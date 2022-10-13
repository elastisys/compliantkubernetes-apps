### Release notes

### Updated

### Changed
- Lowered the default retention age for kubernetes logs in the prod flavor down to 30 days
- Changed grafana's communication with dex to use internal service
- Upgrade Velero helm chart to `v2.31.8`, which also upgrades Velero to `v1.9.2`.
- Update the provider plugins to a supported version for the new Velero release
- Added support for anchors and aliases in override configs, not tested with merge aliases/tags
- Changed the default limit for diskLimit alert, from 66 to 75

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

### Removed
