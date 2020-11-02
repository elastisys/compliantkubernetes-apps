#!/usr/bin/env bash

# Installs CA bundle configmaps and secrets in namespaces where they are needed
# to enable TLS certificate verification for inter-cluster communication.

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

filename=$(basename "$0")
here="$(dirname "$(readlink -f "$0")")"
ck8s=$here/bin/ck8s

usage() {
  echo "Usage: $filename <configmap/secret name> <ca bundle>" >&2
  exit 1
}

if [ $# -ne 2 ]; then usage; fi

NAME=$1
BUNDLE=$2

install_configmaps() {
  local sc_namespaces=(
    monitoring
  )
  local wc_namespaces=(
    kube-system
    fluentd
  )
  create_configmap() {
    local cluster=$1 namespace=$2
    kubectl create configmap "$NAME" --from-file="$BUNDLE" --dry-run -o yaml | \
      $ck8s ops kubectl "$cluster" -n "$namespace" apply -f -
  }
  for namespace in "${sc_namespaces[@]}"; do
    create_configmap sc "$namespace"
  done
  for namespace in "${wc_namespaces[@]}"; do
    create_configmap wc "$namespace"
  done
}

install_secrets() {
  local sc_namespaces=(
    harbor
  )
  for namespace in "${sc_namespaces[@]}"; do
    # Note: Harbor requires the ca bundle secret to contain a key named
    # "ca.crt".
    # See https://github.com/goharbor/harbor-helm/blob/v1.5.1/values.yaml#L363-L365
    kubectl create secret generic "$NAME" --from-file=ca.crt="$BUNDLE" \
      --dry-run -o yaml | \
      $ck8s ops kubectl sc -n "$namespace" apply -f -
  done
}

install_configmaps
install_secrets
