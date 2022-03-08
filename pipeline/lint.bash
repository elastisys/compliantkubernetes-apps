#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"

#We should only lint our "own" charts, not the upstream ones
# TODO: enable linting of kubeapi-metrics, opensearch-secrets and opensearch-configurer after the PGP issues in the pipeline have been solved (https://github.com/elastisys/compliantkubernetes-apps/issues/184)

charts_ignore_list=(
  "app!=sc-logs-retention"
  "app!=fluentd-configmap"
  "app!=ingress-nginx"
  "app!=cert-manager"
  "app!=kube-prometheus-stack"
  "app!=velero"
  "app!=metrics-server"
  "app!=dex"
  "app!=wc-scraper"
  "app!=prometheus-auth"
  "app!=wc-reader"
  "app!=prometheus-wc-reader"
  "app!=user-grafana"
  "app!=prometheus-elasticsearch-exporter"
  "app!=harbor"
  "app!=influxdb"
  "app!=fluentd"
  "app!=fluentd-aggregator"
  "app!=opensearch-master"
  "app!=opensearch-data"
  "app!=opensearch-client"
  "app!=opensearch-dashboards"
  "app!=opensearch-secrets"
  "app!=opensearch-configurer"
  "app!=falco"
  "app!=falco-exporter"
  "app!=user-alertmanager"
  "app!=kubeapi-metrics")

helmfile -e service_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
helmfile -e workload_cluster -f "${here}/../helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint

helmfile -e service_cluster -f "${here}/../bootstrap/namespaces/helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
helmfile -e workload_cluster -f "${here}/../bootstrap/namespaces/helmfile/" -l "$(IFS=',' ; echo "${charts_ignore_list[*]}")" lint
