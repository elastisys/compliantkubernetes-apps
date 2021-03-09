### Release notes

- ClusterIssuers are used instead of Issuers.
  Administrators should be careful regarding the use of ClusterIssuers in workload clusters, since users will be able to use them and may cause rate limits.
- Check out the [upgrade guide](migration/v0.11.x-v0.12.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- NetworkPolicy dashboard in Grafana
- Added a new helm chart `calico-accountant`
- Clean-up scripts that can remove compliantkubernetes-apps from a cluster

### Changed

- ClusterIssuers are used instead of Issuers
- Persistent volumes for prometheus are now optional (disabled by default)
