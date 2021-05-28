#!/bin/bash

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

get_patch() {
  local release_name=$1
  local release_namespace=$2
  local chart=$3

  echo \''{"metadata":'\
          '{ "annotations":'\
            '{ "meta.helm.sh/release-name": "'"${release_name}"'",' \
              '"meta.helm.sh/release-namespace": "'"${release_namespace}"'"},' \
            '"labels":' \
              '{ "app.kubernetes.io/managed-by": "Helm",'\
                '"helm.sh/chart": "'"${chart}"'"}}}'\'
}

RELEASE_NAME="cert-manager"
RELEASE_NAMESPACE="cert-manager"
CHART="cert-manager-v1.1.0"
CRDS=(  certificaterequests.cert-manager.io
        certificates.cert-manager.io
        challenges.acme.cert-manager.io
        clusterissuers.cert-manager.io
        issuers.cert-manager.io
        orders.acme.cert-manager.io )

for CRD in "${CRDS[@]}"; do
  "${here}/../../bin/ck8s" ops kubectl wc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
  "${here}/../../bin/ck8s" ops kubectl sc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
done

RELEASE_NAME="velero"
RELEASE_NAMESPACE="velero"
CHART="velero-2.15.0"

CRDS=(  backups.velero.io
        backupstoragelocations.velero.io
        deletebackuprequests.velero.io
        downloadrequests.velero.io
        podvolumebackups.velero.io
        podvolumerestores.velero.io
        resticrepositories.velero.io
        restores.velero.io
        schedules.velero.io
        serverstatusrequests.velero.io
        volumesnapshotlocations.velero.io )

for CRD in "${CRDS[@]}"; do
  "${here}/../../bin/ck8s" ops kubectl wc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
  "${here}/../../bin/ck8s" ops kubectl sc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
done

RELEASE_NAME="kube-prometheus-stack"
RELEASE_NAMESPACE="monitoring"
CHART="kube-prometheus-stack-12.8.0"
CRDS=(  alertmanagerconfigs.monitoring.coreos.com
        alertmanagers.monitoring.coreos.com
        podmonitors.monitoring.coreos.com
        probes.monitoring.coreos.com
        prometheuses.monitoring.coreos.com
        prometheusrules.monitoring.coreos.com
        servicemonitors.monitoring.coreos.com
        thanosrulers.monitoring.coreos.com )

for CRD in "${CRDS[@]}"; do
  "${here}/../../bin/ck8s" ops kubectl wc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
  "${here}/../../bin/ck8s" ops kubectl sc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
done

# WC only

RELEASE_NAME="gatekeeper"
RELEASE_NAMESPACE="gatekeeper-system"
CHART="gatekeeper"
CRDS=(  configs.config.gatekeeper.sh
        constraintpodstatuses.status.gatekeeper.sh
        constrainttemplatepodstatuses.status.gatekeeper.sh
        constrainttemplates.templates.gatekeeper.sh
        k8sallowedrepos.constraints.gatekeeper.sh
        k8srequirenetworkpolicy.constraints.gatekeeper.sh
        k8sresourcerequests.constraints.gatekeeper.sh )

for CRD in "${CRDS[@]}"; do
  "${here}/../../bin/ck8s" ops kubectl wc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
done

# SC only

RELEASE_NAME="dex"
RELEASE_NAMESPACE="dex"
CHART="dex-2.15.2"

CRDS=(  authcodes.dex.coreos.com
        authrequests.dex.coreos.com
        connectors.dex.coreos.com
        oauth2clients.dex.coreos.com
        offlinesessionses.dex.coreos.com
        passwords.dex.coreos.com
        refreshtokens.dex.coreos.com
        signingkeies.dex.coreos.com )

for CRD in "${CRDS[@]}"; do
  "${here}/../../bin/ck8s" ops kubectl sc patch crd "${CRD}" --patch "$(get_patch "${RELEASE_NAME}" "${RELEASE_NAMESPACE}" "${CHART}")"
done
