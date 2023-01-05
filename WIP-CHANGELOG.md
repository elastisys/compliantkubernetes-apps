### Release notes

### Updated

### Changed

### Fixed

- Fixed harbor restore network policy to allow all egress for the restore job.
- `fluent-plugin-record-modifier` was added to our image `ghcr.io/elastisys/fluentd:v3.4.0-ck8s5` to prevent mapping errors from happening
- Added generation of registry password so that there's not a diff each time we run apply
- Fixed network policies for when internal traffic to the ingress is not short circuted by kube-proxy
- Fixed Harbor network policies
  - Cleaned up `core` egress rule
  - Separate network policies
  - Fixed replication egress rules, `core` and `jobservice`

### Added

### Removed

- Falco alerts in wc from prometheus. Users will get falco alerts via falco sidekick.
