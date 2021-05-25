### Release notes

- Support for multiple connectors for dex and better support for OIDC groups.
- Check out the [upgrade guide](migration/v0.15.x-v0.16.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- A new helm chart `starboard-operator`, which creates `vulnerabilityreports` with information about image vulnerabilities.
- Dashboard in Grafana showcasing image vulnerabilities.
- Added option to enable dex integration for ops grafana
- Added resource request/limits for ops grafana
- Added support for admin group for harbor

### Changed

- The project now requires `helm-diff >= 3.1.2`. Remove the old one (via `rm -rf ~/.local/share/helm/plugins/helm-diff/`), before reinstalling dependencies.
- Changed the way connectors are provided to dex
- Default retention values for other* and authlog* are changed to fit the needs better
- CK8S version validation accepts version number if exactly at the release tag, otherwise commit hash of current commit. "any" can still be used to disable validation.
- The node-local-dns chart have been updated to match the upstream manifest. force_tcp have been removed to improve performence and the container image have beve been updated from 1.15.10 to 1.17.0.

### Fixed

- Fixed issue where you couldn't configure dex google connector to support groups
- Fixed issue where groups wouldn't be fetched for kubelogin
