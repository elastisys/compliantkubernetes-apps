# Upgrade v0.27.x to v0.28.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Migrate nginx service annotations from a string to a map

    ```
    ./migration/v0.27.x-v0.28.x/move-nginx-controller-service-annotation-to-map.sh
    ```

1. Migrate harbor jobservice port to ports (array)

    ```
    ./migration/v0.27.x-v0.28.x/move-harbor-jobservice-port-to-ports.sh
    ```

1. Add new harbor credentials

    ```bash
    ./migration/v0.27.x-v0.28.x/add-registry-credentials.sh
    ```

1. Update network policies:

    - Set `networkPolicies.coredns.extarnalDns.ips` to your upstream DNS servers.

      > *If you are unsure of which your upstream DNS servers are set this to `0.0.0.0/0`.*

    - *With OpenStack Cinder blockstorage:* Set `networkPolicies.kubeSystem.openstack.ips` to your OpenStack endpoints for Keystone, Nova, and Cinder.

      > *Usually these are the same endpoint and you can discover them by issuing `openstack catalog list`, then resolve the hostname of the public endpoint to find all IP addresses. If they do not use the standard ports `5000`, `8774`, and `8776` then be sure to configure them as well.*

    - *With OpenStack Octavia load balancer:* Reconfigure `networkPolicies.global.scNodes` and `networkPolicies.global.wcNodes` to use the full subnet of your private network.

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Removing the legacy datasources requires a pod restart.

    a. check if the grafana pods have restarted (restart them if not):

    ```bash
    bin/ck8s ops kubectl sc get po -n monitoring -l app.kubernetes.io/name=grafana
    ```

    b. check in the UI if the legacy datasources were removed
