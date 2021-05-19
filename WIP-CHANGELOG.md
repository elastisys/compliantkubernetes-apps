### Release notes

- Support for multiple connectors for dex and better support for OIDC groups.
- Check out the [upgrade guide](migration/v0.15.x-v0.16.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- A new helm chart `starboard-operator`, which creates `vulnerabilityreports` with information about image vulnerabilities.
- Dashboard in Grafana showcasing image vulnerabilities.
- Added option to enable dex integration for ops grafana

### Changed

- The project now requires `helm-diff >= 3.1.2`. Remove the old one (via `rm -rf ~/.local/share/helm/plugins/helm-diff/`), before reinstalling dependencies.
- Changed the way connectors are provided to dex

### Fixed

- Fixed issue where you couldn't configure dex google connector to support groups
- Fixed issue where groups wouldn't be fetched for kubelogin
