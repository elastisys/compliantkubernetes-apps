#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "${0}")")"

#We should only lint our "own" charts, not the upstream ones

charts_ignore_list=(
  "app!=sc-logs-retention"
  "app!=fluentd-configmap"
  "app!=ingress-nginx"
  "app!=cert-manager"
  "app!=kube-prometheus-stack"
  "app!=velero"
  "app!=metrics-server"
  "app!=wc-scraper"
  "app!=prometheus-auth"
  "app!=wc-reader"
  "app!=prometheus-wc-reader"
  "app!=user-grafana"
  "app!=prometheus-elasticsearch-exporter"
  "app!=harbor"
  "app!=thanos"
  "app!=fluentd"
  "app!=fluentd-aggregator"
  "app!=opensearch-data"
  "app!=opensearch-client"
  "app!=falco"
  "app!=falco-exporter"
  "app!=user-alertmanager")

helmfile -e service_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
helmfile -e workload_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint

helmfile -e service_cluster -f "${here}/../bootstrap/namespaces/helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
helmfile -e workload_cluster -f "${here}/../bootstrap/namespaces/helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
