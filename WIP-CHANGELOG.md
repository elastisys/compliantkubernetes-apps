### Release notes

### Updated

### Changed

- Set S3 region in OpenSearch config
- Bump kubectl version to v1.22.6
- Patched Falco rules for  `write_etc_common` , `Launch Package Management Process in Container` , `falco_privileged_images` & `falco_sensitive_mount_containers`. Will be removed if upstream Falco Chart accepts these.

### Fixed

- Issue where users couldn't do `POST` or `DELETE` requests to alertmanager via service proxy

### Added

- Added support for UpCloud
- Made thanos storegateway persistence size configurable
- New 'Welcoming' Opensearch dashboard / home page.
- New 'Welcoming' Grafana dashboard / home page.

### Removed
