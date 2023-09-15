### Release notes

### Added

- Add support for self-managed CRDs (preview)
  - Add support for SealedSecrets and MongoDB
- Add application developer service account kube-config for devs
  - Enabled developers to easily create a kube-config to act as an application developer
- Dashboard showing how spread out pods are across nodes or zones

### Changed

- Changed the alert `KubeContainerOOMKilled` threshold.
- Changed Gatekeeper violation messages to be more informative.

### Fixed

- Broken link in v0.30 migration instructions

### Updated

- Upgrade kube-prometheus-stack chart version from `v45.2.0` to `v49.2.0` and app version from `v0.63.0` to `v0.67.1`

### Removed
