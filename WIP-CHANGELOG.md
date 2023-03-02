### Release notes

- alertmanager:
  - using`regex` field from the `Matcher` type is deprecated and it will be removed in a future version. See [CHANGELOG](https://github.com/prometheus-operator/prometheus-operator/blob/main/CHANGELOG.md#0570--2022-06-02)
  - added support for new matching syntax in the routes configuration of the AlertmanagerConfig CRD. See [CHANGELOG](https://github.com/prometheus-operator/prometheus-operator/blob/main/CHANGELOG.md#0530--2021-12-16)
- kube-prometheus-stack:
  - the portName for alertmanager and prometheus have been renamed from `web` to `http-web`. If this port names are used by you apllication or to port-forward to prometheus/alertmanager, you will need to update them to `http-web` or use the port numbers instead (e.g 9090 for prometheus and 9093 for alertmanager)
  - added default metric relabelings for cAdvisor and apiserver metrics to reduce cardinality. See [CHANGELOG](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-36x-to-37x)

### Added

- Add PrometheusRule to alert for dropped packets to/from workloads.
- Add Gatekeeper PSPs for ingress-nginx and monitoring namespaces.

### Fixed

- Increased interval for rook-ceph service monitor which fixes the grafana dashboard
- Add document splits to helmfiles to prepare support for helmfile v0.150+
- Added option to use nodePort for ingress-nginx.
- Correct version checks in migration script library
- Run migration apply snippet without filters
- Add enabled checks for Fluentd network policies

### Updated

- `responseObject` and `requestObject` are no longer dropped in Fluentd from Kubernetes audit events.
- kube-prometheus-stack chart to v45.2.0. Full [CHANGELOG](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-44x-to-45x)
- prometheus-operator to v0.63.0
- grafana to v9.3.8

### Changed
- Changed timekey to `stageTimestamp` for Kubernetes audit logs. Use `auditID` to correlate stages of the same request.

- vulnerability and kube-bench reporter runs as non root.

### Removed

- Kubernetes PSP for ingress-nginx and monitoring namespace.
