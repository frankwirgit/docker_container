#!/bin/bash
set -x
set -e
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/common/kafka:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/data-mgt-mac:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/device-simulator:latest
/usr/bin/time ./ci/docker/controller.py deploy -e med-p3-dev.json -i med-p3-dev-cwb.softlayer.com:5000/develop/mbe:latest
