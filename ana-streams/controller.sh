#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset
set -e

# Deploys Main Analytics Streams Build to a SugarIQ environment
# Execute script with arg1=<environment properties path>.
# i.e., ./deploy-main.sh env.properties <start|stop>

__dir="$(dirname $(readlink -f "$0"))"

function usage() {
  echo "Usage: ${0} <start|deploy|stop|restart|status> [-s sabName] [-e env.properties]"
  echo "  start: Starts the streams job if it is not already running"
  echo "  deploy: Alias for 'restart'"
  echo "  stop: Stops the currently running streams job"
  echo "  restart: Restarts the streams job"
  echo "  status: Checks the status of the streams job"
  echo "  -s: Short name of the SAB file to deploy"
  echo "  -e: Name of the environment properties file to use. Defaults to `hostname`.properties"
  exit 1
}

function parseArgs() {
  if [ ${#} -eq 0 ]; then
    usage
  fi

  action=${1}
  shift

  propsFile=$(hostname).properties
  newUser=false
  while getopts ":s:e:" opt; do
    case $opt in
      s)
        sabName=${OPTARG}
        sabFile="app/com.ibm.mdt.main.gen2.${sabName}.sab"
        jobName="com.ibm.mdt.main.gen2::${sabName}"
        if [ "${sabName}" = "MDTHypoInputData" ] || [ "${sabName}" = "MDTHypoFeatureExtraction" ] || [ "${sabName}" = "MDTHypoScoring" ]; then
          sabFile="app/com.ibm.mdt.main.gen3.${sabName}.sab"
          jobName="com.ibm.mdt.main.gen3::${sabName}"
        fi
        ;;
      e)
        propsFile=${OPTARG}
        ;;
      :)
        echo "Option '-${OPTARG}' requires an argument."
        usage
        ;;
      \?)
        echo "Invalid option: -${OPTARG}"
        usage
        ;;
    esac
  done

  # Environment properties file path
  if [ ! -f "${__dir}/properties/environment/${propsFile}" ]; then
    echo "The environment '${propsFile}' is not supported. Enter a valid environment ID as argument 1."
    usage
  fi

  # Source environment properties file
  . "${__dir}/properties/environment/${propsFile}"

  # Set job opts
  streamsJobOpts="-P kafkaPartitions=${kafkaPartitions} \
    -P appConfigName=${appConfigName} \
    -C fusionScheme=${fusionScheme:-legacy} \
    -C placementScheme=${placementScheme:-legacy} \
    -C threadingModel=${threadingModel:-manual} \
    -C tracing=${tracing:-error}"
}

function getJobId() {
  jobId=$(
  echo ${streamsUserPass} | streamtool lsjobs \
    -U ${streamsUser} \
    -i ${streamsInstance} \
    -d ${streamsDomain} | \
    awk '/'${jobName}_'/' | \
    awk '{print $1;}'
  )
}

function status() {
  echo "Getting ${sabName} status..."
  healthy=false
  getJobId

  if [ ! -z $jobId ]; then
    # Get job state and health
    jobState=$(
    echo ${streamsUserPass} | streamtool lsjobs \
      -j ${jobId} \
      -U ${streamsUser} \
      -i ${streamsInstance} \
      -d ${streamsDomain} | \
      awk 'FNR ==3 {print $2;}'
    )
    isHealthy=$(
    echo ${streamsUserPass} | streamtool lsjobs \
      -j ${jobId} \
      -U ${streamsUser} \
      -i ${streamsInstance} \
      -d ${streamsDomain} | \
      awk 'FNR ==3 {print $3;}'
    )
    # Confirm running and helthy
    echo Verifying health of Streams job...
    if [ "${jobState}" = "Running" ] && [ "${isHealthy}" = "yes" ]; then
      echo Streams job ${jobId} is running and healthy!
      healthy=true
    fi
  fi
}

function stop() {
  echo "Stopping existing ${sabName}..."
  getJobId
  if [ ! -z ${jobId} ]; then
    echo ${streamsUserPass} | streamtool canceljob ${jobId} \
      --force \
      -U ${streamsUser} \
      -i ${streamsInstance} \
      -d ${streamsDomain}

    # Validate previous job has been canceled
    timeout=1200
    while [ ${timeout} -gt 0 ]; do
      getJobId
      if [ -z ${jobId} ]; then
        echo "Job has been cancelled."
        break
      fi

      echo "Waiting for job to cancel. Going to sleep, then making another attempt..."
      sleep 30
      timeout=$((${timeout}-30))
    done

    if [ ! -z ${jobId} ]; then
      echo "Job could not be cancelled."
      exit 1
    fi
  fi
}

function start() {
  echo "Starting Streams job..."
  # Check for running job
  getJobId
  if [ ! -z ${jobId} ]; then
    echo "Job is already running with ID ${jobId}"
    exit 1
  fi

  # Submit streams job.
  echo ${streamsUserPass} | streamtool submitjob ./${sabFile} \
    -U ${streamsUser} \
    -i ${streamsInstance} \
    -d ${streamsDomain} \
    ${streamsJobOpts}

  # Validate Streams job started and is healthy
  getJobId

  echo Begin health validation of Streams job ${jobId}...
  timeout=90
  while [ ${timeout} -gt 0 ]; do
    status
    if [ "${healthy}" = "true" ]; then
      break
    fi

    echo Going to sleep for 30 seconds, then making another attempt...
    sleep 30
    timeout=$((${timeout}-30))
  done

  if [ "${healthy}" = "false" ]; then
    echo Streams job ${jobId} has not returned healthy status in a reasonable amount of time.
    exit 1
  fi
}

function restart() {
  stop
  start
}

parseArgs ${*}

case ${action} in
  "stop")
    stop
    ;;
  "start")
    start
    ;;
  "restart"|"deploy")
    restart
    ;;
  "status")
    status
    if [ "${healthy}" = "false" ]; then
      echo "The Streams job is either not running or cannot be reached"
      exit 1
    fi
    ;;
  *)
    echo "'${action}' is not a recognized command"
    usage
    ;;
esac
