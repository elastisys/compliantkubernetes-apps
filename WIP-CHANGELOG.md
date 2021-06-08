### Release notes

- Check out the [upgrade guide](migration/v0.16.x-v0.17.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
- Changed from depricated nfs provisioner to the new one. Migration is automatic (no manual intervention)

### Changed

- The sc-logs-retention cronjob now runs without error even if no backups were found for automatic removal
- Harbor Swift authentication configuration options has moved from `citycloud` to `harbor.persistence.swift`.

### Fixed

- The `clusterDns` config variable now matches Kubespray defaults.
  Using the wrong value causes node-local-dns to not be used.

### Added

- Option to set cluster admin groups
- Option to change subdomain of ops services

### Removed

- The configuration option `global.cloudProvider` is no longer needed.
