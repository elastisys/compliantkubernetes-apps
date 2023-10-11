# Upgrade to v0.33.x

> [!WARNING]
> Upgrade only supported from v0.32.x.

<!--
Notice to developers on writing migration steps:

- Migration steps:
  - are written per minor version and placed in a subdirectory of the migration directory with the name `vX.Y/`,
  - are written to be idempotent and usable no matter which patch version you are upgrading from and to,
  - are documented in this document to be able to run them manually,
  - are divided into prepare and apply steps:
    - Prepare steps:
      - are placed in the `prepare/` directory,
      - may **only** modify the configuration of the environment,
      - may **not** modify the state of the environment,
      - steps are run in order of their names use two digit prefixes.
    - Apply steps:
      - are placed in the `apply/` directory,
      - may **only** modify the state of the environment,
      - may **not** modify the configuration of the environment,
      - are run in order of their names use two digit prefixes,
      - are run with the argument `execute` on upgrade and should return 1 on failure and 2 on successful internal rollback,
      - are rerun with the argument `rollback` on execute failure and should return 1 on failure.

For prepare the init step is given.
For apply the bootstrap and the apply steps are given, it is expected that releases upgraded in custom steps are excluded from the apply step.

Upgrades of components that are dependent on each other should be done within the same snippet to easily manage the upgrade to a working state and to be able to rollback to a working state.

Steps should use the `scripts/migration/lib.sh` which will provide helper functions, see the file for available helper functions.
This script expects the `ROOT` environment variable to be set pointing to the root of the repository.
As with all scripts in this repository `CK8S_CONFIG_PATH` is expected to be set.
-->

## Prerequisites

- If `.objectStorage.sync.enabled: true` and `.objectStorage.sync.syncDefaultBuckets: true` and `.thanos.objectStorage.type: swift` or `.harbor.persistence.type: swift` then the rclone jobs will automatically use swift for Thanos and/or Harbor source and destination buckets. You will need to create the application credentials for swift and add them into the `secrets.yaml`:

    <details><summary>Create source application credentials</summary>

    ```bash
    source ${CK8S_CONFIG_PATH}/<source-openrc>.sh
    source <(sops -d ${CK8S_CONFIG_PATH}/secret/<source-env-openstack-user>.sh)

    openstack application credential create <env-name>-swift

    sops ${CK8S_CONFIG_PATH}/secrets.yaml

    # set objectStorage.swift.applicationCredentialID in secrets.yaml
    # set objectStorage.swift.applicationCredentialSecret in secrets.yaml
    ```

    </details>

    <details><summary>Create destination application credentials</summary>

    ```bash
    source ${CK8S_CONFIG_PATH}/<destination-openrc>.sh
    source <(sops -d ${CK8S_CONFIG_PATH}/secret/<destination-env-openstack-user>.sh)

    openstack application credential create <env-name>-swift

    sops ${CK8S_CONFIG_PATH}/secrets.yaml

    # set objectStorage.sync.swift.applicationCredentialID in secrets.yaml
    # set objectStorage.sync.swift.applicationCredentialSecret in secrets.yaml
    ```

    </details>

> [!WARNING]
> Any `rclone-sync` job running during the upgrade will be terminated

- [ ] Suspend any `rclone-sync` jobs that are scheduled to run during the upgrade;
- [ ] Notify the users (if any) before the upgrade starts;
- [ ] Check if there are any pending changes to the environment;
- [ ] Check the state of the environment, pods, nodes and backup jobs:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s test sc|wc cert-manager
    ./bin/ck8s test sc|wc ingress
    ./bin/ck8s test sc opensearch
    ./bin/ck8s test wc hnc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get nodes
    ./bin/ck8s ops kubectl sc|wc get jobs -A
    ./bin/ck8s ops helm sc|wc list -A --all
    velero get backup
    ```

- [ ] Silence the notifications for the alerts. e.g you can use [alertmanager silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences);

## Automatic method

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.33.x
    ```

1. Prepare upgrade - *non-disruptive*

    > *Done before maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.33 prepare

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips both dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips both apply
    ```

1. Apply upgrade - *disruptive*

    > *Done during maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.33 apply
    ```

## Manual method

### Prepare upgrade - *non-disruptive*

> *Done before maintenance window.*

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.33.x
    ```

1. Move subdomain and enabled settings to the common config file:

  ```bash
  ./migration/v0.33/prepare/07-move-to-common-for-cross-cluster-probe.sh
  ```

1. Check if `.prometheus.capacityManagementAlerts.disklimit` needs to be copied:

    ```bash
    ./migration/v0.33/prepare/10-copy-capacity-alert-disklimit.sh
    ```

1. Rename the key `.objectStorage.sync.type` to `objectStorage.sync.destinationType`

    ```bash
    ./migration/v0.33/prepare/20-sync-type-new-key-name.sh
    ```

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init
    # or
    ./migration/v0.33/prepare/50-init.sh

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips both dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips both apply
    ```

### Apply upgrade - *disruptive*

> *Done during maintenance window.*

1. Rerun bootstrap:

    ```bash
    ./bin/ck8s bootstrap {sc|wc}
    # or
    ./migration/v0.33/apply/20-bootstrap.sh execute
    ```

1. Migrate Grafana dashboards:

    ```bash
    ./migration/v0.33/apply/30-grafana-dashboards.sh
    ```

1. Move `rclone-sync` from `kube-system`:

    ```bash
    ./migration/v0.33/apply/40-rclone.sh execute
    ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.33/apply/80-apply.sh execute
    ```

## Postrequisite:

- [ ] Unsuspend any `rclone-sync` jobs that were suspended before the upgrade;
- [ ] Check the state of the environment, pods and nodes:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s test sc|wc cert-manager
    ./bin/ck8s test sc|wc ingress
    ./bin/ck8s test sc opensearch
    ./bin/ck8s test wc hnc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get nodes
    ./bin/ck8s ops helm sc|wc list -A --all
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> [!NOTE]
> Additionally it is good to check:
> - if any alerts generated by the upgrade didn't close;
> - if you can login to Grafana, Opensearch or Harbor;
> - you can see fresh metrics and logs.
