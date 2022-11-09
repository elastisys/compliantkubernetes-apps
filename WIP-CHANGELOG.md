### Release notes

- Several default resource requests and limits have changed. When upgrading these might need to be adjusted.
- The settings for the new Opensearch index size alerts might need to be tweaked to better suit the environment.

### Updated

- Updated dex chart to `v0.12.0` which upgraded dex to `v2.35.1`
- Updated Falco chart to `2.2.0` upgrading Falco itself to `0.33.0` and Falco Sidekick to `2.26.0`
- Updated Falco Exporter chart to `0.9.0` upgrading Falco Exporter itself to `0.8.0`
- Upgrade Velero helm chart to `v2.31.8`, which also upgrades Velero to `v1.9.2`.
- Update the provider plugins to a supported version for the new Velero release
- Upgraded Grafana helm chart to `v6.43.4`, which also upgrades the user-facing Grafana to `v9.2.3`.
- Use Grafana tag `9.2.3` in kube-prometheus-stack.

### Changed

- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service
- Added support for anchors and aliases in override configs, not tested with merge aliases/tags
- Changed the default limit for diskLimit alert, from 66 to 75
- Changed some default resource requests and limits for multiple components
- Gatekeeper audits every 10 min instead of 1 min
- Gatekeeper audit only looks at the resource types mentioned in constraints, instead of all resource types
- Set backoffLimit for rclone-jobs to 0.
- Made dex ID Token expiration time configurable
- Made dex tokens expiry times configurable
- Excluded the `gatekeeper-system` namespace from velero backups in the workload cluster.
- Moved Harbor Swift configuration to `objectStorage.swift` to use the same as for Thanos.
- Rewritten Falco overrides to use user editable macros with is used by upstream configuration.
- User alertmanager is now enabled by default.
- Moved the excluded namespace for velero and hnc from templates to configs.
- Changed so the instance label for node-exporter metrics now uses the node name instead of the IP

### Fixed

- Blackbox exporter now looks at the correct error code for the opensearch-dashboards target
- Harbor backup is now pointed to the correct internal service to make backups from
- Bumped backup-postgres image to use tag `1.2.0`, which includes newer versions of the postgresql client
- Fixed Test User RBAC
- Fixed the shifted comment after running init
- Kubernetes cluster status Grafana dashboard not loading data for some panels
- Fixed inevitable mapping conflicts in Opensearch by updating `elastisys/fluentd` to use image tag `v3.4.0-ck8s4`.
  In this image `fluent-plugin-kubernetes_metadata_filter` has been downgraded to version `2.13.0`, which still includes the de_dot functionality that was removed in the prior tag of the image.
- Fixed harbor network policies
- Fixed update-ips script to handle ports for S3 endpoints
- Rclone can now be configured to run every x minutes/hours/days/week/month/year.
- Cleanup scripts now delete PVCs instead of PVs to let the cloud controller manager handle the volume lifecycle
- Fixed issue with the update-ips script to fail to parse port
- Fixed ingress-nginx controller network policy for loadbalancer service and thanos remote write
- falco-psp-rbac chart is now it's own release as it interfered with the falco charts dependency on falco-sidekick

### Added
- Option to configure alerts for growing indices in OpenSearch
- Option to deny network traffic by default
- Network policies for monitoring stack (prometheus, thanos, grafana, some exporters)
- An alert for failed evicted pods (KubeFailedEvictedPods)
- Resource config for user-alertmanager, config-reloader, gatekeeper
- Config option for gatekeeper audit interval
- Network policies for logging stack (fluentd and opensearch)
- Network policies for Kured
- Network policies for Velero
- Network policies for rclone-sync
- Network policies for s3-exporter
- New section in the welcoming dashboards, displaying the most relevant features and changes for the user added in the last two releases.
- Network policies for ingress-nginx and cert-manager
- Added support for running Thanos on Swift

### Removed

- Grafana reporting and update checks
- Pipeline check for `calico-kube-controllers` deployment as it is no longer created in Kubespray `v2.20.0`
- Creation of `influxdb-prometheus` namespace in bootstrap
