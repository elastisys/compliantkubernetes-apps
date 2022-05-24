### Release notes

### Updated

### Changed

- Set S3 region in OpenSearch config
- Bump kubectl version to v1.22.6
- Patched Falco rules for  `write_etc_common` , `Launch Package Management Process in Container` , `falco_privileged_images` & `falco_sensitive_mount_containers`. Will be removed if upstream Falco Chart accepts these.
- Improved error handling for applying manifests in wc deploy script
- `kube-prometheus-stack-alertmanager` is configured to have 2 replicas to increase stability and make it highly available.
- Add pattern `security-auditlog-*` to default retention for Curator

### Fixed

- Issue where users couldn't do `POST` or `DELETE` requests to alertmanager via service proxy
- Fixed deploy script with correct path to `extra-user-view` manifest.
- Fixed issue when `keys` in config had `'.'` in its name and was being moved from `sc/wc` to `common` configs.
- Fixed broken index per namespace feature for logging. The version of `elasticsearch_dynamic` plugin in Fluentd no longer supports OpenSearch. Now the OpenSearch output plugin is used for the feature thanks to the usage of placeholders.
- Fixed conflicting type `ts` in opensearch, where multiple services log `ts` as different types.
- Fixed conflicting type `@timestamp`, should always be `date` in opensearch.
- Fluentd no longer tails its own container log. Fixes the issue when Fluentd failed to push to OpenSearch and started filling up its logs with `\`. Because recursive logging of its own errors to OpenSearch which kept failing and for each fail adding more `\`.
- Split the grafana-ops configmaplist into separate configmaps, which in some instances caused errors in helm due to the size of the resulting resource
- PrometheusNotConnectedToAlertmanagers alert will be sent to `null` if Alertmanger is disabled in wc
- Removed undefined macro preventing falco rules to be compiled

### Added

- Added support for Elastx
- Added support for UpCloud
- Made thanos storegateway persistence size configurable
- New 'Welcoming' Opensearch dashboard / home page.
- New 'Welcoming' Grafana dashboard / home page.
- Add allowlisting for kubeapi-metrics (wc) and thanos-receiver (sc) endpoints
- Add support for running prometheus in HA mode
- Add option for deduplication/vertical compaction with thanos-compactor

### Removed

- Removed disabled releases from helmfile
