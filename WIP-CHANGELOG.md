### Release notes

- alertmanager:
  - using`regex` field from the `Matcher` type is deprecated and it will be removed in a future version. See [CHANGELOG](https://github.com/prometheus-operator/prometheus-operator/blob/main/CHANGELOG.md#0570--2022-06-02)
  - added support for new matching syntax in the routes configuration of the AlertmanagerConfig CRD. See [CHANGELOG](https://github.com/prometheus-operator/prometheus-operator/blob/main/CHANGELOG.md#0530--2021-12-16)
- kube-prometheus-stack:
  - the portName for alertmanager and prometheus have been renamed from `web` to `http-web`. If this port names are used by you application or to port-forward to prometheus/alertmanager, you will need to update them to `http-web` or use the port numbers instead (e.g 9090 for prometheus and 9093 for alertmanager)
  - added default metric relabeling for cAdvisor and apiserver metrics to reduce cardinality. See [CHANGELOG](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-36x-to-37x)

### Added

- Add PrometheusRule to alert for dropped packets to/from workloads.
- Add Gatekeeper PSPs for ingress-nginx and monitoring namespaces.
- Add Gatekeeper PSPs for Fluentd and OpenSearch
- Add Gatekeeper PSPs for Kured.
- Add Gatekeeper PSPs for Harbor
- Add Gatekeeper mutation for setting job TTL if not already set. By default, a TTL of 7 days will be set.
- Enabled Pod Security Admission for `dex` and `cert-manager`
- Add Gatekeeper PSPs for Velero.
- Metrics and Grafana dashboard for Harbor.
- Added so the user admins can read hierarchyconfigurations.
- Add Gatekeeper PSPs for HNC.
- Add Gatekeeper PSPs for falco.
- Add cache-image workflow

### Fixed

- Increased interval for rook-ceph service monitor which fixes the grafana dashboard
- Add document splits to helmfiles to prepare support for helmfile v0.150+
- Added option to use nodePort for ingress-nginx.
- Correct version checks in migration script library
- Run migration apply snippet without filters
- Add enabled checks for Fluentd network policies
- Add missing PSPs for user Fluentd
- Make `user-rbac` chart `extra-workload-admins` rolebinding idempotent
- Indentation issue in the `fluentd-forwarder-workload-cluster-system` values file.
- Ensure `opensearch-configurer` runs on changes
- Correct `fluentd-aggregator` buffer settings
- Moved tolerations, affinity and resources for `fluentd-aggregator` in `aggregator-common.yaml.gotmpl`
- Source `extra-fluentd-config` user supplied settings
- Change config option `falco.customRules` to a map
- Synced the default prometheus interval with the grafana dashboards and datasources
- Use FQDN for Grafana to Dex communication

### Updated

- `responseObject` and `requestObject` are no longer dropped in Fluentd from Kubernetes audit events.
- kube-prometheus-stack chart to v45.2.0. Full [CHANGELOG](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-44x-to-45x)
- prometheus-operator to v0.63.0
- grafana to v9.3.8
- Upgraded Dex to v2.36.0, chart v0.14.1
- Update pre-commit hooks
- node-local-dns to use image `registry.k8s.io/dns/k8s-dns-node-cache:1.22.20`

### Changed

- Changed timekey to `stageTimestamp` for Kubernetes audit logs. Use `auditID` to correlate stages of the same request.
- vulnerability and kube-bench reporter runs as non root.
- Replace chown init container with fsGroup in OpenSearch
- Restructure Gatekeeper charts and values
- Changed the default promIndexAlerts alertsize for authlog from 0.2 to 2.
- Allow SOPS config to contain multiple creation rules
- Expose all `fluentd-aggregator` buffer settings
- Replace starboard-operator v0.9.1 with trivy-operator v0.13.0. This also includes a grafana dashboard for trivy-operator and another dashboard for ClusterComplianceReport: CIS,NSA and PSS.
- Rework Gatekeeper PSP constraints and mutation to follow PSS in regards to groups
- Allow restricted Gatekeeper PSP mutations to use custom namespace selector
- Increase Gatekeeper controller resources to handle new constraints and mutations

### Removed

- Kubernetes PSP for ingress-nginx and monitoring namespace.
- Remove Kubernetes PSPs for Fluentd and OpenSearch
- Remove Kubernetes PSPs for falco
