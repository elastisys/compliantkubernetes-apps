# Updated

- Updated influxdb chart to 4.8.13

### Changed

- ingress-nginx increased the value for client-body-buffer-size from 16K to 256k
- Lowered default falco resource requests
- charts/grafana-ops:
  1. create one ConfigMap for each dashboard
  1. add differenet values for "labelKey" so we can separate the user and ops dashboards in Grafana
  1. the chart template to automatically load the dashboards enabled in the values.yaml file
- grafana-user.yaml.gotmpl to load only the ConfiMaps that have the value of "1" fron "labelKey"

### Fixed

### Added

### Removed
