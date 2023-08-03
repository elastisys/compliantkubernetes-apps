### Release notes

### Added

- Extra component versions can be added in the Welcome dashboard via config

### Changed

- Moved `rclone-sync` from `kube-system` to its own namespace.

### Fixed

- Grafana user values rendering was failing when whitelistRange was enabled, because of the missing of `annotations` key
- Refer to Grafana, OpenSearch and Harbor as Web Portals in Grafana and OpenSearch welcome dashboards

### Updated

- Upgraded falco-exporter chart version to `v0.9.6` and app version to `v0.8.3`

### Removed
