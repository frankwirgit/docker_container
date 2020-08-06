#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

source ${1}
envProps=environments.properties
if [ -f environments.properties.template ]; then
  cp environments.properties.template ${envProps}
else
  touch ${envProps}
fi

# Replace tokens in file
function replaceToken() {
  echo "Replacing token ${1} with token ${2} in file ${3}..."
  sed -i "s|${1}|${2}|g" ${3}
}

# Replace environment properties tokens
replaceToken "KAFKA_CONSUMER_AUTO_COMMIT_INTERVAL_MS_TOKEN" "${kafkaConsumerAutoCommitInterval:-1000}" ${envProps}
replaceToken "KAFKA_CONSUMER_MAX_POLL_RECORDS_TOKEN" "${kafkaConsumerMaxPollRecords:-500}" ${envProps}
replaceToken "KAFKA_PRODUCER_BATCH_SIZE_TOKEN" "${kafkaProducerBatchSize:-16284}" ${envProps}
replaceToken "KAFKA_PRODUCER_BUFFER_MEMORY_TOKEN" "${kafkaProducerBufferMemory:-33554432}" ${envProps}
replaceToken "KAFKA_PRODUCER_MAX_REQUEST_SIZE_TOKEN" "${kafkaProducerMaxRequestSize:-10000000}" ${envProps}
replaceToken "KAFKA_PRODUCER_ACK_SIZE_TOKEN" "${kafkaProducerAckSize:-}" ${envProps}
replaceToken "KAFKA_CONSUMER_SESSION_TIMEOUT_MS_TOKEN" "${kafkaConsumerSessionTimeout:-6000}" ${envProps}
replaceToken "SECURITY_PROTOCOL_TOKEN" "${kafkaSecurityProtocol:-}" ${envProps}
replaceToken "TRUSTSTORE_LOCATION_TOKEN" "${kafkaTruststoreLocation:-}" ${envProps}
replaceToken "TRUSTSTORE_PASSWORD_TOKEN" "${kafkaTruststorePassword:-}" ${envProps}
replaceToken "TRUSTSTORE_TYPE_TOKEN" "${kafkaTruststoreType:-}" ${envProps}
replaceToken "ENABLED_PROTOCOLS_TOKEN" "${kafkaEnabledProtocols:-}" ${envProps}
replaceToken "KEYSTORE_LOCATION_TOKEN" "${kafkaKeystoreLocation:-}" ${envProps}
replaceToken "KEYSTORE_PASSWORD_TOKEN" "${kafkaKeysPassword:-}" ${envProps}
replaceToken "KEYS_PASSWORD_TOKEN" "${kafkaKeysPassword:-}" ${envProps}
replaceToken "KEYSTORE_TYPE_TOKEN" "${kafkaKeystoreType:-}" ${envProps}
replaceToken "ZOOKEEPER_TOKEN" "${zkServers:-}" ${envProps}

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
replaceToken "KAFKA_TOKEN" "${kafkaToken}" ${envProps}

#  Replace tokens in analytics-jee.properties to mfp server
cp analytics-jee.properties.template analytics-jee.properties
replaceToken "LIVE_TOPIC_NAME_TOKEN" "${liveTopicName:-MDTLIVE}" analytics-jee.properties
replaceToken "PRIME_CHUNK_SIZE_TOKEN" "${primeDataChunkSize:-240}" analytics-jee.properties

# Configure and restart MFP
./prepareServerXML.sh ${1}

# Wait for MFP initialization to complete
echo "Waiting for MFP to initialize..."
ret=0
timeout=50000
while [ ${ret} -lt 1 ]; do
  ret=$(grep "========= MobileFirst Administration Services version .* started\." /var/log/liberty/mfp/messages.log | wc -l)
  sleep 5
  timeout=$((timeout-5))
  if [ ${timeout} -le 0 ]; then
    echo "MFP failed to initialize within a reasonable amount of time."
    exit 1
  fi
done

# Deploy adapters and other artifacts
./deployMBE.sh ${1}
