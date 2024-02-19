#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

hncExcludedNamespaces=(alertmanager cert-manager falco fluentd fluentd-system hnc-system ingress-nginx kube-node-lease kube-public kube-system kured monitoring rook-ceph velero gatekeeper-system metallb-system)

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info " - upgrade hnc with the latest excluded ns list"
      helmfile_upgrade wc app=hnc

      log_info " - patch the hnc validatingwebhookconfiguration with excluded ns"
      kubectl_do wc patch validatingwebhookconfiguration.admissionregistration.k8s.io/hnc-controller-validating-webhook-configuration --type strategic --patch '{
      "webhooks": [
          {
              "name": "namespaces.hnc.x-k8s.io",
              "namespaceSelector": {
                  "matchExpressions": [
                      {
                          "key": "kubernetes.io/metadata.name",
                          "operator": "NotIn",
                          "values": ["alertmanager", "cert-manager", "falco", "fluentd", "fluentd-system", "hnc-system", "ingress-nginx", "kube-node-lease", "kube-public", "kube-system", "kured", "monitoring", "rook-ceph", "velero", "gatekeeper-system", "metallb-system"]
                      }
                  ]
              }
          }
        ]
      }'

      for i in "${hncExcludedNamespaces[@]}"; do
        if [[ $(kubectl_do wc get ns -l "${i}".tree.hnc.x-k8s.io/depth --ignore-not-found) ]]; then
          log_info " - hnc label found on ${i}, removing it"
          kubectl_do wc label namespace "${i}" "${i}".tree.hnc.x-k8s.io/depth-
        fi
      done

      log_info " - restore hnc validatingwebhookconfiguration"
      kubectl_do wc patch validatingwebhookconfiguration.admissionregistration.k8s.io/hnc-controller-validating-webhook-configuration --type strategic --patch '{
      "webhooks": [
          {
              "name": "namespaces.hnc.x-k8s.io",
              "namespaceSelector": null
          }
        ]
      }'

    fi
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
