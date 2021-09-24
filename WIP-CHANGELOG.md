# Updated

- Updated influxdb chart 4.8.12 to 4.8.15

### Changed

- ingress-nginx increased the value for client-body-buffer-size from 16K to 256k
- Lowered default falco resource requests
- The timeout of the prometheus-elasticsearch-exporter is set to be 5s lower than the one of the service monitor
- fluentd replaced the time_key value from time to requestReceivedTimestamp for kube-audit log pattern [#571](https://github.com/elastisys/compliantkubernetes-apps/pull/571)
- group_by in alertmanager changed to be configurable
- Reworked harbor restore script into a k8s job and updated the documentation.
- Increased slm timeout from 30 to 45 min.
- charts/grafana-ops [#587](https://github.com/elastisys/compliantkubernetes-apps/pull/587):
  1. create one ConfigMap for each dashboard
  2. add differenet values for "labelKey" so we can separate the user and ops dashboards in Grafana
  3. the chart template to automatically load the dashboards enabled in the values.yaml file
- grafana-user.yaml.gotmpl:
  1. grafana-user.yaml.gotmpl to load only the ConfiMaps that have the value of "1" fron "labelKey" [#587](https://github.com/elastisys/compliantkubernetes-apps/pull/587)
  2. added prometheus-sc as a datasource to user-grafana
- enabled podSecurityPolicy in falco, fluentd, cert-manager, prometheus-elasticsearch-exporter helm charts

### Fixed

- Fixed influxdb-du-monitor to only select influxdb and not backup pods
- Added dex/dex as a need for opendistro-es to make kibana available out-the-box at cluster initiation if dex is enabled
- Fixed disabling retention cronjob for influxdb by allowing to create required resources
- Fixed harbor backup job run as non-root
- fixed "Uptime and status", "ElasticSearch" and "Kubernetes cluster status" grafana dashboards
- Fixed warning from velero that the default backup location "default" was missing.

### Added

- Added the ability to configure elasticsearch ingress body size from sc config.
- Added RBAC to allow users to view PVs.
- Added group support for user RBAC.
- Added option `elasticsearch.snapshot.retentionActiveDeadlineSeconds` to control the deadline for the SLM job.
- Added configuration properties for falco-exporter.
- calico-felix-metrics helm chart to enable calico targets discovery and scraping
  calico felix grafana dashboard to visualize the metrics
- Added JumpCloud as a IDP using dex.
- Setting chunk limit size and queue limit size for fluentd from sc-config file
- Added options to configure the liveness and readiness probe settings for fluentd forwarder.
- resource requests for apps [#551](https://github.com/elastisys/compliantkubernetes-apps/pull/551)
  > **_NOTE:_** This will cause disruptions/downtime in the cluster as many of the pods will restart to apply the new resource limits/requests. Check your cluster available resources before applying the new requests. The pods will remain in a pending state if not enough resources are available.
- Increased Velero request limits.
- Velero restic backup is now default
- Velero backups everything in user namespaces, opt out by using label compliantkubernetes.io/nobackup: velero
- Added configuration for Velero daily backup schedule in config files
- cert-manager networkpolicy, the possibility to configure a custom public repository for the http01 challenge image and the possibility to add an OPA exception for the cert-manager-acmesolver image [#593](https://github.com/elastisys/compliantkubernetes-apps/pull/593)
  > **_NOTE:_** Possible breaking change if OPA policies are enabled
- Added prometheus probes permission for users

### Removed

- Removed unnecessary PSPs and RBAC files for wc and sc.
