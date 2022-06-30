### Release notes

### Updated

### Changed
- Renamed `predictLinear` alerts to `capacityManagementAlerts`
- The `capacitymanagementAlerts` for CPU and Memory request alerts are now per cluster and you can add a `pattern` in the configs, `.prometheus.capacityManagementAlerts.requestlimit`, to create an alert for a certain group of nodes

### Fixed

- Pass snapshot list by tempfile in opensearch-slm to prevent piped commands to fail due to short circuiting

### Added

### Removed
