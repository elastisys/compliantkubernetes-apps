### Release notes

### Updated

### Changed

- Set S3 region in OpenSearch config
- Bump kubectl version to v1.22.6
- Patched Falco rules for  `write_etc_common` , `Launch Package Management Process in Container` , `falco_privileged_images` & `falco_sensitive_mount_containers`. Will be removed if upstream Falco Chart accepts these.
- Improved error handling for applying manifests in wc deploy script
- `kube-prometheus-stack-alertmanager` is configured to have 2 replicas to increase stability and make it highly available.

### Fixed

- Issue where users couldn't do `POST` or `DELETE` requests to alertmanager via service proxy
- Fixed deploy script with correct path to `extra-user-view` manifest.
- Fixed issue when `keys` in config had `'.'` in its name and was being moved from `sc/wc` to `common` configs.

### Added

- Added support for Elastx
- Added support for UpCloud
- Made thanos storegateway persistence size configurable
- New 'Welcoming' Opensearch dashboard / home page.
- New 'Welcoming' Grafana dashboard / home page.
- Add allowlisting for kubeapi-metrics (wc) and thanos-receiver (sc) endpoints

### Removed
