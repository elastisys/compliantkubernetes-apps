### Release notes

- Several default resource requests and limits have changed. When upgrading these might need to be adjusted.

### Updated

- Updated dex chart to `v0.12.0` which upgraded dex to `v2.35.1`

### Changed

- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service
- Upgrade Velero helm chart to `v2.31.8`, which also upgrades Velero to `v1.9.2`.
- Update the provider plugins to a supported version for the new Velero release
- Added support for anchors and aliases in override configs, not tested with merge aliases/tags
- Changed the default limit for diskLimit alert, from 66 to 75
- Changed some default resource requests and limits for multiple components
- Gatekeeper audits every 10 min instead of 1 min
- Gatekeeper audit only looks at the resource types mentioned in constraints, instead of all resource types

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

### Added

- Option to deny network traffic by default
- Network policies for monitoring stack (prometheus, thanos, grafana, some exporters)
- An alert for failed evicted pods (KubeFailedEvictedPods)
- Resource config for user-alertmanager, config-reloader, gatekeeper
- Config option for gatekeeper audit interval

### Removed

- Grafana reporting and update checks
- Pipeline check for `calico-kube-controllers` deployment as it is no longer created in Kubespray `v2.20.0`
