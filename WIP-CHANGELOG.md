### Release notes

- In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, have been removed from the custom resource definitions (CRDs).
- In 1.8 the cert-manager will validate the spec.privateKey.rotationPolicy on Certificate resources. Valid options are Never and Always.
- Automated CIS tests are preformed on each node using kube-bench

### Updated

### Changed
- OIDC scope to include groups for all services
- OIDC enabled by default for ops grafana

- The ThanosReceiveHttpRequestErrorRateHigh, OpenSearchTooFewNodesRunning, and MetricsFromScClusterIsMissing prometheus-alerts were optimized to not be triggered by kured and to reduce other unwanted behaviors.
- Support section of the grafana/opensearch welcome dashboards is removed by default, you can now add custom text at the end of the dashboards via the sc-config.
- OpenSearch has been upgraded from version `v1.3.4` to `v2.6.0`. Our fluentd-plugins was also changed from using "fluent-plugin-opensearch: 1.0.2" to "fluent-plugin-opensearch: 1.0.8".

### Fixed
- Fixed so grafana can show data from thanos that's older than 30 days (downsampled data)
- Fixed so opensearch field limit alert handles metrics drop better

### Added

- Option to create custom solvers for letsencrypt issuers, including a simple way to add secrets.
- Add external redis database as option for harbor
- a new alert `FluentdAvailableSpaceBuffer`, notifies when the fluentd buffer is filling up
- Option to enable `allowSnippetAnnotations` from the configs
- the possibility to enable falco in the service cluster
- Kube-bench runs on every node
- Added a CIS kube-bench Grafana dashboard
- Added `topologySpreadConstraints` rule to thanos and kube-prometheus-stack.
- Network policies for harbor
- Added option for kured to notify to slack when draning and rebooting nodes.
- Added group subjects to `falco-viewer` and `fluentd-configurer` rolebindings.
- Allow users to proxy and port-forward to prometheus running in the workload cluster

### Removed

- `readall_and_monitor` from `extraRoleMappings` in opensearch configuration
