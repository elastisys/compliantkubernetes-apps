### Release notes

- Removed unused config `global.environmentName` and added `global.clusterName` to migrate there's [this script](migration/v0.8.x-v0.9.x/migrate-config.sh)
- To udate the password for `user-alertmanager` you'll have to re-install the chart
  `./bin/ck8s ops helmfile wc -l app=user-alertmanager destroy && ./bin/ck8s ops helmfile wc -l app=user-alertmanager apply`
- With the replacement of the helm chart `stable/elasticsearch-exporter` to `prometheus-community/prometheus-elasticsearch-exporter`, it is required to manually execute some steps to upgrade.
See [migrations docs for elasticsearch-exporter](migration/v0.8.x-v0.9.x/migrate-elasticsearch-exporter.md) for instructions on how to perform the upgrade.
- Configuration regarding backups (in general) and harbor storage have been changed and requires running init again. If `harbor.persistence.type` equals `s3` or `gcs` in your config you must update it to `objectStorage`.
- Some configuration options must be manually updated.
  See [the complete migration guide for all details](migration/v0.8.x-v0.9.x/migrate-apps.md)
- A few applications require additional steps.
  See [the complete migration guide for all details](migration/v0.8.x-v0.9.x/migrate-apps.md)

### Added

- Dex configuration to accept groups from Okta as an OIDC provider
- Added record `cluster.name` in all logs to elasticsearch that matches the cluster setting `global.clusterName`
- Role mapping from OIDC groups to roles in user grafana
- Configuration options regarding resources/tolerations for prometheus-elasticsearch-exporter
- Options to disable different types of backups.
- Harbor image storage can now be set to `filesystem` in order to use persistent volumes instead of object storage.
- Object storage is now optional. There is a new option to set object storage type to `none`. If you disable object storage, then you must also disable any feature that uses object storage (mostly all backups).
- Two new InfluxDB users to used by prometheus for writing metrics to InfluxDB.

### Changed

- Updated user grafana chart to 6.1.11 and app version to 7.3.3
- The `stable/elasticsearch-exporter` helm chart has been replaced by `prometheus-community/prometheus-elasticsearch-exporter`
- OIDC group claims added to Harbor
- The options `s3` and `gcs` for `harbor.persistence.type` have been replaced with `objectStorage` and will then match the type set in the global object storage configuration.
- Bump kubectl to v1.18.13
- Prometheus upgraded to 2.23.0.
- InfluxDB is now exposed via ingress.
- Prometheus in workload cluster now pushes metrics directly to InfluxDB.
- The prometheus release `wc-scraper` has been renamed to `wc-reader`.
  Now wc-reader only reads from the workload_cluster database in InfluxDB.
- InfluxDB helm chart upgraded to `4.8.11`.

### Fixed

- Wrong password being used for user-alertmanager.
- Retention setting for wc scraper always overriding the user config and being set to 10 days.

### Removed

- Release `prometheus-auth` has been removed.
- Helm chart `basic-auth-secret` has been removed.
