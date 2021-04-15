### Changed

- Only install rbac for user alertmanager if it's enabled.
- Convert all values to integers for elasticsearch slm cronjob
- The script for generating a user kubeconfig is now `bin/ck8s kubeconfig user` (from `bin/ck8s user-kubeconfig`)
- Harbor have been updated to v2.2.1.

### Fixed

- When using harbor together with rook there is a potential bug that appears if the database pod is killed and restarted on a new node. This is fixed by upgrading the Harbor helm chart to version 1.6.1.

### Added

- Authlog now indexed by elasticsearch
- Added a ClusterRoleBinding for using an OIDC-based cluster admin kubeconfig and a script for generating such a kubeconfig (see `bin/ck8s kubeconfig admin`)
- S3-exporter for collecting metrics about S3 buckets.
- Dashboard with common things to check daily, e.g. object storage usage, Elasticsearch snapshots and InfluxDB database sizes.

### Removed

- Removed the functionality to automatically restore InfluxDB and Grafana when running `bin/ck8s apply`. The config values controlling this (`restore.*`) no longer have any effect and can be safely removed.
