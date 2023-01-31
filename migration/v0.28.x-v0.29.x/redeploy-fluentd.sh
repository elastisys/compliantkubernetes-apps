#!/usr/bin/env bash

set -euxo pipefail

: "${CK8S_CONFIG_PATH:?"Need to set CK8S_CONFIG_PATH!"}"

ns_exists() {
  ./bin/ck8s ops kubectl "$1" get ns "$2" > /dev/null 2> /dev/null
}

helm_uninstall() {
  if ./bin/ck8s ops helm "$1" status -n "$2" "$3" > /dev/null 2> /dev/null; then
    echo "  - helm uninstall: $1/$2/$3"
    ./bin/ck8s ops helm "$1" uninstall -n "$2" "$3"
  fi
}

kubectl_exists() {
  ./bin/ck8s ops kubectl "$1" get "$2" -n "$3" "$4" > /dev/null 2> /dev/null
}

kubectl_delete() {
  if kubectl_exists "$@"; then
    echo "  - kubectl delete: $1/$2/$3/$4"
    ./bin/ck8s ops kubectl "$1" delete "$2" -n "$3" "$4"
  fi
}

if ! ns_exists sc fluentd-system; then
  echo "  - you must run bootstrap on sc!"
  exit 1
fi
if ! ns_exists wc fluentd-system; then
  echo "  - you must run bootstrap on wc!"
  exit 1
fi

# ---

echo "- sc: redeploying"

if ns_exists sc fluentd; then

  helm_uninstall sc fluentd fluentd
  helm_uninstall sc fluentd fluentd-configmap
  helm_uninstall sc fluentd sc-logs-retention

  kubectl_delete sc pvc fluentd fluentd-buffer-fluentd-0
  kubectl_delete sc secrets fluentd s3-credentials

  echo "  - kubectl delete: sc/namespace/fluentd"
  ./bin/ck8s ops kubectl sc delete namespace fluentd

fi

./bin/ck8s ops helmfile sc -l app=fluentd apply

# ---

echo "- wc: redeploying"

helm_uninstall wc kube-system fluentd-system

./bin/ck8s ops helmfile wc -l app=fluentd apply

kubectl_delete wc secrets fluentd opensearch
kubectl_delete wc secrets kube-system opensearch
