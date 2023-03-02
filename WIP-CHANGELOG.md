### Release notes

- The Fluentd deplyoment has changed considerably and users must ensure that their custom filters continues to work as expected.
- In 1.10 the containers in pods created by cert-manager have been renamed to better reflect what they do. This can be breaking for automation that relies on these names being static.
- In 1.11 the cert-manager Gateway API integration uses the v1beta1 API version. ExperimentalGatewayAPISupport alpha feature users must ensure that v1beta of Gateway API is installed in cluster.
- Releases now have constraints set on them to ensure the stability of upgrades and updates and to better match the expected changes within releases, you can find them in the release document.
- The upgrade process has changed considerably checkout the migration guide, it also contains information about how to follow the new process when writing migration steps

### Added

- Enable rook-ceph network polices by default for exoscale
- Troubleshooting scripts for HNC
- Tests for Groups RBAC
- the possibility to add static users for opensearch
- Support for extracting and storing audit logs with Fluentd
- Compaction for logs stored directly in object store by Fluentd
- New 'Log review overview' Opensearch dashboard
- Added falco rules to ignore redis operator related alerts.
- Add PrometheusRule to alert packets to/from workloads are dropped.
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
- Upgraded the cert-manager helm chart to `v1.11.0` which upgrades the app version to `v1.11.0`
- Update deploy-wc.sh to create `extra-workload-admins` rolebinding on all user namespaces.
- Update harbor backup job api version
- The upgrade process has changed considerably, checkout the migration guide it also contains information about how to follow the new process when writing migration steps

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
- Gatekeeper default enforcements have been changed for certain policies
  - Disallow latest tag default is now `deny`, was `dryrun`
  - Require trusted image registry default is now `warn`, was `deny`
  - Require network policies default is now `warn`, was `deny`
- Moved creation of `extra-workload-admins` to the `user-rbac` chart

### Removed

- GCS support for Fluentd
