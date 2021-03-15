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
- Updated velero chart and its CRDs to 2.15.0 (velero 1.5.0)
- Updated fluentd forwarder config to always include `s3_region`
- Updated gatekeeper to v3.3.0 and it now uses the official chart.

### Removed

- Removed label `certmanager.k8s.io/disable-validation` from cert-manager namespace
- Removed leftover default tolerations config for `ingress-nginx`.
