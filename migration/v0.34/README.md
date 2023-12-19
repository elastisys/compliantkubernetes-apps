# Upgrade to v0.34.x

> [!WARNING]
> Upgrade only supported from v0.33.x.

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
    git switch -d v0.34.x
    ```

1. Prepare upgrade - *non-disruptive*

    > *Done before maintenance window.*

    ```bash
    ./bin/ck8s upgrade both v0.34 prepare

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips both dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips both apply
    ```

    > [!NOTE]
    > It is possible to upgrade `wc` and `sc` clusters separately by replacing `both` when running the `upgrade` command, e.g. the following will only upgrade the workload cluster:
    > ```bash
    > ./bin/ck8s upgrade wc v0.34 prepare
    > ./bin/ck8s upgrade wc v0.34 apply
    > ```

1. Apply upgrade - *disruptive*

    > *Done during maintenance window.*

    ```bash
    ./bin/ck8s upgrade both v0.34 apply
    ```

## Manual method

### Prepare upgrade - *non-disruptive*

> *Done before maintenance window.*

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.34.x
    ```

1. Set whether or not upgrade should be prepared for `both` clusters or for one of `sc` or `wc`:

    ```bash
    export CK8S_CLUSTER=<wc|sc|both>
    ```

1. Verify that no important resources are present in the `elastic-system` and `influxdb-prometheus` namespaces.

    ``` bash
    ./migration/v0.34/prepare/30-delete-obsolete-ns.sh
    ```

    Expected output:

    ```
    No resources found in elastic-system namespace.
    No resources found in influxdb-prometheus namespace.
    ```

    If resources _are_ present, verify that they are not something important.

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init ${CK8S_CLUSTER}
    # or
    ./migration/v0.34/prepare/50-init.sh

    # check if the netpol IPs need to be updated
    ./bin/ck8s update-ips ${CK8S_CLUSTER} dry-run
    # if you agree with the changes apply
    ./bin/ck8s update-ips ${CK8S_CLUSTER} apply
    ```

### Apply upgrade - *disruptive*

> *Done during maintenance window.*

1. Set whether or not upgrade should be applied for `both` clusters or for one of `sc` or `wc`:

    ```bash
    export CK8S_CLUSTER=<wc|sc|both>
    ```

1. Apply the new kube-prometheus-stack CRDs:

    ```bash
    ./migration/v0.34/apply/11-prometheus-operator-crds.sh execute
    ```

1. Apply the new HNC CRDs:

    ```bash
    ./migration/v0.34/apply/12-hnc-crds.sh execute
    ```

1. Rerun bootstrap:

    ```bash
    ./bin/ck8s bootstrap {sc|wc}
    # or
    ./migration/v0.34/apply/20-bootstrap.sh execute
    ```

1. Delete obsolete namespaces:

    ```bash
    ./migration/v0.34/apply/30-delete-obsolete-ns.sh execute
    ```

1. Uninstall the trivy operator to install an upgraded version later during the upgrade

    ```bash
    ./migration/v0.34/apply/40-uninstalls.sh execute
    ```

1. Apply the trivy-operator CRDs

    ```bash
    ./migration/v0.35/apply/50-trivy-operator-crds.sh execute
    ```

1. Unmanage the user-alertmanager secret:

    ```bash
    ./migration/v0.34/apply/70-unmanage-user-alertmanager-secret.sh execute
    ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.34/apply/80-apply.sh execute
    ```

## Postrequisite:

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
> - if any alerts generated by the upgrade didn't close;
> - if you can login to Grafana, Opensearch or Harbor;
> - you can see fresh metrics and logs.
