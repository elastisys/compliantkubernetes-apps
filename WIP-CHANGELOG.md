# Release notes

# Updated

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
- The falco grafana dashboard now shows the misbehaving pod and instance for traceability

### Fixed

### Added

- Added fluentd metrics

### Removed
