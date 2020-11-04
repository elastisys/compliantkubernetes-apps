### Release notes

- Configuration for harbor has been changed and requires running init and apply again.

### Added

- Configurable persistence size in Harbor

### Changed

- Ingress nginx has been updated to a new chart repo and bumped to version 2.10

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
