<<<<<<< HEAD
### Release notes

### Updated

- Update the Velero plugin for AWS to v1.3.1

### Changed

- Bump falco-exporter chart to v0.8.0.

### Fixed

- `prometheus-blackbox-exporter's` internal thanos servicemonitor changed name to avoid name collisions.
- dex `topologySpreadConstraints` matchLabel was changed from `app: dex` to `app.kubernetes.io/name: dex` to increase stability of replica placements.

### Added

- Add option to encrypt off-site buckets replicated with rclone sync

### Removed
=======
>>>>>>> 6b55c5a (Reset changelog for release v0.21.2)
