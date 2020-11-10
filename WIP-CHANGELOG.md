### Release notes

- Configuration for harbor and cert-manager has been changed and requires running init and apply again.
- Configuration for velero has been changed and requires running init again.
- Helm has been upgraded to v3.4.1. Please upgrade the local binary.
- The Helm repository `stable` has changed URL and has to be changed manually:
  `helm repo add "stable" "https://charts.helm.sh/stable" --force-update`
- The blackbox chart has a changed dependency URL and has to be updated manually:
  `cd helmfile/charts/blackbox && helm dependency update`

### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero
- Add `./bin/ck8s ops helm` to allow investigating issues between `helmfile` and `kubectl`.

### Changed

- Ingress nginx has been updated to a new chart repo and bumped to version 2.10
- Harbor chart has been upgraded to version 1.5.1
- Helm has been upgraded to v3.4.1

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
- The wc fluentd tolerations and nodeSelector configuration options are now only specified in the configuration file.

### Removed

- Broken OIDC configuration for the ops Grafana instance has been removed.
