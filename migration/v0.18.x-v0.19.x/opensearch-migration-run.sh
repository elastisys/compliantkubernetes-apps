#!/usr/bin/bash

set -euo pipefail

IFS=$'\n'

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"
secrets="${CK8S_CONFIG_PATH}/secrets.yaml"
common_defaults="${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
sc_defaults="${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"
sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

if [[ ! -f "${sops_config}" ]]; then
    echo "Sops config does not exist, aborting."
    exit 1
elif [[ ! -f "${secrets}" ]]; then
    echo "Secrets does not exist, aborting."
    exit 1
elif [[ ! -f "${common_defaults}" ]]; then
    echo "Default common-config does not exist, aborting."
    exit 1
elif [[ ! -f "${common_config}" ]]; then
    echo "Override common-config does not exist, aborting."
    exit 1
elif [[ ! -f "${sc_defaults}" ]]; then
    echo "Default sc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${sc_config}" ]]; then
    echo "Override sc-config does not exist, aborting."
    exit 1
fi

sc_merged=$(yq m -x -a overwrite "${common_defaults}" "${sc_defaults}" "${common_config}" "${sc_config}")

SNAPSHOTS=$(echo "${sc_merged}" | yq r - "elasticsearch.snapshot.enabled")

if [[ "${SNAPSHOTS}" != "true" ]]; then
    echo "WARNING: If you want to keep data while migrating from ODFE to OpenSearch you must have snapshots enabled."
    echo -n "- continue? [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        exit 1
    fi
fi

ES_BUCKET=$(echo "${sc_merged}" | yq r - "objectStorage.buckets.elasticsearch")
ES_PASSWORD=$(sops --config "${sops_config}" -d --extract '["elasticsearch"]["adminPassword"]' "${secrets}")
ES_REPOSITORY=$(echo "${sc_merged}" | yq r - "elasticsearch.snapshotRepository")

OS_BUCKET=$(echo "${sc_merged}" | yq r - "objectStorage.buckets.opensearch")
OS_PASSWORD=$(sops --config "${sops_config}" -d --extract '["opensearch"]["adminPassword"]' "${secrets}")
OS_REPOSITORY=$(echo "${sc_merged}" | yq r - "opensearch.snapshot.repository")
OS_CLUSTERNAME=$(echo "${sc_merged}" | yq r - "opensearch.clusterName")

if [[ "${SNAPSHOTS}" == "true" ]]; then
    if [[ "${OS_BUCKET}" == "${ES_BUCKET}" ]]; then
        echo -n "ERROR: OpenSearch cannot use the same bucket as ODFE."
        exit 1
    elif [[ "${OS_REPOSITORY}" == "${ES_REPOSITORY}" ]]; then
        echo -n "ERROR: OpenSearch cannot use the same repository name as ODFE."
        exit 1
    fi
fi

BASE_DOMAIN=$(echo "${sc_merged}" | yq r - "global.baseDomain")
OSD_SUBDOMAIN=$(echo "${sc_merged}" | yq r - "opensearch.dashboards.subdomain")

echo "--- Migration from ODFE to OpenSearch ---
"

echo "--- Deleting Fluentd Elasticsearch to stop incoming logs.
ck8s ops helmfile wc -l app=fluentd delete"
echo -n "- run? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi
"${here}/../../bin/ck8s" ops helmfile wc -l app=fluentd delete
echo "---
"

# BEGIN TAKE SNAPSHOT
if [[ "${SNAPSHOTS}" == "true" ]]; then

echo "--- Waiting for ODFE snapshots in progress ---
Elasticsearch > GET /_snapshot/_status"
while true; do
    res=$("${here}/../../bin/ck8s" ops kubectl sc -n elastic-system exec opendistro-es-master-0 -c elasticsearch -- \
        curl -XGET "'http://localhost:9200/_snapshot/_status'" -u "'admin:${ES_PASSWORD}'" -sS | \
        yq r - 'snapshots')
    if [[ "$res" == "[]" ]]; then
        break
    fi
    echo -n "."
    sleep 5
done
echo -e "done\n---\n"

