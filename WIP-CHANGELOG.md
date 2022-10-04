### Release notes

### Updated

### Changed

- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service

### Fixed

- Blackbox exporter now looks at the correct error code for the opensearch-dashboards target

### Added

- Option to deny network traffic by default
- Network policies for monitoring stack (prometheus, thanos, grafana, some exporters)
- An alert for failed evicted pods (KubeFailedEvictedPods)

### Removed

- Grafana reporting and update checks
