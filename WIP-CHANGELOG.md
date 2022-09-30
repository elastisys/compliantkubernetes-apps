### Release notes

### Updated

### Changed
- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days

### Fixed

- Blackbox exporter now looks at the correct error code for the opensearch-dashboards target
- Harbor backup is now pointed to the correct internal service to make backups from
- Bumped backup-postgres image to use tag `1.2.0`, which includes newer versions of the postgresql client

### Added

- Option to deny network traffic by default

### Removed
