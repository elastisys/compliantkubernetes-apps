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

### Fixed

- Fixed influxdb-du-monitor to only select influxdb and not backup pods
- Added dex/dex as a need for opendistro-es to make kibana available out-the-box at cluster initiation if dex is enabled
- Fixed disabling retention cronjob for influxdb by allowing to create required resources
- Fixed harbor backup job run as non-root

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
  !! This will cause disruptions/downtime in the cluster as many of the pods will restart to apply the new resource limits/requests. !!
  !! Check your cluster available resources before applying the new requests. The pods will remain in a pending state if not enough resources are available. !!

### Removed

- Removed unnecessary PSPs and RBAC files for wc and sc.
