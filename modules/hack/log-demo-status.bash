#!/bin/bash

set -uo pipefail

here="$(dirname "$(readlink -f "$0")")"

root="${here}/../.."

opensearch_admin_password="$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq4 .opensearch.adminPassword)"

ds_env=$("${root}/bin/ck8s" ops kubectl wc -n fluentd-system get ds fluentd-forwarder -o jsonpath='{.spec.template.spec.containers[0].env}' 2>/dev/null)

print_ds_env() {
  secret_key_ref="$(jq '.[] | select(.name == "'"${1}"'").valueFrom.secretKeyRef' <<<"${ds_env}")"
  if [ -z "${secret_key_ref}" ]; then
    echo "${1}: N/A"
    return
  fi

  secret_name="$(jq -r .name <<<"${secret_key_ref}")"
  secret_key="$(jq -r .key <<<"${secret_key_ref}")"
  value=$("${root}/bin/ck8s" ops kubectl wc -n fluentd-system get secret "${secret_name}" -o jsonpath='{.data.'"${secret_key}"'}' | base64 -d)

  echo "${1}: ${value}"
}

search() {
  # To remove some of the more spammy ones:
  # "query": {
  #   "bool": {
  #     "must": [],
  #     "filter": [
  #       {
  #         "match_all": {}
  #       }
  #     ],
  #     "should": [],
  #     "must_not": [
  #       {
  #         "match_phrase": {
  #           "kubernetes.container_name": "etcd"
  #         }
  #       }, {
  #         "match_phrase": {
  #           "kubernetes.container_name": "calico-node"
  #         }
  #       }, {
  #         "match_phrase": {
  #           "kubernetes.container_name": "kube-apiserver"
  #         }
  #       }
  #     ]
  #   }
  # }

  curl --fail -s -k -u 'admin:'"${opensearch_admin_password}" \
    'https://opensearch.ops.simonklb.dev-ck8s.com/kubernetes/_search' \
    -H 'Content-Type: application/json' \
    -d '{
      "sort":[{"@timestamp":{"order":"desc","unmapped_type":"boolean"}}]
    }' |
    jq -r '.hits.hits[] | [._source."@timestamp"[0:19], ._source.kubernetes.container_name, (._source.message // ._source.msg)] | join("¶")' |
    column -T 3 -t -s '¶'
}

echo -e "\033[1m== MANAGEMENT CLUSTER ==\033[0m"
echo
echo -e "\033[1mModule\033[0m"
"${root}/bin/ck8s" ops kubectl sc get opensearch
echo
echo -e "\033[1mOpenSearch Pods\033[0m"
"${root}/bin/ck8s" ops kubectl sc -n opensearch-system get po
echo
echo -e "\033[1mOpenSearch Ingress\033[0m"
"${root}/bin/ck8s" ops kubectl sc -n opensearch-system get ingress -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[].host
echo
echo -e "\033[1m== WORKLOAD CLUSTER ==\033[0m"
echo
echo -e "\033[1mModule\033[0m"
"${root}/bin/ck8s" ops kubectl wc get fluentdforwarder
echo
echo -e "\033[1mEnvironmentConfigs\033[0m"
"${root}/bin/ck8s" ops kubectl wc get environmentconfig
echo
echo -e "\033[1mFluentd DaemonSet env\033[0m"
print_ds_env OUTPUT_HOSTS
print_ds_env OUTPUT_USER
print_ds_env OUTPUT_PASSWORD
echo
echo -e "\033[1mFluentd Pods\033[0m"
"${root}/bin/ck8s" ops kubectl wc -n fluentd-system get po
echo
echo -e "\033[1m== OPENSEARCH LOGS ==\033[0m"
search
