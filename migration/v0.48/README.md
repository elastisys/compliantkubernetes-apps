# Upgrade to v0.48.x

> [!WARNING]
> Upgrade only supported from v0.47.x.

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
    ./bin/ck8s ops velero sc|wc get backup
    ```

- [ ] Silence the notifications for the alerts. e.g you can use [alertmanager silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences);

## Automatic method

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.48.x
    ```

1. Prepare upgrade - _non-disruptive_

    > _Done before maintenance window._

    ```bash
    ./bin/ck8s upgrade both v0.48 prepare

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips both dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips both apply
    ```

    > **Note:**
    > It is possible to upgrade `wc` and `sc` clusters separately by replacing `both` when running the `upgrade` command, e.g. the following will only upgrade the workload cluster:

    ```bash
    ./bin/ck8s upgrade wc v0.48 prepare
    ./bin/ck8s upgrade wc v0.48 apply
    ```

1. Apply upgrade - _disruptive_

    > _Done during maintenance window._

    ```bash
    ./bin/ck8s upgrade both v0.48 apply
    ```

1. Update all services if you enabled the enforcement of ipFamilyPolicy and ipFamilies

    > [!WANING]
    > This should only be done if you have enabled the enforcement of ipFamilyPolicy and ipFamilies.
    > You can check this by looking at the values `.global.enforceIPFamilyPolicy` and `.global.enforceIPFamilies` and see if any of those is set to `true`
    > After you've ran this you can't revert to `SingleStack` without recreating the service.

    If you are updating to `PreferDualStack` you can use the following snippet to update all services that hasn't been updated by config.

    ```bash
    CLUSTER="sc" # Or wc

    bin/ck8s ops kubectl "${CLUSTER}" get svc -A -o=custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,POLICY:.spec.ipFamilyPolicy' | \
        # Filter out SingleStack services
        grep SingleStack | \
        # Print namespace and name of service
        awk '{print $1 " " $2}' | \
        xargs -L1 kubectl patch svc -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}' --type=merge -n
    ```

## Manual method

### Prepare upgrade - _non-disruptive_

> _Done before maintenance window._

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.48.x
    ```

1. Set whether or not upgrade should be prepared for `both` clusters or for one of `sc` or `wc`:

    ```bash
    export CK8S_CLUSTER=<wc|sc|both>
    ```

1. This will move `.calicoFelixMetrics` and `.calicoAccountant` under `.networkPlugin.calico` config group.

    ```bash
    ./migration/v0.48/prepare/10-move-calico-config.sh
    ```

1. Remove OpenSearch SLM config, as it has been replaced by SM Policy:

    ```bash
    ./migration/v0.48/prepare/20-opensearch-slm.sh
    ```

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init ${CK8S_CLUSTER}
    # or
    ./migration/v0.48/prepare/50-init.sh

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

1. Remove OpenSearch SLM as it has been replaced by SM Policy:

    ```bash
    ./migration/v0.48/apply/10-opensearch-slm.sh execute
    ```

    > **Note:**
    > Snapshots that are _not_ created by the SM policy will no longer be automatically be removed, and will require manual cleanup once their retention period is up.

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.48/apply/80-apply.sh execute
    ```

1. Update all services if you enabled the enforcement of ipFamilyPolicy and ipFamilies

    > [!WANING]
    > This should only be done if you have enabled the enforcement of ipFamilyPolicy and ipFamilies.
    > You can check this by looking at the values `.global.enforceIPFamilyPolicy` and `.global.enforceIPFamilies` and see if any of those is set to `true`
    > After you've ran this you can't revert to `SingleStack` without recreating the service.

    If you are updating to `PreferDualStack` you can use the following snippet to update all services that hasn't been updated by config.

    ```bash
    CLUSTER="sc" # Or wc

    bin/ck8s ops kubectl "${CLUSTER}" get svc -A -o=custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,POLICY:.spec.ipFamilyPolicy' | \
        # Filter out SingleStack services
        grep SingleStack | \
        # Print namespace and name of service
        awk '{print $1 " " $2}' | \
        xargs -L1 kubectl patch svc -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}' --type=merge -n
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
