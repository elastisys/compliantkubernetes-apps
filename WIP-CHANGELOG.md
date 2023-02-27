### Release notes

### Added

- Add PrometheusRule to alert for dropped packets to/from workloads.

### Fixed

- Increased interval for rook-ceph service monitor which fixes the grafana dashboard
- Add document splits to helmfiles to prepare support for helmfile v0.150+
- Added option to use nodePort for ingress-nginx.

### Updated
- `responseObject` and `requestObject` are no longer dropped in Fluentd from Kubernetes audit events.

### Changed

### Removed
