# Upgrade v0.16.x to v0.17.0

1. Checkout the new release: `git checkout v0.17.0`

1. Run migration script: `./migration/v0.16.x-v0.17.x/migrate-harbor-swift-config.sh`

    This script will move config values from `citycloud.*` to `harbor.persistence.swift` if they exist.

1. Rename `clusterAdmin.admins` to `clusterAdmin.users` for both `wc-config.yaml` and `sc-config.yaml`

1. Check that `global.clusterDns` in both `wc-config.yaml` and `sc-config.yaml` matches the IP for the `coredns` service in `kube-system` namespace.

    Old default values did not match defaults in Kubespray.

1. Run migration script: `./migration/v0.16.x-v0.17.x/migrate-dex-additional-static-clients.sh`

    This script introduces `dex.additionalStaticClients` and create entries for each additional static client already defined on the CK8S cluster.

1. Verify if the script added all your custom static clients under `dex.additionalStaticClients`. If so, delete the backup at `${CK8S_CONFIG_PATH}/secrets.yaml.bak`.

1. To upgrade kube-prometheus-stack from 12.8.0 to 16.6.1 you need to run:

    ```bash
    bin/ck8s ops kubectl sc apply -f 'helmfile/upstream/kube-prometheus-stack/crds'
    ```
    ```bash
    bin/ck8s ops kubectl wc apply -f 'helmfile/upstream/kube-prometheus-stack/crds'
    ```

    and then apply the new changes.

1. Run init to get new defaults:

    ```bash
    bin/ck8s init
    ```

1. Remove the old version of dex to then replace it with the new one by apply

    ```bash
    bin/ck8s ops helmfile sc -l app=dex destroy
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Restart the blackbox-prometheus-blackbox-exporter pod to make changes active.

    ```bash
    bin/ck8s ops kubectl sc delete pod -l app.kubernetes.io/name=prometheus-blackbox-exporter -n monitoring
    ```

1. Run migration script: `./migration/v0.16.x-v0.17.x/migrate-openid.sh`

    This script will reload the security config config.yml to make openid run by the new port
