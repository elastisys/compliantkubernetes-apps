### Release notes

- Configuration for harbor and cert-manager has been changed and requires running init and apply again.
- Configuration for velero, prometheus wc scraper, fluentd and grafana has been changed and requires running init again.

### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero
- Ability to add extra volumes and volumemounts to prometheus wc scraper.
- Ability to add extra volumes and volumemounts to fluentd in the workload cluster.
- Ability to specify certificate authority in fluentd in the workload cluster.
- Extra Configmap mounts can be configured for the user Grafana.
- Harbor can be configured to trust a specific CA bundle

### Changed

- Ingress nginx has been updated to a new chart repo and bumped to version 2.10
- Harbor chart has been upgraded to version 1.5.1

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
- The wc fluentd tolerations and nodeSelector configuration options are now only specified in the configuration file.
