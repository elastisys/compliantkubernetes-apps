# Upgrade v0.16.x to v0.17.0

1. Checkout the new release: `git checkout v0.17.0`

1. Rename `clusterAdmin.admins` to `clusterAdmin.users` for both `wc-config.yaml` and `sc-config.yaml`

1. Run init to get new defaults:

    ```bash
    bin/ck8s init
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
