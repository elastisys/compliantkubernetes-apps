### Fixed


### Changed

- The Service Cluster Prometheus now alerts based on Falco metrics. These alerts are sent to Alertmanager as usual so they now have the same flow as all other alerts. This is in addition to the "Falco specific alerting" through Falco sidekick.


### Removed

- Removed namespace `gatekeeper` from bootstrap.
  The namespace can be safely removed from clusters running ck8s  v0.13.0 or later.
