#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

# Deploys the kafka-logging-monitoring-distribution to a SugarIQ environment
# Execute script with arg1=<environment properties path>.
# i.e., ./deploy.sh env.properties

__dir="$(dirname $(readlink -f "$0"))"

function usage() {
  echo "Usage: ${0} <deploy> [-e env.properties]"
  echo "  deploy: Configures and restarts the carelink simulator"
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
  while getopts ":e:" opt; do
    case $opt in
      e)
        propsFile=${OPTARG}
        ;;
      :)
        echo "Option '-${OPTARG}' requires an argument"
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

  # Assign defaults to global properties
  buildDir=${buildDir:-/opt/ibm/sugar-iq/kafka-logging/kafka-logging-monitoring}
}

# Replace tokens in file
function replaceToken() {
  echo Replacing token ${1} with token ${2} in file ${3}...
  sed -i "s/${1}/${2}/g" ${3}
}

# Deploy carelink simulator server
function deploy() {
  __scripts=${buildDir}/scripts
  envPropTemplate=${__scripts}/environments.properties.template

  # Replace environment properties KAFKA_TOKEN
  count=1
  kafkaToken=
  while [ ${count} -le ${kafkaNodes} ]; do
    if [ ! -z ${kafkaToken} ]; then
      kafkaToken="${kafkaToken},"
    fi
    currentKafkaHost=$(eval "echo \$kafkaHost$count")
    if [ ${currentKafkaHost} = "localhost" ]; then
      currentKafkaHost=$(hostname -f)
    fi
    currentKafkaPort=$(eval "echo \$kafkaPort$count")
    kafkaToken="${kafkaToken}${currentKafkaHost}:${currentKafkaPort}"
    count=$((count+1))
  done
  replaceToken "KAFKA_TOKEN" "${kafkaToken}" ${envPropTemplate}

  # Replace environemnts properties file with updated template
  cp -f ${envPropTemplate} ${__scripts}/environments.properties
}

parseArgs ${*}

case ${action} in
  "deploy")
    deploy
    ;;
  *)
    echo "'${action}' is not a recognized command"
    usage
    ;;
esac
