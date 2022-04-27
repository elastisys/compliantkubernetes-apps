set -eu

retries=60
 while [ ${retries} -gt 0 ]; do
   result="$(curl --connect-timeout 20 --max-time 60 -ksIL -o /dev/null -w "%{http_code}" https://opensearch.ops.pipeline-exoscale.elastisys.se || true)"
   echo "Waiting for OpenSearch to be ready. Got status ${result}"
   [[ "${result}" == "401" ]] && break
   sleep 10
   retries=$((retries-1))
 done
./apps/bin/ck8s ops kubectl wc -n fluentd rollout restart daemonset fluentd-fluentd-elasticsearch
./apps/bin/ck8s ops kubectl wc -n kube-system rollout restart daemonset fluentd-system-fluentd-elasticsearch
# There seem to be no point in waiting for the pods here, as the tests already do this.
