### Release notes

### Updated

### Changed

- Updated Rook alerts to the ones provided by Rook `v1.10.5`
- Disabled all collectors for node-exporter in ciskubebench- and vulnerability-exporter except textcollector
- Increased the default CPU limit for node-exporter in ciskubebench- and vulnerability-exporter
- Nginx controller service annotations are now defined as a map, previously just a single string.
- Synced all grafana dashboards so that they use the same timezone, they all now use the default organization timezone.

### Fixed

- Used FQDN for services connecting from the workload cluster to the service cluster to prevent resolve timeouts
- Added generation of registry password so that there's not a diff each time we run apply
- Fixed a templating error which occurs when more than one workload cluster is specified under the `global.clustersMonitoring` in the `sc-config.yaml`
- Fix `KubeletDown` alert rule, did previously not alert if a kubelet was missing.
- Add permissions to the `alerting_full_access` role in Opensearch to be able to view notification channels.
- Fixed network policies for when internal traffic to the ingress is not short circuted by kube-proxy
- `fluent-plugin-record-modifier` was added to our image `ghcr.io/elastisys/fluentd:v3.4.0-ck8s5` to prevent mapping errors from happening
- Fixed harbor restore network policy to allow all egress for the restore job.
- Fixed Harbor network policies
  - Cleaned up `core` egress rule
  - Separate network policies
  - Fixed replication egress rules, `core` and `jobservice`

### Added

-  Network policies for `coredns` and `dnsAutoscaler`.
- Starboard resources will now be removed when running the cleanup scripts - `scripts/clean-{sc,wc}.sh`.
- Added templating for wc Velero bucket prefix.
- Network policies for `rook-ceph` (disabled by default).
- Network policies for `csi-cinder`, `csi-upcloud`, `metrics-server` and `snapshot-controller`.
- Added alert for less kubelets than nodes in the cluster.
- Added alert for object limits in bucket
	- Limits: size and object count.
	- Consult with your cloud provider for specific s3 limits.

### Removed

- Prometheus recording rules for Rook.
- Falco alerts in wc from prometheus. Users will get falco alerts via falco sidekick.
- Legacy datasources from user-grafana: `prometheus-sc` and `prometheus-sc-reader`
- Legacy datasources from grafana-ops: `prometheus-wc-reader`
