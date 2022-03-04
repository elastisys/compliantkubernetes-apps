# Release notes
- Ingress-nginx has been upgraded from 0.49.3 to 1.1.1.
    - In ingress-nginx >= 1.0.0, an ingressClass object is required.
        By default, an ingressClass called `nginx` will be available in the cluster.
        Ingress-nginx will still handle ingresses that do not specify an `ingressClassName`, however users are strongly encouraged to update their Ingress Objects and specify `spec.ingressClassName: nginx`.
    - The entire changelog can be found [here](https://github.com/kubernetes/ingress-nginx/blob/main/Changelog.md).
- Added a new config `global.containerRuntime` (default set to `containerd`).
  - Supported runtimes are `containerd` and `docker`
- The option to enable and configure [kured](https://github.com/weaveworks/kured) to keep nodes up to date with security patches.
  Kured is disabled by default.


### Updated
 - Upgraded nginx-ingress helm chart to `v4.0.17`, which upgrade nginx-ingress to `v1.1.1`.
    When upgrading an ingressClass object called `nginx` will be installed, this class has been set as the default class in Kubernetes.
    Ingress-nginx has been configured to still handle existing ingress objects that do not specify any `ingressClassName`.
    Read more on the ingressClassName changes [here](https://kubernetes.github.io/ingress-nginx/#what-is-ingressclassname-field).
 - Upgraded starboard-operator helm chart to `v0.9.1`, upgrading starboard-operator to `v0.14.1`

### Changed

 - Exposed sc-log-retention's resource requests.
 - Persist Dex state in Kubernetes.
 - Upgrade gatekeeper helm chart to `v3.7.0`, which also upgrades gatekeeper to `v3.7.0`.
 - Updated opensearch helm chart to version `1.7.1`, which upgrades opensearch  to `v1.2.4`.
 - Renamed release `blackbox` to `prometheus-blackbox-exporter`.
 - Added new panel to backup dashboard to reflect partial, failed and successful velero backups
 - Alertmanager group-by parameters was removed and replaced by the special value `...`
     See https://github.com/prometheus/alertmanager/blob/ec83f71/docs/configuration.md#route for more information
 - Exposed opensearch-slm-job max request seconds for curl.
 - Made opensearch-slm-job more verbose when using curl.
 - Update kubeapi-metrics ingress api version to `networking.k8s.io/v1`.
 - Fluentd can now properly handle and write orphaned documents to Opensearch when using the index per namespace feature.
  The orphaned documents will be written to `.orphaned-...` indices, which a user does not have access to read from.
 - Add `ingressClassName` in ingresses where that configuration option is available.
 - Upgrade velero helm chart to `v2.27.3`, which also upgrades velero to `v1.7.1`.
 - Upgrade prometheus-elasticsearch-exporter helm chart to v4.11.0 and prometheus-elasticsearch-exporter itself to v1.3.0
 - Exposed options for starboard-operator to control the number of jobs it generates and to allow for it to be disabled.
 - Added the new OPA policy - disallowed the latest image tag.
 - Moved `user.alertmanager.group_by` to `prometheus.alertmanagerSpec.groupBy` in `sc-config.yaml`
 - Moved `user.grafana.userGroups` to `user.grafana.oidc.userGroups` in `sc-config.yaml`
 - kubeconfig.bash have been edited to work with the new 'secret' structure.
 - memory limit for thanos receiveDistributor and pvc size for thanos receiver

### Fixed

### Added
- Added Prometheus alerts for the 'backup status' and 'daily checks' dashboards. Also, 's3BucketPercentLimit' and 's3BucketSizeQuotaGB' parameters to set what limits the s3 rule including will alert off.
- RBAC for admin user so that they now can list pods cluster wide and run the `kubectl top`.
- Added containerd support for fluentd.
- added the option to disable predict linear alerts
- fluentd alerts for sc [#812](https://github.com/elastisys/compliantkubernetes-apps/pull/812)
- fluentd grafana dashboard [#812](https://github.com/elastisys/compliantkubernetes-apps/pull/812)
- `kured` - Kubernetes Reboot Daemon. Added helm chart version `2.11.2` which defaults to `v1.9.1` of the application.

### Removed
- Removed disabled helm releases from the application helmfile
- The no longer needed rolebinding and clusterrole `metrics` has been removed.
