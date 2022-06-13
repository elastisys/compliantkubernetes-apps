### Release notes

### Updated

- Update the Velero plugin for AWS to v1.3.1

### Changed

- Bump falco-exporter chart to v0.8.0.
- Users are now not forced to use proxy for connecting to alertmanager but can use port-forward as well.

### Fixed

- `prometheus-blackbox-exporter's` internal thanos servicemonitor changed name to avoid name collisions.
- dex `topologySpreadConstraints` matchLabel was changed from `app: dex` to `app.kubernetes.io/name: dex` to increase stability of replica placements.
- Fixed issue where user admin groups wasn't added to the user alertmanager rolebinding

### Added

- Add option to encrypt off-site buckets replicated with rclone sync
- Added metrics for field mappings and an alert that will throw an error if the fields get close to the max limit.

### Removed
- wcReader mentions from all configs files
