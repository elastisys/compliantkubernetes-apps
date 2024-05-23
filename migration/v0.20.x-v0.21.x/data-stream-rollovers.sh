#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"
secrets="${CK8S_CONFIG_PATH}/secrets.yaml"

OS_PASSWORD=$(sops --config "${sops_config}" -d --extract '["opensearch"]["adminPassword"]' "${secrets}")

indexArr=$("${here}/../../bin/ck8s" ops kubectl sc exec -n opensearch-system opensearch-master-0 -c opensearch -- curl -XGET 'http://localhost:9200/_cat/aliases?format=json' -u "'admin:${OS_PASSWORD}'" --no-progress-meter | jq -r .[].alias | sort -u | grep -vP "^\.")

for index in $indexArr; do
    res=$("${here}/../../bin/ck8s" ops kubectl sc exec -n opensearch-system opensearch-master-0 -c opensearch -- curl -XPOST 'http://localhost:9200/'"${index}"'/_rollover' -u "'admin:""${OS_PASSWORD}""'" --no-progress-meter)
    echo "$res"
done
