# Release notes

# Updated

### Changed

- The falco grafana dashboard now shows the misbehaving pod and instance for traceability

### Fixed

### Added

- Added fluentd metrics

### Removed

- Removed disabled helm charts. All have been disabled for at least one release which means no migration steps are needed as long as the updates have been done one version at a time.
  - `nfs-client-provisioner`
  - `gatekeeper-operator`
  - `common-psp-rbac`
  - `workload-cluster-psp-rbac`
