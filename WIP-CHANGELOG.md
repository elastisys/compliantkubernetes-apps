### Release notes

### Updated

### Changed

- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service

### Fixed

### Added

- Option to deny network traffic by default
- Network policies for monitoring stack (prometheus, thanos, grafana, some exporters)

### Removed

- Grafana reporting and update checks
