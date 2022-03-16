### Release notes

### Updated

### Changed
- Added the repo - "quay.io/jetstack/cert-manager-acmesolver" in allowrepo safeguard by default.
- Backup operator namespaces can for example be added as veloro parameters to be able to back them up. 'alertmanager' is added as default in the workload cluster.
- Set 'continue_if_exception' in curator as to not fail when a snapshot is in progress and it is trying to remove some indices.
- Vulnerability scanner reports ttl is now set to 720 hours, i.e., 30 days.
  - Reports will now be deleted every 30 days by the operator and newer reports are generated.
  - Older reports that are not created with ttl parameter set, should be deleted manually.

### Fixed
- Use `master` tag for the grafana-label-enforcer as the previous sha used no longer exist.

### Fixed
- The opensearch SLM job now uses `/_cat/snapshots` to make it work better when there are a large amount of snapshots available.

### Added

### Removed
