#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

__dir="$(dirname $(readlink -f "${0}"))"

function usage() {
  echo "Usage: ${0} <start|stop|restart|status> -e env.properties"
  echo "  start: Starts the MBE if it is not already running"
  echo "  stop: Stops the currently running MBE"
  echo "  restart: Restarts the MBE"
  echo "  status: Checks the status of the MBE"
  echo "  -e: Name of the environment properties file to use"
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
  if [ ! -f "${__dir}/${propsFile}" ]; then
    echo "The environment '${propsFile}' is not supported. Enter a valid environment ID as argument 1."
    usage
  fi

  # Source environment properties file
  . "${__dir}/${propsFile}"

  # Assign defaults to global properties
  wlpHome=${wlpHome:-/opt/ibm/wlp}
}

# Stop server
function stop() {
  sudo service sugariq-mfp stop
}

# Start server
function start() {
  sudo service sugariq-mfp start
}

function restart() {
  sudo service sugariq-mfp restart
}

function status() {
  sudo service sugariq-mfp status
}

parseArgs ${*}

case ${action} in
  "stop")
    stop
    ;;
  "start")
    start
    ;;
  "restart")
    restart
    ;;
  "status")
    status
    ;;
  *)
    echo "'${action}' is not a recognized command"
    usage
    ;;
esac

