#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

# Runs the data-mgt component tests

__dir="$(dirname $(readlink -f "$0"))"

function usage() {
  echo "Usage ${0} deploy [-e env.properties]"
  echo "  deploy: Configures and runs the database tests"
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
}

function deploy() {
  export JAVA_HOME=${JAVA_HOME:-/opt/ibm/ibm-java-x86_64-8.0-1.10}
  export ANT_HOME=${ANT_HOME:-/opt/ant/apache-ant-1.9.6}
  export PATH=${JAVA_HOME}/bin:${ANT_HOME}/bin:$PATH
  pushd ${__dir}/APIAUTO
    ant ServiceBVT -Ddb2.user=db2dat01 -Ddb2.password=safe4whc -Ddb2.host=${dbHost} -Ddb2.name=MDTDB
  popd
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
