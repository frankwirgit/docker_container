#!/bin/bash
set -x
set -e
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/common/kafka:latest
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/data-mgt-mac:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/data-mgt-mac:latest
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/device-simulator:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/device-simulator:latest
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/mbe:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/mbe:latest
echo "copying the toolbert to kafka container"
./copy_toolbert_in_kafka_container.sh
sleep 120
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/mbe-tests:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/mbe-tests:latest
sleep 120
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/analytics-streams:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/analytics-streams:latest
sleep 120
#docker pull med-p3-dev-cwb.softlayer.com:5000/develop/health-diagnostic-tests:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/health-diagnostic-tests:latest
sleep 120
#docker pull
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/analytics-streams-unit-tests:latest

