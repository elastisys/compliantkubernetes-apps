# Release notes

* Check out the [upgrade guide](https://github.com/elastisys/compliantkubernetes-apps/blob/main/migration/v0.18.x-v0.19.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

# Updated

 - updated falco helm chart to version 1.16.0, this upgrades falco to version 0.30.0
 - cert-manager 1.4.0 upgraded to 1.6.1

### Changed

- The falco grafana dashboard now shows the misbehaving pod and instance for traceability
- Reworked configuration handling to use a common config in addition to the service and workload configs. This is handled in the same way as the sc and wc configs, meaning it is split between a default and an override config. Running `init` will update this configuration structure, update and regenerate any missing configs, as well as merge common options from sc and wc overrides into the common override.
- Updated fluentd config to adhere better with upsream configuration
- Fluentd now logs reasons for 400 errors from elasticsearch

### Fixed

### Added

- Added fluentd metrics
- Enabled automatic compaction (cleanup) of pos_files for fluentd

### Removed

- Removed disabled helm charts. All have been disabled for at least one release which means no migration steps are needed as long as the updates have been done one version at a time.
  - `nfs-client-provisioner`
  - `gatekeeper-operator`
  - `common-psp-rbac`
  - `workload-cluster-psp-rbac`
