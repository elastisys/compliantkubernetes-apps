# Compliant Kubernetes changelog
<!-- BEGIN TOC -->
- [v0.18.1](#v0181---2021-12-08)
- [v0.18.0](#v0180---2021-10-28)
- [v0.17.0](#v0170---2021-06-29)
- [v0.16.0](#v0160---2021-05-27)
- [v0.15.0](#v0150---2021-05-05)
- [v0.14.0](#v0140---2021-04-20)
- [v0.13.0](#v0130---2021-04-06)
- [v0.12.0](#v0120---2021-03-17)
- [v0.11.0](#v0110---2021-03-03)
- [v0.10.0](#v0100---2021-02-18)
- [v0.9.0](#v090---2021-01-25)
- [v0.8.0](#v080---2020-12-11)
- [v0.7.0](#v070---2020-11-09)
- [v0.6.0](#v060---2020-10-16)
- [v0.5.0](#v050---2020-08-06)
<!-- END TOC -->

-------------------------------------------------
## v0.18.1 - 2021-12-08

# Updated

 - updated Grafana to 8.0.7 in order to fix [CVE-2021-43798](https://grafana.com/blog/2021/12/07/grafana-8.3.1-8.2.7-8.1.8-and-8.0.7-released-with-high-severity-security-fix/)

-------------------------------------------------
## v0.18.0 - 2021-10-28

### Release notes
- Check out the [upgrade guide](migration/v0.17.x-v0.18.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
- ingress-nginx chart was upgraded from 2.10.0 to 3.39.0 and ingress-nginx-controller was upgraded from v0.28.0 to v.0.49.3. During the upgrade the services may be unavailable for short period of time.
  With this version:
     - set allow-snippet-annotations: “false” to mitigate [CVE-2021-25742](https://github.com/kubernetes/ingress-nginx/issues/7837)
     - only ValidatingWebhookConfiguration AdmissionReviewVersions v1 is supported
     - the nginx-ingress-controller repository was deprecated
     - access-log-path setting is deprecated
     - server-tokens, ssl-session-tickets, use-gzip, upstream-keepalive-requests, upstream-keepalive-connections have new defaults
     - TLSv1.3 is enabled by default
     - Add linux node selector as default
     - Update versions of components for base image, including nginx-http-auth-digest, ngx_http_substitutions_filter_module, nginx-opentracing, opentracing-cpp, ModSecurity-nginx, yaml-cpp, msgpack-c, lua-nginx-module, stream-lua-nginx-module, lua-upstream-nginx-module, luajit2, dd-opentracing-cpp, ngx_http_geoip2_module, nginx_ajp_module, lua-resty-string, lua-resty-balancer, lua-resty-core, lua-cjson, lua-resty-cookie, lua-resty-lrucache, lua-resty-dns, lua-resty-http, lua-resty-memcached, lua-resty-ipmatcher

### Updated

- Updated influxdb chart 4.8.12 to 4.8.15
- Updated starboard-operator chart from v0.5.1 (app v0.10.1) to v0.7.0 (app v0.12.0), this introduces a PSP RBAC as a subchart since the Trivy scanners were unable to run.

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
- ingress-nginx chart was upgraded from 2.10.0 to 3.39.0. [#640](https://github.com/elastisys/compliantkubernetes-apps/pull/640)
  ingress-nginx-controller was upgraded from v0.28.0 to v.0.49.3
  nginx was upgraded to 1.19
  > **_Breaking Changes:_** * Kubernetes v1.16 or higher is required. Only ValidatingWebhookConfiguration AdmissionReviewVersions v1 is supported. * Following the Ingress extensions/v1beta1 deprecation, please use networking.k8s.io/v1beta1 or networking.k8s.io/v1 (Kubernetes v1.19 or higher) for new Ingress definitions * The repository https://quay.io/repository/kubernetes-ingress-controller/nginx-ingress-controller is deprecated and read-only

  > **_Deprecations:_** * Setting access-log-path is deprecated and will be removed in 0.35.0. Please use http-access-log-path and stream-access-log-path

  > **_New defaults:_** * server-tokens is disabled * ssl-session-tickets is disabled * use-gzip is disabled * upstream-keepalive-requests is now 10000 * upstream-keepalive-connections is now 320 * allow-snippet-annotations is set to  “false”

  > **_New Features:_** * TLSv1.3 is enabled by default * OCSP stapling * New PathType and IngressClass fields * New setting to configure different access logs for http and stream sections: http-access-log-path and stream-access-log-path options in configMap * New configmap option enable-real-ip to enable realip_module * Add linux node selector as default * Add hostname value to override pod's hostname * Update versions of components for base image * Change enable-snippet to allow-snippet-annotation * For the full list of New Features check the Full Changelog

  > **_Full Changelog:_** https://github.com/kubernetes/ingress-nginx/blob/main/Changelog.md
- enable hostNetwork and set the dnsPolicy to ClusterFirstWithHostNet only if hostPort is enabled [#535](https://github.com/elastisys/compliantkubernetes-apps/pull/535)
  > **_Note:_** The upgrade will fail while disabling the hostNetwork when LoadBalancer type service is used, this is due removing some privileges from the PSP. See the migration steps for more details.
- Prometheus alert and servicemonitor was separated
- Default user alertmanager namespace changed from monitoring to alertmanager.
- Reworked configuration handling to keep a read-only default with specifics for the environment and a seperate editable override config for main configuration.
- Integrated secrets generation script into `ck8s init` which will by default generate password and hashes when creating a new `secrets.yaml`, and can be forced to generate new ones with the flag `--generate-new-secrets`.
- Increased metricsserver resource limits.
- Increased cert-managers resource limits.
- Increased harbor resource request and limits.

### Fixed

- Fixed influxdb-du-monitor to only select influxdb and not backup pods
- Added dex/dex as a need for opendistro-es to make kibana available out-the-box at cluster initiation if dex is enabled
- Fixed disabling retention cronjob for influxdb by allowing to create required resources
- Fixed harbor backup job run as non-root
- fixed "Uptime and status", "ElasticSearch" and "Kubernetes cluster status" grafana dashboards
- Fixed warning from velero that the default backup location "default" was missing.
- Fixed dex tls handshake failed

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
- Added the ability to set and choose subdomain of your service endpoints.
- Added backup function for configurations and secrets during `ck8s init`.
- Issuers is on by default for wc.

### Removed

- Removed unnecessary PSPs and RBAC files for wc and sc.

-------------------------------------------------
## v0.17.0 - 2021-06-29

### Release notes

- Check out the [upgrade guide](migration/v0.16.x-v0.17.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
- Changed from depricated nfs provisioner to the new one. Migration is automatic (no manual intervention)

### Changed

- The sc-logs-retention cronjob now runs without error even if no backups were found for automatic removal
- Harbor Swift authentication configuration options has moved from `citycloud` to `harbor.persistence.swift`.
- The dry-run and apply command now have the options to check against the state of the cluster while ran by using the flags "--sync" and "--kubectl".
- The dex chart is upgraded from stable/dex to dex/dex (v0.3.3).
  Dex is upgraded to v2.18.1
- cert-manager upgrade from 1.1.0 to 1.4.0.
- Increased slm cpu request slightly

### Fixed

- The `clusterDns` config variable now matches Kubespray defaults.
  Using the wrong value causes node-local-dns to not be used.
- Blackbox-exporter now ignores checking the harbor endpoint if harbor is disabled.
- Kube-prometheus-stack are now being upgraded from 12.8.0 to 16.6.1 to fix dashboard errors.
Grafana 8.0.1 and Prometheus 2.27.1.
- "serviceMonitor/" have been added to all prometheus targets in our tests to make them work
- The openid url port have been changed from 32000 to 5556 to match the current setup.
- sc-log-rentention fixed to delete all logs within a 5 second loop.
- Fixed issue where curator would fail if postgres retention was enabled

### Added

- Option to set cluster admin groups
- Configuration option `dex.additionalStaticClients` in `secrets.yaml` can now be used to define additional static clients for Dex.
- ck8s providers command
- ck8s flavors command
- Added script to make it easier to generate secrets

### Removed

- The configuration option `global.cloudProvider` is no longer needed.

-------------------------------------------------
## v0.16.0 - 2021-05-27

### Release notes

- Support for multiple connectors for dex and better support for OIDC groups.
- Check out the [upgrade guide](migration/v0.15.x-v0.16.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.
- The project now requires `helm-diff >= 3.1.2`. Remove the old one (via `rm -rf ~/.local/share/helm/plugins/helm-diff/`), before reinstalling dependencies.

### Added

- A new helm chart `starboard-operator`, which creates `vulnerabilityreports` with information about image vulnerabilities.
- Dashboard in Grafana showcasing image vulnerabilities.
- Added option to enable dex integration for ops grafana
- Added resource request/limits for ops grafana
- Added support for admin group for harbor
- Rook monitoring (ServiceMonitor and PrometheusRules) and dashboards.

### Changed

- Changed the way connectors are provided to dex
- Default retention values for other* and authlog* are changed to fit the needs better
- CK8S version validation accepts version number if exactly at the release tag, otherwise commit hash of current commit. "any" can still be used to disable validation.
- The node-local-dns chart have been updated to match the upstream manifest. force_tcp have been removed to improve performence and the container image have beve been updated from 1.15.10 to 1.17.0.

### Fixed

- Fixed issue where you couldn't configure dex google connector to support groups
- Fixed issue where groups wouldn't be fetched for kubelogin
- Fixed issue where grafana would get stuck on upgrade
- Rook monitor for the alertmanagers is no longer hard-coded to true.

-------------------------------------------------
## v0.15.0 - 2021-05-05

### Changed

- Only install rbac for user alertmanager if it's enabled.
- Convert all values to integers for elasticsearch slm cronjob
- The script for generating a user kubeconfig is now `bin/ck8s kubeconfig user` (from `bin/ck8s user-kubeconfig`)
- Harbor have been updated to v2.2.1.
- Use update strategy `Recreate` instead of `RollingUpdate` for Harbor components.

### Fixed

- When using harbor together with rook there is a potential bug that appears if the database pod is killed and restarted on a new node. This is fixed by upgrading the Harbor helm chart to version 1.6.1.
- The command `team-add` for adding new PGP fingerprints no longer crashes when validating some environment variables.

### Added

- Authlog now indexed by elasticsearch
- Added a ClusterRoleBinding for using an OIDC-based cluster admin kubeconfig and a script for generating such a kubeconfig (see `bin/ck8s kubeconfig admin`)
- S3-exporter for collecting metrics about S3 buckets.
- Dashboard with common things to check daily, e.g. object storage usage, Elasticsearch snapshots and InfluxDB database sizes.

### Removed

- Removed the functionality to automatically restore InfluxDB and Grafana when running `bin/ck8s apply`. The config values controlling this (`restore.*`) no longer have any effect and can be safely removed.

-------------------------------------------------
## v0.14.0 - 2021-04-20

### Added

- Script to restore Harbor from backup

### Fixed

- Elasticsearch slm now deletes excess snapshots also when none of them are older than the maximum age

### Changed

- The Service Cluster Prometheus now alerts based on Falco metrics. These alerts are sent to Alertmanager as usual so they now have the same flow as all other alerts. This is in addition to the "Falco specific alerting" through Falco sidekick.
- Elasticsearch slm now deletes indices in bulk
- Default to object storage disabled for the dev flavor.

### Removed

- Removed namespace `gatekeeper` from bootstrap.
  The namespace can be safely removed from clusters running ck8s  v0.13.0 or later.

-------------------------------------------------
## v0.13.0 - 2021-04-06

### Fixed

- Elasticsearch SLM retention value conversion bug
- FluentId logs stop being shipped to S3

### Changed

- Increased default active deadline for the slm job from 5 to 10 minutes
- Updated the release documentation

-------------------------------------------------
## v0.12.0 - 2021-03-17

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
- Tweaked config default value for disabled option

### Removed

- Removed label `certmanager.k8s.io/disable-validation` from cert-manager namespace
- Removed leftover default tolerations config for `ingress-nginx`.
- Removed unsed config option `objectStorage.s3.regionAddress`.

-------------------------------------------------
## v0.11.0 - 2021-03-03

### Fixed
- Fixed service cluster log retention using the wrong service account.
- Fixed upgrade of user Grafana.

### Changed
- Bumped `helm` to `v3.5.2`.
- Bumped `kubectl` to `v1.19.8`.
- Bumped `helmfile` to `v0.138.4`.

### Removed
- Fluentd prometheus metrics.

### Added
- Possibility to disable metrics server

-------------------------------------------------
=======
## v0.10.0 - 2021-02-18

### Release notes
- With the update of the opendistro helm chart you can now decide whether or not you want dedicated deployments for data and client/ingest nodes.
  By setting `elasticsearch.dataNode.dedicatedPods: false` and `elasticsearch.clientNode.dedicatedPods: false`,
  the master node statefulset will assume all roles.
- Ck8sdash has been deprecated and will be removed when upgrading.
  Some resources like it's namespace will have to be manually removed.
- Check out the [upgrade guide](migration/v0.9.x-v0.10.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- Several new dashboards for velero, nginx, gatekeeper, uptime of services, and kubernetes status.
- Metric scraping for nginx, gatekeeper, and velero.
- Check for Harbor endpoint in the blackbox exporter.

### Changed

- The falco dashboard has been updated with a new graph, multicluster support, and a link to kibana.
- Changed path that fluentd looks for kubernetes audit logs to include default path for kubespray.
- Opendistro helm chart updated to 1.12.0.
- Options to disable dedicated deployments for elasticsearch data and client/ingest nodes.
- By default, no storageclass is specified for elasticsearch, meaning it'll consume whatever is cluster default.
- Updated elasticsearch config in dev-flavor.
  Now the deployment consists of a single master/data/client/ingest node.

### Fixed

- Fixed issue with adding annotation to bootstrap namespace chart

### Removed

- Ck8sdash.

-------------------------------------------------
## v0.9.0 - 2021-01-25

### Release notes

- Removed unused config `global.environmentName` and added `global.clusterName` to migrate there's [this script](migration/v0.8.x-v0.9.x/migrate-config.sh).
- To udate the password for `user-alertmanager` you'll have to re-install the chart.
- With the replacement of the helm chart `stable/elasticsearch-exporter` to `prometheus-community/prometheus-elasticsearch-exporter`, it is required to manually execute some steps to upgrade.
- Configuration regarding backups (in general) and harbor storage have been changed and requires running init again. If `harbor.persistence.type` equals `s3` or `gcs` in your config you must update it to `objectStorage`.
- With the removal of `scripts/post-infra-common.sh` you'll now have to, if enabled, manually set the address to the nfs server in `nfsProvisioner.server`
- The cert-manager CustomResourceDefinitions has been upgraded to `v1`, see [API reference docs](https://cert-manager.io/docs/reference/api-docs/). It is advisable that you update your resources to `v1` in the near future to maintain functionality.
- The cert-manager letsencrypt issuers have been updated to the `v1` API and the old `letsencrypt` releases must be removed before upgrading.
- To get some of the new default values for resource requests on Harbor pods you will first need to remove the resource requests that you have in your Harbor config and then run `ck8s init` to get the new values.
- Check out the [upgrade guide](migration/v0.8.x-v0.9.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- Dex configuration to accept groups from Okta as an OIDC provider
- Added record `cluster.name` in all logs to elasticsearch that matches the cluster setting `global.clusterName`
- Role mapping from OIDC groups to roles in user grafana
- Configuration options regarding resources/tolerations for prometheus-elasticsearch-exporter
- Options to disable different types of backups.
- Harbor image storage can now be set to `filesystem` in order to use persistent volumes instead of object storage.
- Object storage is now optional. There is a new option to set object storage type to `none`. If you disable object storage, then you must also disable any feature that uses object storage (mostly all backups).
- Two new InfluxDB users to used by prometheus for writing metrics to InfluxDB.
- Multicluster support for some dashboards in Grafana.
- More config options for falco sidekick (tolerations, resources, affinity, and nodeSelector)
- Option to configure serviceMonitor for elasticsearch exporter
- Option to add more redirect URIs for the `kubelogin` client in dex.
- Option to disable the creation of user namespaces (RBAC will still be created)
- The possibility to configure resources, affinity, tolerations, and nodeSelector for all Harbor pods.

### Changed

- Updated user grafana chart to 6.1.11 and app version to 7.3.3
- The `stable/elasticsearch-exporter` helm chart has been replaced by `prometheus-community/prometheus-elasticsearch-exporter`
- OIDC group claims added to Harbor
- The options `s3` and `gcs` for `harbor.persistence.type` have been replaced with `objectStorage` and will then match the type set in the global object storage configuration.
- Bump kubectl to v1.18.13
- InfluxDB is now exposed via ingress.
- Prometheus in workload cluster now pushes metrics directly to InfluxDB.
- The prometheus release `wc-scraper` has been renamed to `wc-reader`.
  Now wc-reader only reads from the workload_cluster database in InfluxDB.
- InfluxDB helm chart upgraded to `4.8.11`.
- `kube-prometheus-stack` updated to version `12.8.0`.
- Bump prometheus to `2.23.0`.
- Added example config for Kibana group mapping from an OIDC provider
- Replaced `kiwigrid/fluentd-elasticsearch` helm chart with `kokuwa/fluentd-elasticsearch`.
- Replaced `stable/fluentd` helm chart with `bitnami/fluentd`.
- StorageClasses are now enabled/disabled in the `{wc,sc}-cofig.yaml` files.
- Mount path and IP/hostname is now configurable in `nfs-client-provisioner`.
- Upgraded `cert-manager` to `1.1.0`.
- Moved the `bootstrap/letsencrypt` helm chart to the apps step and renamed it to `issuers`.
  The issuers are now installed after cert-manager.
  You can now select which namespaces to install the letsencrypt issuers.
- Helm upgraded to `v3.5.0`.
- InfluxDB upgraded to `v4.8.12`.
- Resource requests/limits have been updated for all Harbor pods.

### Fixed

- Wrong password being used for user-alertmanager.
- Retention setting for wc scraper always overriding the user config and being set to 10 days.
- Blackbox exporter checks kibana correctly
- Removed duplicate enforcement config for OPA from wc-config
- Inavlid apiKey field being used in opsgenie config.

### Removed
- The following helm release has been deprecated and will be uninstalled when upgrading:
  - `wc-scraper`
  - `prometheus-auth`
  - `wc-scraper-alerts`
  - `fluentd-aggregator`
- Helm chart `basic-auth-secret` has been removed.
- Unused config option `dnsPrefix`.
- Removed `scripts/post-infra-common.sh` file.
- The image scanner Clair in Harbor, image scanning is done by the scanner Trivy

-------------------------------------------------

## v0.8.0 - 2020-12-11

### Release notes

**Note:** This upgrade will cause disruptions in some services, including the ingress controller!
See [the complete migration guide for all details](migration/v0.7.x-v0.8.x/migrate-apps.md).

You may get warnings about missing values for some fluentd options in the Workload cluster.
This can be disregarded.

- Helm has been upgraded to v3.4.1. Please upgrade the local binary.
- The Helm repository `stable` has changed URL and has to be changed manually:
  `helm repo add "stable" "https://charts.helm.sh/stable" --force-update`
- The blackbox chart has a changed dependency URL and has to be updated manually:
  `cd helmfile/charts/blackbox && helm dependency update`
- Configuration changes requires running init again to get new default values.
- Run the following migration script to update the object storage configuration: `migration/v0.7.x-v0.8.x/migrate-object-storage.sh`
- Some configuration options must be manually updated.
  See [the complete migration guide for all details](migration/v0.7.x-v0.8.x/migrate-apps.md)
- A few applications require additional steps.
  See [the complete migration guide for all details](migration/v0.7.x-v0.8.x/migrate-apps.md)


### Added

- Configurable persistence size in Harbor
- `any` can be used as configuration version to disabled version check
- Configuration options regarding pod placement and resources for cert-manager
- Possibility to configure pod placement and resourcess for velero
- Add `./bin/ck8s ops helm` to allow investigating issues between `helmfile` and `kubectl`.
- Allow nginx config options to be set in the ingress controller.
- Allow user-alertmanager to be deployed in custom namespace and not only in `monitoring`.
- Support for GCS
- Backup retention for InfluxDB.
- Add Okta as option for OIDC provider

### Changed

- The `stable/nginx-ingress` helm chart has been replaced by `ingress-nginx/ingress-nginx`
  - Configuration for nginx has changed from `nginxIngress` to `ingressNginx`
- Harbor chart has been upgraded to version 1.5.1
- Helm has been upgraded to v3.4.1
- Grafana has been updated to a new chart repo and bumped to version 5.8.16
- Bump `kubectl` to 1.17.11
- useRegionEndpoint moved to fluentd conf.
- Dex application upgraded to v2.26.0
- Dex chart updated to v2.15.2
- The issuer for the user-alertmanager ingress is now taken from `global.issuer`.
- The `stable/prometheus-operator` helm chart has been replaced by `prometheus-community/kube-prometheus-stack`
- InfluxDB helm chart upgraded to `4.8.9`
- Rework of the InfluxDB configuration.
- The sized based retention for InfluxDB has been lowered in the dev flavor.
- Bump opendistro helm chart to `1.10.4`.
- The configuration for the opendistro helm chart has been reworked.
Check the release notes for more information on replaces and removed options.
One can now for example configure:
  - Role and subject key for OIDC
  - Tolerations, affinity, nodeSelecor, and resources for most components
  - Additional opendistro security roles, ISM policies, and index templates
- OIDC is now enabled by default for elasticsearch and kibana when using the prod flavor

### Fixed

- The user fluentd configuration uses its dedicated values for tolerations, affinity and nodeselector.
- The wc fluentd tolerations and nodeSelector configuration options are now only specified in the configuration file.
- Helmfile install error on `user-alertmanager` when `user.alertmanager.enabled: true`.
- The wrong job name being used for the alertmanager rules in wc when `user.alertmanager.enabled: true`.
- Commented lines in `secrets.yaml`, showing which `objectStorage` values need to be set, now appear when running `ck8s init`.

### Removed

- Broken OIDC configuration for the ops Grafana instance has been removed.
- Unused alertmanager retention configuration from workload cluster

-------------------------------------------------
## v0.7.0 - 2020-11-09

### Release notes

- Configuration for the certificate issuers has been changed and requires running the [migration script](migration/v0.6.x-v0.7.x/migrate-issuer-config.sh).'
- Remove `alerts.opsGenieHeartbeat.enable` and `alerts.opsGenieHeartbeat.enabled` from your config file `sc-config.yaml`.
- Run `ck8s init` again to update your config files with new options (after checking out v0.7.0).
- Update your `yq` binary to version `3.4.1`.

### Added

- Support for providing certificate issuer manifests to override default issuers.
- Configurable extra role mappings in Elasticsearch
- Added falco exporter to workload cluster
- Falco dashboard added to Grafana
- Config option to disable redirection when pushing to Harbor image storage.

### Changed

- Configuration value `global.certType` has been replaced with `global.issuer` and `global.verifyTls`.
- Certificate issuer configuration has been changed from `letsencrypt` to `issuers.letsencrypt` and extended to support more issuers.
- Explicitly disabled multitenancy in Kibana.
- Cloud provider dependencies are removed from the templates, instead, keys are added to the sc|wc-config.yaml by the init script so no more "hidden" config. This requires a re-run of ck8s init or manully adding the missing keys.
- Version of `yq` have been updated to `3.4.1`.

### Fixed

- Kibana OIDC logout not redirecting correctly.
- Getting stuck at selecting tenant when logging in to Kibana.
- Typo in elasticsearch slm config for the schedule.
- Pushing images to Harbor on Safespring
- Typo in Alertmanager config regarding connection to Opsgenie heartbeat

-------------------------------------------------
## v0.6.0 - 2020-10-16

### Breaking changes
- The old config format of bashscripts will no longer be supported. All will need to use the yaml config instead. The scripts in `migration/v0.5.x-0.6.x` can be used to migrate current config files.
- The new Opendistro for Elasticsearch version requires running the steps in the [migration document](migration/v0.5.x-v0.6.0/opendistro.md).


### Release notes
- The `ENABLE_PSP` config option has been removed and it needs to be removed from `config.sh` before upgrading.
  See more extensive migration instructions [here](migration/v0.5.x-v0.6.0/psp.md).

- `CK8S_ADDITIONAL_VALUES` is now deprecated and no longer supported. Everything needed can now be set as values in config files.
- All bash and env config files have been replaced to yaml config.
- Before upgrading, add the `CK8S_FLAVOR` variable to your `config.sh`.
  It can be set to either `dev` or `prod` and will impact the validation.
  For example, the `prod` flavor will require a value for `OPSGENIE_HEARTBEAT_NAME`.
  If you want to keep the current behavior (no new requirements for validation) set the value to `dev`.
- Add `logRetention.days` to your `sc-config.yaml` to specify retention period in days for service cluster logs.
- To updatge apps to use the 'user' rather than 'customer' text you will need to destroy the customer-rbac chart first
  ./ck8s ops helmfile wc -l app=customer-rbac destroy
  Also note the existing config for clusters must be changed manually to migrate from customers to users
- Add `letsencrypt.prod.email` and `letsencrypt.staging.email` to your `sc-config.yaml` and `wc-config.yaml` to specify email addresses to be used for letsencrypt production certificate issuers and staging ("fake") certificate issuers, respectively. Additionally, old issuers must be deleted before `ck8s bootstrap` is run; they can be deleted by running the migration script `remove-old-issuers.bash`.

### Changed
- Yq is upgraded to v3.3.2
- Customer kubeconfig is no longer created automatically, and has to be created using the `ck8s user-kubeconfig` command.
- Storageclasses are installed as part of `ck8s bootstrap` instead of together with other applications.
- `ck8s apply` now runs the steps `ck8s bootstrap` and `ck8s apps`.
- Namespaces and Issuers are installed as part of `ck8s bootstrap` instead of together with other applications.
- `blackbox-exporter` uses ingress for health checking workload cluster kube api
- Renamed the flavors: `default` -> `dev`, `ha` -> `prod`.
- Group alerts by `severity` label.
- Pipeline is now prevented from being run if only .md files have been modified.
- When pulling code from `ck8s-cluster`, the pipeline targets the branch/tag `master@v0.5.0` instead of `cluster`
- Upgraded `helmfile` to version v0.129.3
- Removed `hook-failed` from opendistro helm hook deletion policy
- Upgraded ck8s-dash to v0.3.2
- By default, ES snapshots are now taken every 2 hours
- Continue on error in pipeline install apps steps
- `jq` upgraded to `1.6`
- Update ck8sdash helm chart values file to use the correct index for kubecomponents logs
- References to customer changed to user
- Helm is upgraded to v3.3.4
- Opendistro for Elasticsearch is updated to v1.10.1
- Falco chart updated to v1.5.2
- Falco image tag updated to v0.26.1

### Added
- Added `ck8s validate (sc|wc)` to the cli. This command can be run to validate your config.
- Helm secrets as a requirement.
- InfluxDB metric retention size limit for each cluster is now configurable.
- InfluxDB now uses a persistent volume during the backup process.
- Added `ck8s bootstrap (sc|wc)` to the CLI to bootstrap clusters before installing applications.
- Added `ck8s apps (sc|wc)` to the CLI to install applications.
- CRDs are installed in the bootstrap stage.
- Kibana SSO with oidc and dex.
- Namespaces and Issuers are installed in bootstrap
- S3 region to influxdb backup credentials.
- Kube apiserver /healthz endpoint is exposed through nginx with basic auth.
- Added alerts for endpoints monitored by blackbox.
- The flavors now include separate defaults for `config.sh`.
- Set opsgenie priority based on alert severity.
- New ServiceMonitor scrapes data from cert-manager.
- Cronjob for service cluster log backup retention.
- InfluxDB volume size is now configurable
- In the pipeline the helm relese statuses are listed and k8s objects are printed in the apps install steps.
- Alertmanager now generates alerts when certificates are about to expire (< 20 days) or if they are invalid.
- Letsencrypt email addresses are now configurable.

### Fixed
- Fixed syntax in the InfluxDB config
- Elasticsearch eating up node diskspace most likely due to a bug in the performance_analyzer plugin.
- InfluxDB database retention variables are now used.

### Removed
- InfluxDB backups are automatically removed after 7 days.
- `CK8S_ADDITIONAL_VALUES` is now deprecated and no longer supported. Everything needed can now be set as values in config files.
- `set-storage-class.sh` is removed. The storage class can now be set as a value directly in the config instead.
- Elasticsearch credentials from ck8sdash.
- Broken elasticsearch api key creation from ck8sdash.
- The `ENABLE_PSP` config value is removed. "Disabling" has to be done by creating a permissive policy instead.

-------------------------------------------------
## v0.5.0 - 2020-08-06

# Initial release

First release of the application installer for Compliant Kubernetes.

The application installer will both install and configure applications forming the Compliant Kubernetes on top of existing Kubernetes clusters.
