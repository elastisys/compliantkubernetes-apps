### Release notes

### Added

- Add support for self-managed CRDs (preview)
  - Add support for SealedSecrets and MongoDB
- Add application developer service account kube-config for devs
  - Enabled developers to easily create a kube-config to act as an application developer

### Changed

- Changed the alert `KubeContainerOOMKilled` threshold.

### Fixed

- Removed the label `admission.gatekeeper.sh/ignore: "true"` from `kube-system` namespace.

### Updated

### Removed
