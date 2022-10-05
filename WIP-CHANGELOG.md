### Release notes

### Updated

- Updated dex chart to `v0.12.0` which upgraded dex to `v2.35.1`

### Changed

- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service
- Upgrade Velero helm chart to `v2.31.8`, which also upgrades Velero to `v1.9.2`.
- Update the provider plugins to a supported version for the new Velero release

### Fixed

- Blackbox exporter now looks at the correct error code for the opensearch-dashboards target
- Harbor backup is now pointed to the correct internal service to make backups from
- Bumped backup-postgres image to use tag `1.2.0`, which includes newer versions of the postgresql client
- Fixed Test User RBAC

### Added

- Option to deny network traffic by default
- Network policies for monitoring stack (prometheus, thanos, grafana, some exporters)

### Removed

- Grafana reporting and update checks
