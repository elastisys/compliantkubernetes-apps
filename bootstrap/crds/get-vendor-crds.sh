#!/bin/bash

# Pulls vendors crds from github. If the chart version is changed (updated) in helmfile,
# the crd version needs to be changed here to reflect the change.
echo downloading vendor crds
echo cert-manager
wget 'https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml' -O cert-manager/cert-manager.yaml
echo prometheus-operator
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml' -o prometheus-operator/alertmanagerconfigs.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml' -o prometheus-operator/alertmanagers.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml' -o prometheus-operator/podmonitors.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml' -o prometheus-operator/probes.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml' -o prometheus-operator/prometheuses.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml' -o prometheus-operator/prometheusrules.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml' -o prometheus-operator/servicemonitors.yaml
curl 'https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.43/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml' -o prometheus-operator/thanosrulers.yaml
echo velero
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/backups.yaml' -o velero/backups.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/backupstoragelocations.yaml' -o velero/backupstoragelocations.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/deletebackuprequests.yaml' -o velero/deletebackuprequests.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/downloadrequests.yaml' -o velero/downloadrequests.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/podvolumebackups.yaml' -o velero/podvolumebackups.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/podvolumerestores.yaml' -o velero/podvolumerestores.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/resticrepositories.yaml' -o velero/resticrepositories.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/restores.yaml' -o velero/restores.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/schedules.yaml' -o velero/schedules.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/serverstatusrequests.yaml' -o velero/serverstatusrequests.yaml
curl 'https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-2.8.2/charts/velero/crds/volumesnapshotlocations.yaml' -o velero/volumesnapshotlocations.yaml
echo dex
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/authcodes.yaml' -o dex/authcodes.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/authrequests.yaml' -o dex/authrequests.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/connectors.yaml' -o dex/connectors.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/oauth2clients.yaml' -o dex/oauth2clients.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/offlinesessionses.yaml' -o dex/offlinesessionses.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/passwords.yaml' -o dex/passwords.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/refreshtokens.yaml' -o dex/refreshtokens.yaml
curl 'https://raw.githubusercontent.com/dexidp/dex/v2.16.x/scripts/manifests/crds/signingkeies.yaml' -o dex/signingkeies.yaml
echo Patching the dex crds with scope
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/authcodes.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/authrequests.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/connectors.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/oauth2clients.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/offlinesessionses.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/passwords.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/refreshtokens.yaml
sed -i 's/spec:/spec:\n  scope: Namespaced/' dex/signingkeies.yaml
echo gatekeeper
curl 'https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.1.0-beta.8/chart/gatekeeper-operator/templates/gatekeeper.yaml' -o gatekeeper-tmp.yaml
yq r -d1 gatekeeper-tmp.yaml | yq d - metadata.labels.app | yq d - metadata.labels.chart | yq d - metadata.labels.heritage | yq d - metadata.labels.release > gatekeeper/gatekeeper.yaml
echo "---" >> gatekeeper/gatekeeper.yaml
yq r -d2 gatekeeper-tmp.yaml | yq d - metadata.labels.app | yq d - metadata.labels.chart | yq d - metadata.labels.heritage | yq d - metadata.labels.release >> gatekeeper/gatekeeper.yaml
rm gatekeeper-tmp.yaml
