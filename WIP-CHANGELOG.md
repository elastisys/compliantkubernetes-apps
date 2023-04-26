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
- Possibility to enable metrics for Cluster API in `kube-state-metrics`.
- Add node-local-dns Grafana dashboard
- Add gatekeeper mutation for setting seccomp profile
- Allow drop all capabilites mutation to be disabled per service
- Added annotation for the grafana dashboard "Compute Resources / Pod" to show container restarts
- Added so Grafana egress can be configured from sc-config.

### Fixed

- Fixed issue with compaction job on ephemeral volumes
