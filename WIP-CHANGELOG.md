### Release notes
- In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, have been removed from the custom resource definitions (CRDs).
- In 1.8 the cert-manager will validate the spec.privateKey.rotationPolicy on Certificate resources. Valid options are Never and Always.
- Automated CIS tests are preformed on each node using kube-bench

### Updated

### Changed
- OIDC scope to include groups for all services
- OIDC enabled by default for ops grafana

### Fixed
- Fixed so grafana can show data from thanos that's older than 30 days (downsampled data)

### Added
- Option to create custom solvers for letsencrypt issuers, including a simple way to add secrets.
- Add external redis database as option for harbor
- a new alert `FluentdAvailableSpaceBuffer`, notifies when the fluentd buffer is filling up
- Option to enable `allowSnippetAnnotations` from the configs
- the possibility to enable falco in the service cluster
- Kube-bench runs on every node
- Added a CIS kube-bench Grafana dashboard

### Removed
