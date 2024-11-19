# Upgrade to v0.43.x

> [!WARNING]
> Upgrade only supported from v0.42.x.

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

- [ ] Read through the changelog to check if there are any changes you need to be aware of. Read through the release notes, Platform Administrator notices, Application Developer notices, and Security notice.
- [ ] Notify the users (if any) before the upgrade starts;
- [ ] Check if there are any pending changes to the environment;
- [ ] Check the state of the environment, pods, nodes and backup jobs:

    ```bash
    ./bin/ck8s test sc|wc
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
    git switch -d v0.43.x
    ```

1. Prepare upgrade - _non-disruptive_

    > _Done before maintenance window._

    ```bash
    ./bin/ck8s upgrade both v0.43 prepare

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips both dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips both apply
    ```

    > **Note:**
    > It is possible to upgrade `wc` and `sc` clusters separately by replacing `both` when running the `upgrade` command, e.g. the following will only upgrade the workload cluster:

    ```bash
    ./bin/ck8s upgrade wc v0.43 prepare
    ./bin/ck8s upgrade wc v0.43 apply
    ```

1. The config for `.hnc.excludedExtraNamespaces` has been moved to `.hnc.excludedNamespaces`. As such aliases used for `.hnc.excludedExtraNamespaces` in `$CK8S_CONFIG_PATH/wc-config.yaml` may be overwritten to the actual values, and need to be manually replaced with the alias again if desired.

1. If Tekton is enabled, ensure to add appropriate network policies that allow traffic from Tekton to OpenSearch.

    To check if the tekton is enabled, run the following command

    ```bash
    yq4 '.tektonPipelines.enabled == true' $CK8S_CONFIG_PATH/sc-config.yaml
    ```

  Example of how the network policies for the pipeline can be found on the [documentation page](https://elastisys.io/welkin/operator-manual/schema/config-properties-network-policies-config-properties-network-policies-tekton-pipeline/#pipeline).

1. If Harbor is using azure object storage and you are using rclone sync, then you need to disable default sync buckets and configure them manually.

    You should set `objectStorage.sync.syncDefaultBuckets: false` and add the default buckets to the list of sync buckets. Except for the harbor bucket, there you instead need to add something like this:

    ```yaml
    objectStorage:
        sync:
            enabled: true
            destinationType: s3
            syncDefaultBuckets: false
            buckets:
            - source: <azure-env-name>-harbor
                sourcePath: //docker
                destinationPath: /docker # set //docker if syncing from azure to azure
                nameSuffix: docker
            - source: <azure-env-name>-harbor
                sourcePath: /backups
                destinationPath: /backups
                nameSuffix: backups
            # config for the other default buckets need to be added here as well
    ```

    This is because of an issue in Harbor where it is saving image data in the path `//docker/` but rclone by default skips the `//` path. So we need to add a manual config to sync that. The default sync job would also remove the docker folder from the destination since it is skipping it in the source, that is why the default job needs to be disabled.

1. The resource request capacity management alerts have been reworked to target the `elastisys.io/node-group` label instead of being based on node name patterns. As such, any previous override config for `prometheus.capacityManagementAlerts.requestLimit` has been removed. These can be manually reconfigured if the new defaults are not suitable.

1. Apply upgrade - _disruptive_

    > _Done during maintenance window._

    ```bash
    ./bin/ck8s upgrade both v0.43 apply
    ```

## Manual method

### Prepare upgrade - _non-disruptive_

> _Done before maintenance window._

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.43.x
    ```

1. Set whether or not upgrade should be prepared for `both` clusters or for one of `sc` or `wc`:

    ```bash
    export CK8S_CLUSTER=<wc|sc|both>
    ```

1. Remove outdated capacity alert config:

    ```bash
    ./migration/v0.43/prepare/10-capacity-alerts.sh

1. Migrate `.hnc.excludedExtraNamespaces` to `.hnc.excludedNamespaces`:

    ```bash
    ./migration/v0.43/prepare/20-hnc-config.sh
    ```

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init ${CK8S_CLUSTER}
    # or
    ./migration/v0.43/prepare/50-init.sh

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips ${CK8S_CLUSTER} dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips ${CK8S_CLUSTER} apply
    ```

### Apply upgrade - _disruptive_

> _Done during maintenance window._

1. Set whether or not upgrade should be applied for `both` clusters or for one of `sc` or `wc`:

    ```bash
    export CK8S_CLUSTER=<wc|sc|both>
    ```

1. Upgrade Opensearch:

    ```bash
    ./migration/v0.43/apply/20-upgrade-opensearch.sh execute
    ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.43/apply/80-apply.sh execute
    ```

## Postrequisite

- [ ] Check the state of the environment, pods and nodes:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get nodes
    ./bin/ck8s ops helm sc|wc list -A --all
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> [!NOTE]
> Additionally it is good to check:
>
> - if any alerts generated by the upgrade didn't close;
> - if you can login to Grafana, Opensearch or Harbor;
> - you can see fresh metrics and logs.
