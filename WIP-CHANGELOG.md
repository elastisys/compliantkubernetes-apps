### Release notes

- Removed unused config `global.environmentName` and added `global.clusterName` to migrate there's [this script](migration/v0.8.x-v0.9.x/migrate-config.sh)
- To udate the password for `user-alertmanager` you'll have to re-install the chart
  `./bin/ck8s ops helmfile wc -l app=user-alertmanager destroy && ./bin/ck8s ops helmfile wc -l app=user-alertmanager apply`
- With the replacement of the helm chart `stable/elasticsearch-exporter` to `prometheus-community/prometheus-elasticsearch-exporter`, it is required to manually execute some steps to upgrade.
See [migrations docs for elasticsearch-exporter](migration/v0.8.x-v0.9.x/migrate-elasticsearch-exporter.md) for instructions on how to perform the upgrade.
- Configuration regarding backups (in general) and harbor storage have been changed and requires running init again. If `harbor.persistence.type` equals `s3` or `gcs` in your config you must update it to `objectStorage`.
- Some configuration options must be manually updated.
  See [the complete migration guide for all details](migration/v0.8.x-v0.9.x/upgrade-apps.md)
- A few applications require additional steps.
  See [the complete migration guide for all details](migration/v0.8.x-v0.9.x/upgrade-apps.md)
- With the removal of `scripts/post-infra-common.sh` you'll now have to, if enabled, manually set the address to the nfs server in `nfsProvisioner.server`
- The cert-manager CustomResourceDefinitions has been upgraded to `v1`, see [API reference docs](https://cert-manager.io/docs/reference/api-docs/). It is advisable that you update your resources to `v1` in the near future to maintain functionality.
- The cert-manager letsencrypt issuers have been updated to the `v1` API and the old `letsencrypt` releases must be removed before upgrading. Instruction are found in the [upgrade guide](migration/v0.8.x-v0.9.x/upgrade-apps.md).
- To get some of the new default values for resource requests on Harbor pods you will first need to remove the resource requests that you have in your Harbor config and then run `ck8s init` to get the new values.

### Added

- Dex configuration to accept groups from Okta as an OIDC provider
- Added record `cluster.name` in all logs to elasticsearch that matches the cluster setting `global.clusterName`
- Role mapping from OIDC groups to roles in user grafana
- Configuration options regarding resources/tolerations for prometheus-elasticsearch-exporter
- Options to disable different types of backups.
- Harbor image storage can now be set to `filesystem` in order to use persistent volumes instead of object storage.
- Object storage is now optional. There is a new option to set object storage type to `none`. If you disable object storage, then you must also disable any feature that uses object storage (mostly all backups).
- Two new InfluxDB users to used by prometheus for writing metrics to InfluxDB.
- Multicluster support for some dashboards in Grafana.
- More config options for falco sidekick (tolerations, resources, affinity, and nodeSelector)
- Option to configure serviceMonitor for elasticsearch exporter
- Option to add more redirect URIs for the `kubelogin` client in dex.
- Option to disable the creation of user namespaces (RBAC will still be created)
- The possibility to configure resources, affinity, tolerations, and nodeSelector for all Harbor pods.

### Changed

- Updated user grafana chart to 6.1.11 and app version to 7.3.3
- The `stable/elasticsearch-exporter` helm chart has been replaced by `prometheus-community/prometheus-elasticsearch-exporter`
- OIDC group claims added to Harbor
- The options `s3` and `gcs` for `harbor.persistence.type` have been replaced with `objectStorage` and will then match the type set in the global object storage configuration.
- Bump kubectl to v1.18.13
- InfluxDB is now exposed via ingress.
- Prometheus in workload cluster now pushes metrics directly to InfluxDB.
- The prometheus release `wc-scraper` has been renamed to `wc-reader`.
  Now wc-reader only reads from the workload_cluster database in InfluxDB.
- InfluxDB helm chart upgraded to `4.8.11`.
- `kube-prometheus-stack` updated to version `12.8.0`.
- Bump prometheus to `2.23.0`.
- Added example config for Kibana group mapping from an OIDC provider
- Replaced `kiwigrid/fluentd-elasticsearch` helm chart with `kokuwa/fluentd-elasticsearch`.
- Replaced `stable/fluentd` helm chart with `bitnami/fluentd`.
- StorageClasses are now enabled/disabled in the `{wc,sc}-cofig.yaml` files.
- Mount path and IP/hostname is now configurable in `nfs-client-provisioner`.
- Upgraded `cert-manager` to `1.1.0`.
- Moved the `bootstrap/letsencrypt` helm chart to the apps step and renamed it to `issuers`.
  The issuers are now installed after cert-manager.
  You can now select which namespaces to install the letsencrypt issuers.
- Helm upgraded to `v3.5.0`.
- InfluxDB upgraded to `v4.8.12`.
- Resource requests/limits have been updated for all Harbor pods.

### Fixed

- Wrong password being used for user-alertmanager.
- Retention setting for wc scraper always overriding the user config and being set to 10 days.
- Blackbox exporter checks kibana correctly
- Removed duplicate enforcement config for OPA from wc-config
- Fixed issue with adding annotation to bootstrap namespace chart

### Removed
- The following helm release has been deprecated and will be uninstalled when upgrading:
  - `wc-scraper`
  - `prometheus-auth`
  - `wc-scraper-alerts`
  - `fluentd-aggregator`
- Helm chart `basic-auth-secret` has been removed.
- Unused config option `dnsPrefix`.
- Removed `scripts/post-infra-common.sh` file.
- The image scanner Clair in Harbor, image scanning is done by the scanner Trivy
