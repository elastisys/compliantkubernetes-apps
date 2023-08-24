### Release notes

### Added

- Extra component versions can be added in the Welcome dashboard via config

### Changed

- Moved `rclone-sync` from `kube-system` to its own namespace.
- Moved all the kube-prometheus-stack Grafana dashboards to `grafana-dashboards` chart

### Fixed

- Refer to Grafana, OpenSearch and Harbor as Web Portals in Grafana and OpenSearch welcome dashboards
- Fixed the `csi-upcloud` Network Policy template.

### Updated

- Upgraded falco-exporter chart version to `v0.9.6` and app version to `v0.8.3`

### Removed

- The deprecated `Image vulnerabilities` dashboard
