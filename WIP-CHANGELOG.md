### Release notes

### Added

- Add support for self-managed CRDs (preview)
  - Add support for SealedSecrets and MongoDB
- Add application developer service account kube-config for devs
  - Enabled developers to easily create a kube-config to act as an application developer
- Dashboard showing how spread out pods are across nodes or zones
- Add secrets to gatekeeper validatingWebhookCustomRules
- Fix psp violations in clusters as a command for ck8s
  - `bin/ck8s fix-psp-violations <sc/wc>` ensures that there are no pods violating psps, important for new environments.
- Clean apps from clusters as a command for ck8s
  - `bin/ck8s clean <sc/wc>` removes apps from cluster.

### Changed

- Changed the alert `KubeContainerOOMKilled` threshold.
- Changed Gatekeeper violation messages to be more informative.

### Fixed

- Broken link in v0.30 migration instructions
- Fixed thanos ingesting out-of-order error.

### Updated

- Upgrade kube-prometheus-stack chart version from `v45.2.0` to `v49.2.0` and app version from `v0.63.0` to `v0.67.1`

### Removed
