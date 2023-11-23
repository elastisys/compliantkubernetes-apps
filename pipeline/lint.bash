#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "${0}")")"

#We should only lint our "own" charts, not the upstream ones

charts_ignore_list=(
  "app!=cert-manager"
  "app!=falco"
  "app!=falco-exporter"
  "app!=fluentd-aggregator"
  "app!=fluentd-forwarder"
  "app!=harbor"
  "app!=ingress-nginx"
  "app!=kube-prometheus-stack"
  "app!=metrics-server"
  "app!=prometheus-opensearch-exporter"
  "app!=thanos"
  "app!=user-alertmanager"
  "app!=user-grafana"
  "app!=velero"
)

helmfile -e service_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
helmfile -e workload_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
