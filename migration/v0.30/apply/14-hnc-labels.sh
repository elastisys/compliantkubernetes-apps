#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

update_hierarchyconfigurations() {
  readarray -t userNamespaces < <(yq4 '.user.namespaces[]' "$CK8S_CONFIG_PATH/wc-config.yaml")
  readarray -t userNamespacesWithHigherPSALevel < <(yq4 '.user.constraints // {} | keys | .[]' "$CK8S_CONFIG_PATH/wc-config.yaml")

  for i in "${userNamespacesWithHigherPSALevel[@]}"; do
    userNamespaces=("${userNamespaces[@]//*${i}*/}")
  done

  for i in "${userNamespaces[@]}"; do
    if [[ -z "$(kubectl_do wc get hierarchyconfigurations.hnc.x-k8s.io -n "${i}" hierarchy --ignore-not-found)" ]]; then
      continue
    fi

    kubectl_do wc annotate hierarchyconfigurations.hnc.x-k8s.io -n "${i}" hierarchy helm.sh/hook- helm.sh/resource-policy- meta.helm.sh/release-name=user-rbac meta.helm.sh/release-namespace=kube-system --overwrite
    kubectl_do wc label hierarchyconfigurations.hnc.x-k8s.io -n "${i}" hierarchy app.kubernetes.io/managed-by=Helm --overwrite

    config="$(kubectl_do wc get hierarchyconfigurations.hnc.x-k8s.io -n "${i}" hierarchy -oyaml)"

    kubectl_do wc patch hierarchyconfigurations.hnc.x-k8s.io -n "${i}" hierarchy --type merge --patch '{
      "spec": {
        "labels": [
          {
            "key": "pod-security.kubernetes.io/enforce",
            "value": "restricted"
          },
          {
            "key": "pod-security.kubernetes.io/audit",
            "value": "restricted"
          },
          {
            "key": "pod-security.kubernetes.io/warn",
            "value": "restricted"
          }
        ]
      }
    }'
  done
}

run() {
  case "${1:-}" in
  execute)
    log_info "--- applying HNC for workload cluster"
    helmfile_upgrade wc group=hnc

    log_info "--- waiting for hnc-controller-manager"
    kubectl_do wc wait pods -n hnc-system -l app.kubernetes.io/component=hnc-controller-manager --for condition=Ready --timeout=300s

    log_info "--- waiting for hnc-webhook"
    kubectl_do wc wait pods -n hnc-system -l app.kubernetes.io/component=hnc-webhook --for condition=Ready --timeout=300s

    log_info "--- updating hierarchyconfigurations with PSA labels for workload cluster"
    update_hierarchyconfigurations

    log_info "--- applying user-rbac for workload cluster"
    helmfile_upgrade wc app=user-rbac
    ;;

  rollback)
    log_warn "rollback not implemented"
    ;;

  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
