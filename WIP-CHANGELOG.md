### Added

- Script to restore Harbor from backup

### Fixed

- Elasticsearch slm now deletes excess snapshots also when none of them are older than the maximum age

### Changed

- The Service Cluster Prometheus now alerts based on Falco metrics. These alerts are sent to Alertmanager as usual so they now have the same flow as all other alerts. This is in addition to the "Falco specific alerting" through Falco sidekick.
- Elasticsearch slm now deletes indices in bulk
- Default to object storage disabled for the dev flavor.

### Removed

- Removed namespace `gatekeeper` from bootstrap.
  The namespace can be safely removed from clusters running ck8s  v0.13.0 or later.
