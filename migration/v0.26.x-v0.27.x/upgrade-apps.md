# Upgrade v0.26.x to v0.27.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init
    ```

1. Update network policy IPs

    ```bash
    ./bin/ck8s update-ips both update
    ```

    The `update-ips` script does not update IPs for all network policies, go through `sc-config.yaml` and `common-config.yaml` and set the IPs of the external services to whatever suits your need.

    > **_Optional_**: *If you want to set the network policy IPs of all of these external services to `0.0.0.0/0` then you can run this script, note that this exposes the services to any connections*

    ```bash
    ./migration/v0.26.x-v0.27.x/set-external-netpol-ips.sh
    ```

    > **_Note_**: With Octavia load balancers add the IP of the Amphorae instances to SC and WC nodes respectively in `common-config.yaml`.

    First list networks using `openstack network list` to find the network IDs, then using `openstack port list --network <network-id>` find the IPs used by the load balancer instances prefixed with `octavia` and add those.

    Alternatively allow the entire subnet.

1. If the loadbalancer, fronting the ingress controller, is not controlled by a kubernetes cloud controller, set the following to true in `$CK8S_CONFIG_PATH/common-config.yaml`

    ```console
    networkPolicies:
    global:
      externalLoadBalancer: true
      ingressUsingHostNetwork: true
    ```

1. If kured notification are enabled, set the ips in `$CK8S_CONFIG_PATH/common-config.yaml`

    ```console
    networkPolicies:
      kured:
        notificationSlack:
          ips:
            - 0.0.0.0/0
    ```

1. *When using Harbor on Swift:* Migrate Swift configuration.

    ```bash
    ./migration/v0.26.x-v0.27.x/migrate-swift.sh
    ```

1. Adding the additional services namespaces in `$CK8S_CONFIG_PATH/wc-config.yaml`

    ```bash
    ./migration/v0.26.x-v0.27.x/add-extra-excluded-namespaces.sh
    ```
    > **_NOTE:_** remove the namespaces that are not managed from `$CK8S_CONFIG_PATH/wc-config.yaml`

1. Reinstall HNC

    ```bash
    ./migration/v0.26.x-v0.27.x/reinstall-hnc.sh
    ```

1. *IMPORTANT* If you are using any Dex connector of type `google` and you haven't added a service account then you'll need to change it to a type `oidc`

    This can be done by adding the following line to the `config` part in the connector
    ```
    issuer: https://accounts.google.com
    ```

    The diff should look like this for `secrets.yaml`

    ```diff
    dex:
      connectors:
        - name: Example
          id: example
    -     type: google
    +     type: oidc
          config:
    +       issuer: https://accounts.google.com
            clientID: exampleid
            clientSecret: examplesecret
    ```

1. Upgrade the `workload-cluster-np` with the new changes, before applying the common-np chart:

    *If alertmanager was not enabled in wc before, you need to enable it before applying the network policies.*

    ```bash
    ./bin/ck8s bootstrap wc
    ./bin/ck8s ops helmfile wc -l app=user-alertmanager apply
    ```

    ```bash
    ./bin/ck8s ops helmfile wc -f helmfile -l app=workload-cluster-np -i apply
    ```

1. Before upgrading, destroy `falco` and `falco-exporter` in both wc & sc

    ```bash
    ./bin/ck8s ops helmfile wc -l app=falco -l app=falco-exporter destroy
    ./bin/ck8s ops helmfile sc -l app=falco -l app=falco-exporter destroy
    ```
1. If you are upgrading from v0.26.x to v0.27.1 apply this steps:

  1. Add new harbor credentials

      ```bash
      ./migration/v0.27.x-v0.28.x/add-registry-credentials.sh
      ```

  1. Migrate harbor jobservice port to ports (array)

      ```bash
      ./migration/v0.27.x-v0.28.x/move-harbor-jobservice-port-to-ports.sh
      ```

  1. Up date the IPs for harbor replication in `$CK8S_CONFIG_PATH/sc-config.yaml`

      ```yaml
      harbor:
        registries:
          ips:
            - "set-me"
      ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    ```

1. Check resource requests and limits

    Several default resource requests and limits have changed. When upgrading these might need to be changed in your environment. Check for pods that have high memory usage (or even goes OOM) or have heavily throttled CPU.

> **_NOTE:_** after the upgrade check the `NetworkPolicy Dashboard` in Grafana to see if you have any dropped packets.
