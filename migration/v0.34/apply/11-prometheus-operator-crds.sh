#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    clusters=("sc" "wc")
    if [[ ! "${CK8S_CLUSTER}" = both ]]; then
      clusters=("${CK8S_CLUSTER}")
    fi

    for CLUSTER in "${clusters[@]}"; do
      if [[ ! "$(helm_chart_version "${CLUSTER}" monitoring kube-prometheus-stack)" = "49.2.0" ]]; then
        log_info "  - applying the prometheus-operator CRDs on $CLUSTER"
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-alertmanagerconfigs.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-alertmanagers.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-podmonitors.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-probes.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-prometheuses.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-prometheusrules.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-thanosrulers.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-scrapeconfigs.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds/crd-prometheusagents.yaml
      else
        log_info "  - Skipping applying the prometheus-operator CRDs on $CLUSTER"
      fi
    done
    ;;
  rollback)
    clusters=("sc" "wc")
    if [[ ! "${CK8S_CLUSTER}" = both ]]; then
      clusters=("${CK8S_CLUSTER}")
    fi

    for CLUSTER in "${clusters[@]}"; do
      if [[ ! "$(helm_chart_version "${CLUSTER}" monitoring kube-prometheus-stack)" = "49.2.0" ]]; then
        log_info "  - rollback the prometheus-operator CRDs on $CLUSTER"
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
        kubectl_do "${CLUSTER}" apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.63.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
        kubectl_do "${CLUSTER}" delete -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.1/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml
        kubectl_do "${CLUSTER}" delete -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml
      else
        log_info "  - Skipping rollbacking the prometheus-operator CRDs on $CLUSTER"
      fi
    done
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
