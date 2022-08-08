### Release notes
- In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, have been removed from the custom resource definitions (CRDs).
- In 1.8 the cert-manager will validate the spec.privateKey.rotationPolicy on Certificate resources. Valid options are Never and Always.

### Updated
- cert-manager from v1.6.1 to v1.8.2. [Full changelog](https://github.com/cert-manager/cert-manager/releases?page=1)
    - In 1.7 the cert-manager API versions v1alpha2, v1alpha3, and v1beta1, that were deprecated in 1.4, have been removed from the custom resource definitions (CRDs). Read [Migrating Deprecated API Resources](https://cert-manager.io/docs/installation/upgrading/remove-deprecated-apis/) for full instructions.
    - The field spec.privateKey.rotationPolicy on Certificate resources is now validated. Valid options are Never and Always. If you are using a GitOps flow and one of your YAML manifests contains a Certificate with an invalid value, you will need to update it with a valid value to prevent your GitOps tool from failing on the new validation. Please follow the instructions listed on the page [Upgrading from v1.7 to v1.8](https://cert-manager.io/docs/installation/upgrading/upgrading-1.7-1.8/).

### Changed

### Fixed

### Added

### Removed
