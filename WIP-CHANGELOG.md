# Release notes

* This release introduces a new feature called "index per namespace".
    Enabling it makes fluentd log to indices in elasticsearch based on the namespace from which the container log originates.
* Check out the [upgrade guide](https://github.com/elastisys/compliantkubernetes-apps/blob/main/migration/v0.18.x-v0.19.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
* CK8S_FLAVOR is now mandatory on init
* This release migrates from Open Distro for Elasticsearch to OpenSearch.
* Updated Blackbox chart to v5.3.1, and blackbox app to v0.19.0
  - HTTP probe: no_follow_redirects has been renamed to follow_redirects

# Updated

- kubectl version from v1.19.8 to v1.20.7 [#725](https://github.com/elastisys/compliantkubernetes-apps/pull/725)
- updated falco helm chart to version 1.16.0, this upgrades falco to version 0.30.0
- cert-manager 1.4.0 upgraded to 1.6.1
- Updated Open Distro for Elasticsearch to 1.13.3 to mitigate [CVE-2021-44228 & CVE-2021-45046](https://opendistro.github.io/for-elasticsearch/blog/2021/12/update-to-1-13-3/)
- kube-prometheus-stack to v19.2.2 [#685](https://github.com/elastisys/compliantkubernetes-apps/pull/685)
  - upgrade prometheus-operator to v0.50.0
  - sync dashboards, rules and subcharts
  - add ability to specify existing secret with additional alertmanager configs
  - add support for prometheus TLS and basic auth on HTTP endpoints
  - allows to pass hashed credentials to the helm chart
  - add option to override the allowUiUpdates for grafana dashboards
- promethues to v2.28.1 [full changelog](https://github.com/prometheus/prometheus/blob/main/CHANGELOG.md)
- grafana to v8.2.7 [full changelog](https://github.com/grafana/grafana/blob/main/CHANGELOG.md)
  - security fixes: [CVE-2021-43798)](https://grafana.com/blog/2021/12/07/grafana-8.3.1-8.2.7-8.1.8-and-8.0.7-released-with-high-severity-security-fix/), [CVE-2021-41174](https://grafana.com/blog/2021/11/03/grafana-8.2.3-released-with-medium-severity-security-fix-cve-2021-41174-grafana-xss/), [stylesheet injection vulnerability](https://github.com/grafana/grafana/pull/38432), [short URL vulnerability](https://github.com/grafana/grafana/pull/38436), [CVE-2021-36222](https://github.com/grafana/grafana/pull/37546), [CVE-2021-39226](https://grafana.com/blog/2021/10/05/grafana-7.5.11-and-8.1.6-released-with-critical-security-fix/)
  - accessControl: Document new permissions restricting data source access. [#39091](https://github.com/grafana/grafana/pull/39091)
  - admin: Prevent user from deleting user's current/active organization. [#38056](https://github.com/grafana/grafana/pull/38056)
  - oauth: Make generic teams URL and JMES path configurable. [#37233](https://github.com/grafana/grafana/pull/37233),
- kube-state-metrics to v2.2.0 [full changelog](https://github.com/kubernetes/kube-state-metrics/blob/master/CHANGELOG.md)
- node exporter to v1.2.2 [full changelog](https://github.com/prometheus/node_exporter/blob/master/CHANGELOG.md)
- updated metrics-server helm chart to version 0.5.2, this upgrades metrics-server image to 3.7.0 [#702](https://github.com/elastisys/compliantkubernetes-apps/pull/702)
- Updated Dex chart to v0.6.3, and Dex itself to v2.30.0
- Updated Blackbox chart to v5.3.1, and blackbox app to v0.19.0
  - HTTP probe: no_follow_redirects has been renamed to follow_redirects



### Changed

- The falco grafana dashboard now shows the misbehaving pod and instance for traceability
- Reworked configuration handling to use a common config in addition to the service and workload configs. This is handled in the same way as the sc and wc configs, meaning it is split between a default and an override config. Running `init` will update this configuration structure, update and regenerate any missing configs, as well as merge common options from sc and wc overrides into the common override.
- Updated fluentd config to adhere better with upsream configuration
- Fluentd now logs reasons for 400 errors from elasticsearch
- Enabled the default rules from kube-prometheus-stack and deleted them from `prometheus-alerts` chart [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Enabled extra api server metrics [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Increased resources requests and limits for Starboard-operator in the common config [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Updated the common config as "prometheusBlackboxExporter" will now be required in both sc and wc cluster
- moved the elasticsearch alerts from the prometheus-elasticsearch-exporter chart to the prometheus-alerts chart [#685](https://github.com/elastisys/compliantkubernetes-apps/pull/685)
- Changed the User Alertmanager namespace (alertmanager) to an operator namespace from an user namespace
- Moved the User Alertmanager RBAC to `user-alertmanager` chart
- Made CK8S_FLAVOR mandatory on init
- Exposed harbor's backup retention period as config.
- Migrated from OpenDistro for Elasticsearch to OpenSearch.
  - This will be a breaking change as some API, specifically related to plugins and security, have been renamed in OpenSearch.
    The impact will be minimal as the function of the API will stay mostly the same, and the configuration will basically works as is, although renamed.
    The user experience will change slightly as this will replace Kibana with OpenSearch Dashboards, however the functionality remains the same.
  - OpenSearch is compatible with existing tools supporting ODFE using a compatibility setting, however this will only last for version 1.x.
    Newer versions of offical Elasticsearch tools and libraries already contain checks against unofficial Elasticsearch and will therefore not work for either ODFE or OpenSearch.
    Older versions exists that will still work, and the OpenSearch project is working on providing their own set of tools and libraries.
  - This will cause downtime for Elasticsearch and Kibana during the migration, and OpenSearch and OpenSearch Dashboards will replace them.
    Data will be kept by the migration steps, except security settings, any manually created user or roles must be manually handled.
- resources requests and limits for falco-exporter, kubeStateMetrics and prometheusNodeExporter [#739](https://github.com/elastisys/compliantkubernetes-apps/pull/739)
- increased resource requests and limits for falco-exporter, kubeStateMetrics and prometheusNodeExporter [#739](https://github.com/elastisys/compliantkubernetes-apps/pull/739)
- increased the influxDB pvc size [#739](https://github.com/elastisys/compliantkubernetes-apps/pull/739)
- Exposed velero's backup timetolive for both sc and wc.
- disabled internal database for InfluxDB
- OPA policies are now enforced (deny) for the prod flavor.

### Fixed

- Grafana dashboards by keeping more metrics from the kubeApiServer [#681](https://github.com/elastisys/compliantkubernetes-apps/pull/681)
- Fixed rendering of new prometheus alert rule to allow it to be admitted by the operator
- Fixed rendering of s3-exporter to be idempotent
- Fixed bug where init'ing a config path a second time without the `CK8S_FLAVOR` variable set would fail.
- Fixed relabeling for rook-ceph and cert servicemonitor.
- Fluentd will now properly detect changes in container logs.
- The `init` script will now properly generate secrets for new configuration options.
- Fixed an issue preventing OpenSearch to run without snapshots enabled
- Fixed a permission issue preventing OpenSearch init container to run sysctl

### Added

- Added fluentd metrics
- Enabled automatic compaction (cleanup) of pos_files for fluentd
- Added and enabled by default an option for Grafana Viewers to temporarily edit dashboards and panels without saving.
- New Prometheus rules have been added to forewarn against when memory and disk (PVC and host disk) capacity overloads
- Added the possibility to whitelist IP addresses to the loadbalancer service
- Added pwgen and htpasswd as requirements
- Added the blackbox installation in the wc cluster based on ADR to monitor the uptime of internal services as well in wc .
- Added option to enable index per namespace feature in fluentd and elasticsearch
- Added optional off-site backup replication between two providers or regions using rclone sync

### Removed

- Removed disabled helm charts. All have been disabled for at least one release which means no migration steps are needed as long as the updates have been done one version at a time.
  - `nfs-client-provisioner`
  - `gatekeeper-operator`
  - `common-psp-rbac`
  - `workload-cluster-psp-rbac`
- Removed the "prometheusBlackboxExporter" from sc config and updated the common config as it will now be required in both sc and wc cluster
- Removed curator alerts
