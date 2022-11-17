### Release notes

### Updated

### Changed

- Updated Rook alerts to the ones provided by Rook `v1.10.5`
- Disabled all collectors for node-exporter in ciskubebench- and vulnerability-exporter except textcollector
- Increased the default CPU limit for node-exporter in ciskubebench- and vulnerability-exporter
- Nginx controller service annotations are now defined as a map, previously just a single string.

### Fixed

- Used FQDN for services connecting from the workload cluster to the service cluster to prevent resolve timeouts

### Added

- Starboard resources will now be removed when running the cleanup scripts - `scripts/clean-{sc,wc}.sh`.

### Removed

- Prometheus recording rules for Rook.
