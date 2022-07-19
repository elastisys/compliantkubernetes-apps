### Release notes

### Updated
- Helm upgraded to `v3.8.0`.
- Helmfile upgraded to `v0.144.0`.
- Helm-secrets upgraded to `v3.12.0`.

### Changed
- Renamed `predictLinear` alerts to `capacityManagementAlerts`
- The `capacitymanagementAlerts` for CPU and Memory request alerts are now per cluster and you can add a `pattern` in the configs, `.prometheus.capacityManagementAlerts.requestlimit`, to create an alert for a certain group of nodes
- Increased blackbox exporter default resources to reduce cpu throttling.
- Add the alertmanager namespace to wc velero, only if `user.alertmanager` is enabled

### Fixed

- Pass snapshot list by tempfile in opensearch-slm to prevent piped commands to fail due to short circuiting

### Added

### Removed
