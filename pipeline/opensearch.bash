#!/usr/bin/env bash

set -eu

opensearch_url=https://opensearch.ops.pipeline-elastx.dev-ck8s.se/api/status
retries=60
while [ ${retries} -gt 0 ]; do
  result="$(curl --connect-timeout 20 --max-time 60 --insecure -sIL -o /dev/null -w "%{http_code}" $opensearch_url || true)"
  [[ "${result}" == "401" ]] && echo "Opensearch is ready. Got status ${result}"
  break
  echo "Waiting for OpenSearch to be ready. Got status ${result}"
  sleep 10
  retries=$((retries - 1))
done
./apps/bin/ck8s ops kubectl wc -n fluentd-system rollout restart daemonset fluentd-forwarder
./apps/bin/ck8s ops kubectl wc -n fluentd-system rollout restart statefulset fluentd-aggregator
# There seem to be no point in waiting for the pods here, as the tests already do this.
