### Release notes

### Added

- Extra component versions can be added in the Welcome dashboard via config
- Probes from WC to SC to monitor how well clusters reach each other
- Added so `bin/ck8s test` components can be used all at once in a cluster.

### Changed

- Moved `rclone-sync` from `kube-system` to its own namespace.
- Moved all the kube-prometheus-stack Grafana dashboards to `grafana-dashboards` chart
- Separated node and PV `capacityManagementAlerts` limit configuration
- Replaced image `elastisys/curl-jq:latest` with `ghcr.io/elastisys/curl-jq:1.0.0`.
- Only mutate pods on create to prevent them from getting stuck

### Fixed

- Refer to Grafana, OpenSearch and Harbor as Web Portals in Grafana and OpenSearch welcome dashboards
- Fixed the `csi-upcloud` Network Policy template.

### Updated

- Upgraded falco-exporter chart version to `v0.9.6` and app version to `v0.8.3`

### Removed

- The deprecated `Image vulnerabilities` dashboard
