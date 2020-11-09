### Release notes

- Configuration for harbor and cert-manager has been changed and requires running init and apply again.
- Configuration for velero has been changed and requires running init again.

### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero

### Changed

- Ingress nginx has been updated to a new chart repo and bumped to version 2.10
- Harbor chart has been upgraded to version 1.5.1

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
