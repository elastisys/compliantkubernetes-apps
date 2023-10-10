### Release notes

### Added

- Add support for self-managed CRDs (preview)
  - Add support for SealedSecrets and MongoDB
  - Add support for Flux
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
- Modified the `FluentdQueueLength` prometheus alert condition to calculate the rate of change of the `fluentd_status_buffer_queue_length` metric from `5m` to `15m` and sustain the condition from `1m` to `5m`.
- Modified the `FluentdOutputError` & `FluentdRetry` prometheus alert condition to evaluate based on specific labels combination of `pod`, `cluster`, and `service`.

### Fixed

- Broken link in v0.30 migration instructions
- Fixed thanos ingesting out-of-order error.

### Updated

- Upgrade kube-prometheus-stack chart version from `v45.2.0` to `v49.2.0` and app version from `v0.63.0` to `v0.67.1`

### Removed
