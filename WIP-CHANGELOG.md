### Release notes

### Updated

### Changed

### Fixed

- `prometheus-blackbox-exporter's` internal thanos servicemonitor changed name to avoid name collisions.
- dex `topologySpreadConstraints` matchLabel was changed from `app: dex` to `app.kubernetes.io/name: dex` to increase stability of replica placements.

### Added

- Add option to encrypt off-site buckets replicated with rclone sync

### Removed
