#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

# Deploys all Analytics Streams SABs to provided environment in single command

__dir="$(dirname $(readlink -f "$0"))"

function usage() {
  echo "Usage: ${0} [-e env.properties]"
  echo "  -e: Name of the environment properties file to use. Defaults to `hostname`.properties"
  exit 1
}

function parseArgs() {
  propsFile=$(hostname).properties
  while getopts ":e:" opt; do
    case $opt in
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
}

parseArgs ${*}

${__dir}/controller.sh stop -s MDTMainGlycemicFeaturesandInsights -e ${propsFile}
${__dir}/controller.sh stop -s MDTMainTrigger -e ${propsFile}
${__dir}/controller.sh stop -s MDTMainMyData -e ${propsFile}
${__dir}/controller.sh stop -s MDTMainMI -e ${propsFile}
${__dir}/controller.sh stop -s MDTMainInputData -e ${propsFile}
${__dir}/controller.sh stop -s MDTHypoInputData -e ${propsFile}
${__dir}/controller.sh stop -s MDTHypoFeatureExtraction -e ${propsFile}
${__dir}/controller.sh stop -s MDTHypoScoring -e ${propsFile}
