### Fixed


### Changed

- The Service Cluster Prometheus now alerts based on Falco metrics. These alerts are sent to Alertmanager as usual so they now have the same flow as all other alerts. This is in addition to the "Falco specific alerting" through Falco sidekick.