echo "--- Taking final ODFE snapshot ---
Elasticsearch > PUT /_snapshot/${ES_REPOSITORY}/final
-"
"${here}/../../bin/ck8s" ops kubectl sc -n elastic-system exec opendistro-es-master-0 -c elasticsearch -- \
curl -XPUT "'http://localhost:9200/_snapshot/${ES_REPOSITORY}/final?wait_for_completion=true&pretty=true'" \
-u "'admin:${ES_PASSWORD}'" -sS
echo "---
"

echo "Make sure that the snapshot has the state 'SUCCESS', else you might have to manually delete it and start over"
echo "If you've already done this step then it is expected that it will throw an 'invalid_snapshot_name_exception'"
echo -n "- continue? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi

fi
# END TAKE SNAPSHOT

echo "--- Deleting Prometheus Elasticsearch Exporter.
ck8s ops helmfile sc -l group=opendistro,app=prometheus-elasticsearch-exporter delete"
echo -n "- run? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi
"${here}/../../bin/ck8s" ops helmfile sc -l group=opendistro,app=prometheus-elasticsearch-exporter delete
echo "---
"

echo "--- Deleting ODFE. (Skip using option 's' if you want to keep it for now, remove it now if you are going to reuse the subdomains.)
ck8s ops helmfile sc -l group=opendistro delete"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops helmfile sc -l group=opendistro delete
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "--- Deleting ODFE PVCs. (Skip using option 's' if you want to keep it, remove it now if you have limited block storage.)
ck8s ops kubectl sc -n elastic-system delete pvc -l app=opendistro-es"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops kubectl sc -n elastic-system delete pvc -l app=opendistro-es
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "--- Updating Dex with OpenSearch client. (Skip using option 's' if it is not used.)
ck8s ops helmfile sc -l app=dex apply"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops helmfile sc -l app=dex apply
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "--- Bootstrapping namespaces.
ck8s bootstrap sc
-"
"${here}/../../bin/ck8s" bootstrap sc
echo "---
"

echo "--- Deploying OpenSearch.
ck8s ops helmfile sc -l group=opensearch apply
-"
"${here}/../../bin/ck8s" ops helmfile sc -l group=opensearch apply
echo "---

OpenSearch should be ready when the apply is done, verify opening: https://${OSD_SUBDOMAIN}.${BASE_DOMAIN}/
---
"

# BEGIN RESTORE SNAPSHOT
if [[ "${SNAPSHOTS}" == "true" ]]; then

echo "--- Deleting generated '.opensearch_dashboards*' index from OpenSearch, this will later be restored from the snapshot.
OpenSearch > DELETE /.opensearch_dashboards*"
echo -n "- run? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -- \
curl -XDELETE "'http://localhost:9200/.opensearch_dashboards*?pretty=true'" \
-u "'admin:${OS_PASSWORD}'"
echo "---
"

echo "--- Adding ODFE snapshot repository.
OpenSearch > PUT /_snapshot/${ES_REPOSITORY}
'{
    \"type\":\"s3\",
    \"settings\":{
        \"bucket\":\"${ES_BUCKET}\",
        \"readonly\":true
    }
}'
-"
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XPUT "'http://localhost:9200/_snapshot/${ES_REPOSITORY}?pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -H "'Content-Type: application/json'" -sS -d \
"'{
    \"type\":\"s3\",
    \"settings\":{
        \"bucket\":\"${ES_BUCKET}\",
        \"readonly\":true
    }
}'"
echo "---
"

echo "--- Restoring .kibana* from final ODFE snapshot
OpenSearch > POST /_snapshot/${ES_REPOSITORY}/final/_restore
'{
    \"indices\": \".kibana*\",
    \"include_aliases\": false,
    \"include_global_state\": false,
    \"rename_pattern\": \".kibana(.+)\",
    \"rename_replacement\": \".opensearch_dashboards\$1\"
}'
-"
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XPOST "'http://localhost:9200/_snapshot/${ES_REPOSITORY}/final/_restore?wait_for_completion=true&pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -H "'Content-Type: application/json'" -sS -d \
"'{
    \"indices\": \".kibana*\",
    \"include_aliases\": false,
    \"include_global_state\": false,
    \"rename_pattern\": \".kibana(.+)\",
    \"rename_replacement\": \".opensearch_dashboards\$1\"
}'"

