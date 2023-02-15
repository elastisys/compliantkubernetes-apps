### Release notes

### Added

- Enable rook-ceph network polices by default for exoscale
- Troubleshooting scripts for HNC
- Tests for Groups RBAC
- the possibility to add static users for opensearch

### Fixed

- The update-ips script can now fetch Calico Wireguard IPs
- The test scripts can now always access the kubeconfig
- The OpenSearch network policies now properly work with dedicated nodes and shapshots enabled
- The `clean-sc` script now patches any pending challenges which would prevent the removal of certain namespaces


### Updated

- The NetworkPolicy Dashboard have been updated to be more clear
- Upgraded the Starboard-operator helm chart to `0.10.11` which upgrades the app version to `0.15.11`

### Changed

- Thanos Rulers now sends alerts to all Alertmanagers in an HA setup, sends requests directly to Queries, and are now accessible by Queries
- Thanos components now use DNS SD to automatically find healthy replicas
- Alerts can now be inspected in ops Grafana
- Updated metrics-server chart to 0.6.2 which upgrades metrics-server to 3.8.3
- Allow the creation of arbitrary network-policy in wc
- Network polices
  - Added missing network policy for rook-ceph-csi-detect-version for rook-ceph v1.10
