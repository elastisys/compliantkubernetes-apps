### Release notes

- Check out the [upgrade guide](migration/v0.16.x-v0.17.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
- Changed from depricated nfs provisioner to the new one. Migration is automatic (no manual intervention)

### Changed

- The sc-logs-retention cronjob now runs without error even if no backups were found for automatic removal
- Harbor Swift authentication configuration options has moved from `citycloud` to `harbor.persistence.swift`.
- The dry-run and apply command now have the options to check against the state of the cluster while ran by using the flags "--sync" and "--kubectl".
- The dex chart is upgraded from stable/dex to dex/dex (v0.3.3).
  Dex is upgraded to v2.18.1
- cert-manager upgrade from 1.1.0 to 1.4.0.

### Fixed

- The `clusterDns` config variable now matches Kubespray defaults.
  Using the wrong value causes node-local-dns to not be used.
- Blackbox-exporter now ignores checking the harbor endpoint if harbor is disabled.
- Kube-prometheus-stack are now being upgraded from 12.8.0 to 16.6.1 to fix dashboard errors.
Grafana 8.0.1 and Prometheus 2.27.1.
- "serviceMonitor/" have been added to all prometheus targets in our tests to make them work

### Added

- Option to set cluster admin groups
- Configuration option `dex.additionalStaticClients` in `secrets.yaml` can now be used to define additional static clients for Dex.
- ck8s providers command
- ck8s flavors command
- Added script to make it easier to generate secrets

### Removed

- The configuration option `global.cloudProvider` is no longer needed.
