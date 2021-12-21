# Release notes

* Check out the [upgrade guide](https://github.com/elastisys/compliantkubernetes-apps/blob/main/migration/v0.18.x-v0.19.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

# Updated

 - updated Grafana to 8.0.7 in order to fix [CVE-2021-43798](https://grafana.com/blog/2021/12/07/grafana-8.3.1-8.2.7-8.1.8-and-8.0.7-released-with-high-severity-security-fix/)
 - updated falco helm chart to version 1.16.0, this upgrades falco to version 0.30.0
 - cert-manager 1.4.0 upgraded to 1.6.1
 - Updated Open Distro for Elasticsearch to 1.13.3 to mitigate [CVE-2021-44228 & CVE-2021-45046](https://opendistro.github.io/for-elasticsearch/blog/2021/12/update-to-1-13-3/)

### Changed

- The falco grafana dashboard now shows the misbehaving pod and instance for traceability
- Reworked configuration handling to use a common config in addition to the service and workload configs. This is handled in the same way as the sc and wc configs, meaning it is split between a default and an override config. Running `init` will update this configuration structure, update and regenerate any missing configs, as well as merge common options from sc and wc overrides into the common override.
- Updated fluentd config to adhere better with upsream configuration
- Fluentd now logs reasons for 400 errors from elasticsearch
- Enabled the default rules from kube-prometheus-stack and deleted them from `prometheus-alerts` chart [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Enabled extra api server metrics [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Increased resources requests and limits for Starboard-operator in the common config [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)

### Fixed
- Grafana dashboards by keeping more metrics from the kubeApiServer [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)

- Fixed rendering of new prometheus alert rule to allow it to be admitted by the operator

### Added

- Added fluentd metrics
- Enabled automatic compaction (cleanup) of pos_files for fluentd
- Added and enabled by default an option for Grafana Viewers to temporarily edit dashboards and panels without saving.
- New Prometheus rules have been added to forewarn against when memory and disk (PVC and host disk) capacity overloads
- Added the possibility to whitelist IP addresses to the loadbalancer service
- Added pwgen and htpasswd as requirements

### Removed

- Removed disabled helm charts. All have been disabled for at least one release which means no migration steps are needed as long as the updates have been done one version at a time.
  - `nfs-client-provisioner`
  - `gatekeeper-operator`
  - `common-psp-rbac`
  - `workload-cluster-psp-rbac`
