---
from: v0.43
to: main
---

# Main upgrade and migration

<!-- begin preamble --->

> [!caution]
> This is the upgrade and migration process for the next version of Welkin Apps not intended for production!
>
> Upgrade is supported from any patch version of the major or minor version stated in the `from` field above!

> [!tip]
> Contributors please see the [migration readme](../README.md) for instructions on how to write migration steps.

<!--- end preamble --->

## Prerequisites

- [ ] Read through [the changelog of the new version](../../changelog) for notices.
    - This includes platform administrator, application developer, and security notices as they will detail any breaking changes.
- [ ] Notify users of the environment before the upgrade starts.
- [ ] Ensure the environment has no pending changes.
- [ ] Ensure the environment is in a good state, including the status of backups and other jobs:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get jobs -A
    ./bin/ck8s ops kubectl sc|wc get nodes
    ./bin/ck8s ops helm sc|wc list -A --all
    ./bin/ck8s ops velero sc|wc get backup
    ```

- [ ] Disable alert notifications during the upgrade. e.g using [Alertmanager silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences).

## Automatic method

> [!tip]
> It is possible to either upgrade both the service and workload cluster together, or upgrade service clusters and workload clusters separately by supplying the upgrade command with the `both`, `sc`, or `wc` target cluster arguments.

1. Switch to the main branch and pull the latest changes:

    ```bash
    git switch main
    git pull
    ```

1. Prepare upgrade

    > _Non-disruptive, done before maintenance window._

    ```bash
    ./bin/ck8s upgrade <target-cluster> main prepare

    # Check if any NetworkPolicy IPs need to be updated
    ./bin/ck8s update-ips <target-cluster> dry-run
    # Apply the changes if you agree with them
    ./bin/ck8s update-ips <target-cluster> apply
    ```

1. Apply upgrade

    > **Disruptive, done during maintenance window.**

    ```bash
    ./bin/ck8s upgrade both <target-cluster> apply
    ```

## Manual method

> [!warning]
> When running migration snippets directly you can target to either upgrade both the service and workload cluster together, or to upgrade service clusters and workload clusters separately by setting and exporting the environment variable `CK8S_CLUSTER` with `both`, `sc`, or `wc` respectively.
>
> This must be set and exported for both the prepare and apply upgrade steps!

### Prepare upgrade

> _Non-disruptive, done before maintenance window._

1. Switch to the main branch and pull the latest changes:

    ```bash
    git switch main
    git pull
    ```

1. Update configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./migration/main/prepare/50-init.sh

    # Check if any NetworkPolicy IPs need to be updated
    ./bin/ck8s update-ips ${CK8S_CLUSTER} dry-run
    # Apply the changes if you agree with them
    ./bin/ck8s update-ips ${CK8S_CLUSTER} apply
    ```

### Apply upgrade - *disruptive*

> **Disruptive, done during maintenance window.**

1. Upgrade applications:

    ```bash
    ./migration/main/apply/80-apply.sh execute
    ```

## Postrequisites

- [ ] Ensure the environment is in a good state:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get nodes
    ./bin/ck8s ops helm sc|wc list -A --all
    ```

    It can also be good to check that authentication still works, as well as alerting, monitoring, and logging with fresh metrics and logs.
    And to ensure that alerts opened during the upgrade close afterwards.

- [ ] Enable alert notifications after the upgrade.
- [ ] Notify users of the environment after the upgrade is completed.
