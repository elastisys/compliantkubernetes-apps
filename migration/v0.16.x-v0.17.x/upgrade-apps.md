# Upgrade v0.16.x to v0.17.0

1. Checkout the new release: `git checkout v0.17.0`

1. Run migration script: `./migration/v0.16.x-v0.17.x/migrate-harbor-swift-config.sh`

   This script will move config values from `citycloud.*` to `harbor.persistence.swift` if they exist.

1. Rename `clusterAdmin.admins` to `clusterAdmin.users` for both `wc-config.yaml` and `sc-config.yaml`

1. Check that `global.clusterDns` in both `wc-config.yaml` and `sc-config.yaml` matches the IP for the `coredns` service in `kube-system` namespace.
   Old default values did not match defaults in Kubespray.

1. Run init to get new defaults:

    ```bash
    bin/ck8s init
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
