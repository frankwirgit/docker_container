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

echo safe4whc | streamtool getinstancestate -d whc -i medp3 -U streamsuser

${__dir}/controller.sh start -s MDTMainGlycemicFeaturesandInsights -e ${propsFile}
${__dir}/controller.sh start -s MDTMainTrigger -e ${propsFile}
${__dir}/controller.sh start -s MDTMainMyData -e ${propsFile}
${__dir}/controller.sh start -s MDTMainMI -e ${propsFile}
${__dir}/controller.sh start -s MDTMainInputData -e ${propsFile}
${__dir}/controller.sh start -s MDTHypoInputData -e ${propsFile}
${__dir}/controller.sh start -s MDTHypoFeatureExtraction -e ${propsFile}
${__dir}/controller.sh start -s MDTHypoScoring -e ${propsFile}

echo "Checking health..."
healthyJobs=$(echo safe4whc | streamtool lsjobs -d whc -i medp3 -U streamsuser --xheaders --fmt %Nf | grep "Healthy: yes" | wc -l)
if [ ${healthyJobs} -lt 6 ]; then
  echo "One or more jobs have become unhealthy."
  exit 1
else
  echo "Analytics Streams deployed successfully."
fi
