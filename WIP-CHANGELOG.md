### Release notes
- In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, have been removed from the custom resource definitions (CRDs).
- In 1.8 the cert-manager will validate the spec.privateKey.rotationPolicy on Certificate resources. Valid options are Never and Always.
- bash scripts are now migrated to yq-v4.26.1
  - Requires `yq4` as an alias to yq v4. Installed via `get-requirements.yaml`.

### Updated
- cert-manager from v1.6.1 to v1.8.2. [Full changelog](https://github.com/cert-manager/cert-manager/releases?page=1)
    - In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, that were deprecated in 1.4, have been removed from the custom resource definitions (CRDs). Read [Migrating Deprecated API Resources](https://cert-manager.io/docs/installation/upgrading/remove-deprecated-apis/) for full instructions.
    - The field spec.privateKey.rotationPolicy on Certificate resources is now validated. Valid options are Never and Always. If you are using a GitOps flow and one of your YAML manifests contains a Certificate with an invalid value, you will need to update it with a valid value to prevent your GitOps tool from failing on the new validation. Please follow the instructions listed on the page [Upgrading from v1.7 to v1.8](https://cert-manager.io/docs/installation/upgrading/upgrading-1.7-1.8/).
- Upgraded Opensearch helm chart to `1.13.1`, this upgrades Opensearch to `1.3.4`. For more information about the upgrade, check out their [1.3 Launch Announcement](https://opensearch.org/blog/releases/2022/03/launch-announcement-1-3-0/).
- Upgraded Opensearch-Dashboards helm chart to `1.7.4`, this upgrades Opensearch-Dashboards to `1.3.4`

### Changed
- The Kubernetes status Grafana dashboard (new node filter, new graphs for CPU/Memory requests and limits per node, updated graphs for CPU/Memory usage/requests)
- bash scripts are now migrated to yq-v4.26.1
- Changed Velero WC namespace selectors from including user namespaces to include all and exclude system namespaces in order to support HNC
- Split harbor affinity to apply for each component and added default podantiaffinity

### Fixed
- Fixed a bug where you could set the XSRF key to an invalid length without any notifications
- Fixed a bug where config for notary wasn't propagated to the chart

### Added
- Option to create custom solvers for letsencrypt issuers, including a simple way to add secrets.
- Add external redis database as option for harbor
- a new alert `FluentdAvailableSpaceBuffer`, notifies when the fluentd buffer is filling up
- Option to enable `allowSnippetAnnotations` from the configs
- Add external database as option for harbor
- the possibility to enable falco in the service cluster and added some rules or alert exceptions
- Added the `node-role.kubernetes.io/control-plane:NoSchedule` toleration
- Add hierarchical namespace controller, allowing self-serve namespaces within namespaces
- Configuration options for setting up harbor in HA

### Removed