echo "--- Adding restored .opensearch_dashboards* to alias
OpenSearch > POST /_aliases
'{
    \"actions\": [
      {
        \"add\": {
          \"index\": \".opensearch_dashboards*\",
          \"alias\": \".opensearch_dashboards\"
        }
      }
    ]
}'"
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XPOST "'http://localhost:9200/_aliases?pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -H "'Content-Type: application/json'" -sS -d \
"'{
    \"actions\": [
      {
        \"add\": {
          \"index\": \".opensearch_dashboards*\",
          \"alias\": \".opensearch_dashboards\"
        }
      }
    ]
}'"
echo "---
"

INDICES="authlog
kubeaudit
kubernetes
other"

for index in ${INDICES}; do
echo "--- Restoring ${index}* from final ODFE snapshot
OpenSearch > POST /_snapshot/${ES_REPOSITORY}/final/_restore
'{
    \"indices\": \"${index}*\",
    \"include_aliases\": false,
    \"include_global_state\": false,
    \"rename_pattern\": \"${index}(.+)\",
    \"rename_replacement\": \"${index}-restored\$1\",
    \"ignore_index_settings\": [
        \"index.opendistro.index_state_management.policy_id\",
        \"index.opendistro.index_state_management.rollover_alias\"
    ]
}'
-"
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XPOST "'http://localhost:9200/_snapshot/${ES_REPOSITORY}/final/_restore?wait_for_completion=true&pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -H "'Content-Type: application/json'" -sS -d \
"'{
    \"indices\": \"${index}*\",
    \"include_aliases\": false,
    \"include_global_state\": false,
    \"rename_pattern\": \"${index}(.+)\",
    \"rename_replacement\": \"${index}-restored\$1\",
    \"ignore_index_settings\": [
        \"index.opendistro.index_state_management.policy_id\",
        \"index.opendistro.index_state_management.rollover_alias\"
    ]
}'"
echo "---
"
echo "--- Adding restored ${index}* to alias
OpenSearch > POST /_aliases
'{
    \"actions\": [
      {
        \"add\": {
          \"index\": \"${index}-restored*\",
          \"alias\": \"${index}\"
        }
      }
    ]
}'"
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XPOST "'http://localhost:9200/_aliases?pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -H "'Content-Type: application/json'" -sS -d \
"'{
    \"actions\": [
      {
        \"add\": {
          \"index\": \"${index}-restored*\",
          \"alias\": \"${index}\"
        }
      }
    ]
}'"
echo "---
"
done

echo "If ODFE is still running you can now verify that all objects have been restored.
---
"

echo "--- Removing ODFE snapshot repository.
OpenSearch > DELETE /_snapshot/${ES_REPOSITORY}"
echo -n "- run? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi
"${here}/../../bin/ck8s" ops kubectl sc -n opensearch-system exec "${OS_CLUSTERNAME}-master-0" -c opensearch -- \
curl -XDELETE "'http://localhost:9200/_snapshot/${ES_REPOSITORY}?pretty=true'" \
-u "'admin:${OS_PASSWORD}'" -sS
echo "---
"

fi
# END RESTORE SNAPSHOT

echo "--- Deleting ODFE. (Skip using option 's' if you want to keep it for now or already done so.)
ck8s ops helmfile sc -l group=opendistro delete"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops helmfile sc -l group=opendistro delete
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "--- Deleting ODFE PVCs. (Skip using option 's' if you want to keep it or already done so.)
ck8s ops kubectl sc -n elastic-system delete pvc -l app=opendistro-es"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops kubectl sc -n elastic-system delete pvc -l app=opendistro-es
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "--- Deleting ODFE namespace. (Skip using option 's' if you want to keep it.)
ck8s ops kubectl sc delete namespace elastic-system"
echo -n "- run? [y/s/N]: "
read -r reply
if [[ "${reply}" == "y" ]]; then
    "${here}/../../bin/ck8s" ops kubectl sc delete namespace elastic-system
elif [[ "${reply}" == "s" ]]; then
    echo "skipping"
else
    exit 1
fi
echo "---
"

echo "Done!"
