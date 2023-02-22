### Release notes

- The Fluentd deplyoment has changed considerably and users must ensure that their custom filters continues to work as expected.

### Added

- Enable rook-ceph network polices by default for exoscale
- Troubleshooting scripts for HNC
- Tests for Groups RBAC
- the possibility to add static users for opensearch
- Support for extracting and storing audit logs with Fluentd
- Compaction for logs stored directly in object store by Fluentd
- New 'Log review overview' Opensearch dashboard

### Fixed

- The update-ips script can now fetch Calico Wireguard IPs
- The update-ips script can now fetch object storage sync destination IPs
- The test scripts can now always access the kubeconfig
- The OpenSearch network policies now properly work with dedicated nodes and shapshots enabled
- The `clean-sc` script now patches any pending challenges which would prevent the removal of certain namespaces

### Updated

- The NetworkPolicy Dashboard have been updated to be more clear
- Upgraded the Starboard-operator helm chart to `0.10.11` which upgrades the app version to `0.15.11`
- Upgrade Gatekeeper helm chart to `v3.11.0`, which also upgrades Gatekeeper to `v3.11.0`
- Updated Gatekeeper Dashboard to new one from upstream
- Renamed the ElasticSearch Dashboard to Opensearch in Grafana
- Changed release name for `prometheus-elasticsearch-exporter` to `prometheus-opensearch-exporter`

### Changed

- Thanos Rulers now sends alerts to all Alertmanagers in an HA setup, sends requests directly to Queries, and are now accessible by Queries
- Thanos components now use DNS SD to automatically find healthy replicas
- Alerts can now be inspected in ops Grafana
- Updated metrics-server chart to 0.6.2 which upgrades metrics-server to 3.8.3
- Allow the creation of arbitrary network-policy in wc
- Network polices
  - Added missing network policy for rook-ceph-csi-detect-version for rook-ceph v1.10
- Upgraded the kured helm chart to `4.4.1` which upgrades the app version to `1.12.1`
- Fluentd in both SC and WC now use the `fluentd-elasticsearch` chart for forwarding, and the `fluentd` chart for aggregating
  - This have changed the deployment for Fluentd considerably and users must ensure that their custom filter continues to work as expected
- Retention for logs stored directly in object store have been reworked
- Updated alertmanager network policy to allow ingress traffic from user pods.

### Removed

- GCS support for Fluentd
