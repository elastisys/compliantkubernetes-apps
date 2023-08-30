### Release notes

### Added

- Extra component versions can be added in the Welcome dashboard via config
- Probes from WC to SC to monitor how well clusters reach each other
- Added so `bin/ck8s test` components can be used all at once in a cluster.
- Alerts for Harbor
- The possibility to configure plugins and additional datasources for Grafana
- The possibility to add or overwrite `grafana.ini` configuration

### Changed

- Moved `rclone-sync` from `kube-system` to its own namespace.
- Moved all the kube-prometheus-stack Grafana dashboards to `grafana-dashboards` chart
- Separated node and PV `capacityManagementAlerts` limit configuration
- Replaced image `elastisys/curl-jq:latest` with `ghcr.io/elastisys/curl-jq:1.0.0`.
- Only mutate pods on create to prevent them from getting stuck
- Increased the default `proxy-buffer-size` setting in ingress-nginx to `8k`.
- The Grafana dashboard for Harbor to show the total number of artifacts and storage used per project

### Fixed

- Refer to Grafana, OpenSearch and Harbor as Web Portals in Grafana and OpenSearch welcome dashboards
- Fixed the `csi-upcloud` Network Policy template.
- Pods that are using `curl-jq` image security context

### Updated

- Upgraded falco-exporter chart version to `v0.9.6` and app version to `v0.8.3`

### Removed

- The deprecated `Image vulnerabilities` dashboard
