### Release notes

- Configuration for the certificate issuers has been changed and requires running the [migration script](migration/v0.6.x-v0.7.x/migrate-issuer-config.sh).
- Configuration for harbor has been changed and requires running init and apply again.

### Added

- Configurable persistence size in Harbor
- Support for providing certificate issuer manifests to override default issuers.
- Configurable extra role mappings in Elasticsearch
- Added falco exporter to workload cluster
- Falco dashboard added to Grafana

### Changed

- Configuration value `global.certType` has been replaced with `global.issuer` and `global.verifyTls`.
- Certificate issuer configuration has been changed from `letsencrypt` to `issuers.letsencrypt` and extended to support more issuers.
- Explicitly disabled multitenancy in Kibana.
- Cloud provider dependencies are removed from the templates, instead, keys are added to the sc|wc-config.yaml by the init script so no more "hidden" config. This requires a re-run of ck8s init or manully adding the missing keys.
- Ingress nginx has been updated to a new chart repo and bumped to version 2.10

### Fixed

- Kibana OIDC logout not redirecting correctly.
- Getting stuck at selecting tenant when logging in to Kibana.
- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
