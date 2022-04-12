### Release notes

### Updated

### Changed
- Added the repo - "quay.io/jetstack/cert-manager-acmesolver" in allowrepo safeguard by default.
- Backup operator namespaces can for example be added as veloro parameters to be able to back them up. 'alertmanager' is added as default in the workload cluster.
- Set 'continue_if_exception' in curator as to not fail when a snapshot is in progress and it is trying to remove some indices.
- Vulnerability scanner reports ttl is now set to 720 hours, i.e., 30 days.
  - Reports will now be deleted every 30 days by the operator and newer reports are generated.
  - Older reports that are not created with ttl parameter set, should be deleted manually.
- Users are now allowed to get ClusterIssuers.
- Changed the container names of the vulnerability exporter to a bit more meaningful ones.
- Added persistence to alertmanager.
- made the [CISO grafana dashboards](https://elastisys.io/compliantkubernetes/ciso-guide/) visible to the end-users
- indices.query.bool.max_clause_count is now configurable.
- Patched Falco rules for  `k8s_containers` , `postgres_running_wal_e` & `user_known_contact_k8s_api_server_activities`. Will be removed if upstream Falco Chart accepts these.
- Added the user-permissions available pre-defined alerting roles for opensearch.
- PrometheusBlackboxExporter targets with customized propes added for internal service health-checking.
- The dex chart has been upgraded from version 0.6.3 to 0.8.1. Dex has changed to have two replicas to increase the stability of OpenSearch's authentication. A dex ServiceMonitor has also been enabled
- Self service: User admins are now allowed to add new users to the clusterrole user-view. Clusterrole and Clusterrolebinding has been added accordingly.

### Fixed
- Use `master` tag for the grafana-label-enforcer as the previous sha used no longer exist.
- The opensearch SLM job now uses `/_cat/snapshots` to make it work better when there are a large amount of snapshots available.
- predictlinear alerts
- Calico-accountant is now being scheduled on master nodes.
- it is now possible to set tolerations and affinity for vulnerability-exporter
- SC log retention no longer fails silently after removing one day of logs.

### Added
- the possibility to add falco custom rules for each environment
- New Grafana dashboard that shows how many timeseries there are in Prometheus.
- Added the alternative port for kubelogin (18000) to be an allowed redirect url by default.

### Removed
