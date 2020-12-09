### Release notes

- Configuration for harbor and cert-manager has been changed and requires running init and apply again.
- Configuration for velero has been changed and requires running init again.
- Helm has been upgraded to v3.4.1. Please upgrade the local binary.
- The Helm repository `stable` has changed URL and has to be changed manually:
  `helm repo add "stable" "https://charts.helm.sh/stable" --force-update`
- The blackbox chart has a changed dependency URL and has to be updated manually:
  `cd helmfile/charts/blackbox && helm dependency update`
- With the replacement of the helm chart `stable/nginx-ingress` to `ingress-nginx/ingress-nginx`, it is required to manually execute some steps to upgrade.
See [migrations docs for nginx](migration/v0.7.x-v0.8.x/nginx.md) for instruction on how to perform the upgrade.
- The config option `nginxIngress.controller.daemonset.useHostPort` has been replaced by `ingressNginx.controller.useHostPort`.
Make sure to remove the old option from your config when upgrading.
- Move useRegionEndpoint from elasticsearch to fluentd in sc-config.yaml before upgrading.
- The workload cluster config option `prometheus.retention.alertManager` has been removed.
Make sure to remove the option from your config when upgrading.
- With the replacement of the helm chart `stable/prometheus-operator` to `prometheus-community/kube-prometheus-stack`, it is required to manually execute some steps to upgrade.
See [migrations docs for prometheus-operator](migration/v0.7.x-v0.8.x/migrate-prometheus-operator.md) for instructions on how to perform the upgrade.
- Migrate existing config to the new object storage config by running the script `migration/v0.7.x-v0.8.x/migrate-object-storage.sh`
- The configuration for InfluxDB has been changed and requires running init again.
Upon init new default values will be added to your config, please update them to match your old values.
The following options has been removed or replaced
  - `influxDB.address` removed
  - `influxDB.metrics.sizeWc` replaced by `influxDB.retention.sizeWC`
  - `influxDB.metrics.sizeSc` replaced by `influxDB.retention.sizeSC`
  - `influxDB.retention.ageWc` replaced by `influxDB.retention.durationWC`
  - `influxDB.retention.ageSc` replaced by `influxDB.retention.durationSC`
- The config for opendistro has been changed and requires running init again.
See [upgrade docs for opendistro](migration/v0.7.x-v0.8.x/opendistro.md) for instructions for the upgrade.
Upon init new default values will be added to your config, please update them to match your old values.
The following options has been removed or replaced
  - `elasticsearch.tolerations` removed
  - `elasticsearch.nodeSelector` removed
  - `elasticsearch.affinity` removed
  - `elasticsearch.storageClass` replaced by `elasticsearch.dataNode.storageClass`
  - `elasticsearch.retention.kubeAuditSize` replaced by `elasticsearch.retention.kubeAuditSizeGB`
  - `elasticsearch.retention.kubeAuditAge` replaced by `elasticsearch.retention.kubeAuditAgeDays`
  - `elasticsearch.retention.kubernetesSize` replaced by `elasticsearch.retention.kubernetesSizeGB`
  - `elasticsearch.retention.kubernetesAge` replaced by `elasticsearch.retention.kubernetesAgeDays`
  - `elasticsearch.retention.otherSize` replaced by `elasticsearch.retention.otherSizeGB`
  - `elasticsearch.retention.otherAge` replaced by `elasticsearch.retention.otherAgeDays`
- Removed unused config `global.environmentName` and added `global.clusterName` to migrate there's [this script](migration/v0.7.x-v0.8.x/migrate-config.sh)
- To udate the password for `user-alertmanager` you'll have to re-install the chart
  `./bin/ck8s ops helmfile wc -l app=user-alertmanager destroy && ./bin/ck8s ops helmfile wc -l app=user-alertmanager apply`

### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero
- Add `./bin/ck8s ops helm` to allow investigating issues between `helmfile` and `kubectl`.
- Allow nginx config options to be set in the ingress controller.
- Allow user-alertmanager to be deployed in custom namespace and not only in `monitoring`.
- Support for GCS
- Backup retention for InfluxDB.
- Add Okta as option for OIDC provider
- Dex configuration to accept groups from Okta as an OIDC provider
- Added record `cluster.name` in all logs to elasticsearch that matches the cluster setting `global.clusterName`

### Changed

- The `stable/nginx-ingress` helm chart has been replaced by `ingress-nginx/ingress-nginx`
  - Configuration for nginx has changed from `nginxIngress` to `ingressNginx`
- Harbor chart has been upgraded to version 1.5.1
- Helm has been upgraded to v3.4.1
- Grafana has been updated to a new chart repo and bumped to version 5.8.16
- Bump `kubectl` to 1.17.11
- useRegionEndpoint moved to fluentd conf.
- Dex application upgraded to v2.26.0
- Dex chart updated to v2.15.2
- The issuer for the user-alertmanager ingress is now taken from `global.issuer`.
- The `stable/prometheus-operator` helm chart has been replaced by `prometheus-community/kube-prometheus-stack`
- InfluxDB helm chart upgraded to `4.8.10`
- Rework of the InfluxDB configuration.
- The sized based retention for InfluxDB has been lowered in the dev flavor.
- Bump opendistro helm chart to `1.10.4`.
- The configuration for the opendistro helm chart has been reworked.
Check the release notes for more information on replaces and removed options.
One can now for example configure:
  - Role and subject key for OIDC
  - Tolerations, affinity, nodeSelecor, and resources for most components
  - Additional opendistro security roles, ISM policies, and index templates
- OIDC is now enabled by default for elasticsearch and kibana when using the prod flavor
- Updated user grafana chart to 6.1.11 and app version to 7.3.3

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
- The wc fluentd tolerations and nodeSelector configuration options are now only specified in the configuration file.
- Helmfile install error on `user-alertmanager` when `user.alertmanager.enabled: true`.
- The wrong job name being used for the alertmanager rules in wc when `user.alertmanager.enabled: true`.
- Wrong password being used for user-alertmanager.

### Removed

- Broken OIDC configuration for the ops Grafana instance has been removed.
- Unused alertmanager retention configuration from workload cluster
