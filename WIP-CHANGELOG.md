### Release notes

- Configuration for harbor and cert-manager has been changed and requires running init and apply again.
- Configuration for velero has been changed and requires running init again.
- Helm has been upgraded to v3.4.1. Please upgrade the local binary.
- The Helm repository `stable` has changed URL and has to be changed manually:
  `helm repo add "stable" "https://charts.helm.sh/stable" --force-update`
- The blackbox chart has a changed dependency URL and has to be updated manually:
  `cd helmfile/charts/blackbox && helm dependency update`
- With the replacement of the helm chart `stable/nginx-ingress` to `ingress-nginx/ingress-nginx`, it is required to manually execute some steps to upgrade.
See [migrations docs for nginx](migration/v0.7.x-v0.8.x/nginx.md) for instruction on how to perform the upgrade.
- The config option `nginxIngress.controller.daemonset.useHostPort` has been replaced by `ingressNginx.controller.useHostPort`.
Make sure to remove the old option from your config when upgrading.

### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero
- Add `./bin/ck8s ops helm` to allow investigating issues between `helmfile` and `kubectl`.
- Allow nginx config options to be set in the ingress controller.

### Changed

- The `stable/nginx-ingress` helm chart has been replaced by `ingress-nginx/ingress-nginx`
  - Configuration for nginx has changed from `nginxIngress` to `ingressNginx`
- Harbor chart has been upgraded to version 1.5.1
- Helm has been upgraded to v3.4.1
- Grafana has been updated to a new chart repo and bumped to version 5.8.16

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
- The wc fluentd tolerations and nodeSelector configuration options are now only specified in the configuration file.
- Helmfile install error on `user-alertmanager` when `user.alertmanager.enabled: true`.

### Removed

- Broken OIDC configuration for the ops Grafana instance has been removed.
