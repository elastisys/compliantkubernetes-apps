# Upgrade to v0.29.x

> **Warning**: Upgrade only supported from v0.28.x.

<!--
Notice to developers on writing migration steps:

- Migration steps:
  - are written per minor version and placed in a subdirectory of the migration directory with the name `vX.Y/`,
  - are written to be idempotent and usable no matter which patch version you are upgrading from and to,
  - are documented in this docuemnt to be able to run them manually,
  - are divided into prepare and apply steps:
    - Prepare steps:
      - are placed in the `prepare/` directoy,
      - may **only** modify the configuration of the environment,
      - may **not** modify the state of the environment,
      - steps are run in order of their names use two digit prefixes.
    - Apply steps:
      - are placed in the `apply/` directory,
      - may **only** modify the state of the environment,
      - may **not** modify the configuration of the environment,
      - are run in order of their names use two digit prefixes,
      - are run with the argument `execute` on upgrade and should return 1 on failure and 2 on succesful internal rollback,
      - are rerun with the argument `rollback` on execute failure and should return 1 on failure.

For prepare the init step is given.
For apply the bootstrap and the apply steps are given, it is expected that releases upgraded in custom steps are excluded from the apply step.

Upgrades of components that are dependant on each other should be done within the same snippet to easily manage the upgrade to a working state and to be able to rollback to a working state.

Steps should use the `scripts/migration/lib.sh` which will provide helper functions, see the file for available helper functions.
This script expects the `ROOT` environment variable to be set pointing to the root of the repository.
As with all scripts in this repository `CK8S_CONFIG_PATH` is expected to be set.
-->

## Prerequisites

- [ ] Upgrade your version of helmfile and helm diff by following these steps:
    - Uninstall `helm-diff` so that the new version can be installed:
        ```console
        $ helm plugin uninstall diff
        ```
    - From the root of your `compliantkubernetes-apps` directory, run ansible to get the updated requirements:
        ```console
        $ ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --connection local --inventory 127.0.0.1, get-requirements.yaml
        ```
- [ ] Notify the users (if any) before the upgrade starts;
- [ ] Check if there are any pending changes to the environment;
- [ ] Check the state of the environment, pods, nodes and backup jobs:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s test sc|wc cert-manager
    ./bin/ck8s test sc|wc ingress
    ./bin/ck8s test sc opensearch
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
    git switch -d v0.29.x
    ```

    > **Warning**:
    > The default Gatekeeper enforcements have been updated:
    > - Disallow latest tag `disallowedTags.enforcement` default is now `deny` - was `dryrun`
    > - Require trusted image registry `imageRegistry.enforcement` default is now `warn` - was `deny`
    > - Require network policies `networkPolicies.enforcement` default is now `warn` - was `deny`
    > - Require resource requests `resourceRequests.enforcement` default is unchanged as `deny`
    >
    > As changing these enforcements can be disruptive, especially when going from `dryrun` to `deny`, here are some recommendations:
    > - If the new default is `deny` and the environment does not already have `deny` on that specific policy, then override with `warn` and inform the user that they should work toward being able to have `deny` in the future.
    > - If the new default is `warn` and the environment has `deny`, then leave it at `deny` (possibly requiring an override config).
    > - If the new default is `warn` and the environment has `dryrun`, then use `warn` (possibly requiring removal of override config) and inform the user that they will start seeing warnings from that policy.

    > **Note**:
    > Fluentd can now collect audit logs, enable it by setting `fluentd.audit.enabled: true`.
    > The apply upgrade will create the bucket as set by `objectStorage.buckets.audit` to store those logs.
    > If the environment has rclone-sync enabled you will need to create the audit in the destination S3
    > To set the elastisys nodes tolerations and affinity for fluentd aggregator in wc edit `vim "$CK8S_CONFIG_PATH/wc-config.yaml"` and add them under `fluentd.aggregator`

1. Prepare upgrade - *non-disruptive*

    > *Done before maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.29 prepare
    ```
    > **Note**:
    > To set the elastisys nodes tolerations and affinity for fluentd aggregator in wc edit `vim "$CK8S_CONFIG_PATH/wc-config.yaml"` and add them under `fluentd.aggregator`

1. Apply upgrade - *disruptive*

    > *Done during maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.29 apply
    ```

## Manual method

### Prepare upgrade - *non-disruptive*

> *Done before maintenance window.*

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.29.x
    ```

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init
    # or
    ./migration/v0.29/prepare/10-init.sh
    ```

1. Update Fluentd configuration:

    ```bash
    ./migration/v0.29/prepare/20-fluentd.sh
    ```

    > **Note**:
    > Fluentd can now collect audit logs, enable it by setting `fluentd.audit.enable: true`.
    > Make sure to create the bucket as set by `objectStorage.buckets.audit` to store those logs.
    > To set the elastisys nodes tolerations and affinity for fluentd aggregator in wc edit `vim "$CK8S_CONFIG_PATH/wc-config.yaml"` and add them under `fluentd.aggregator`

    ```bash
    sops exec-file --no-fifo "$CK8S_CONFIG_PATH/.state/s3cfg.ini" './scripts/S3/entry.sh --s3cfg {} create'
    # or
    ./migration/v0.29/apply/01-create-buckets.sh execute
    # if rclone-sync is enabled
    sops exec-file --no-fifo "$CK8S_CONFIG_PATH/.state/destination-s3cfg.ini" './scripts/S3/entry.sh --s3cfg {} create'
    ```

1. **Warning** The default Gatekeeper enforcements have been updated:

    - Disallow latest tag `disallowedTags.enforcement` default is now `deny` - was `dryrun`
    - Require trusted image registry `imageRegistry.enforcement` default is now `warn` - was `deny`
    - Require network policies `networkPolicies.enforcement` default is now `warn` - was `deny`
    - Require resource requests `resourceRequests.enforcement` default is unchanged as `deny`

    As changing these enforcements can be disruptive, especially when going from `dryrun` to `deny`, here are some recommendations:

    - If the new default is `deny` and the environment does not already have `deny` on that specific policy, then override with `warn` and inform the user that they should work toward being able to have `deny` in the future.
    - If the new default is `warn` and the environment has `deny`, then leave it at `deny` (possibly requiring an override config).
    - If the new default is `warn` and the environment has `dryrun`, then use `warn` (possibly requiring removal of override config) and inform the user that they will start seeing warnings from that policy.

### Apply upgrade - *disruptive*

> *Done during maintenance window.*

1. Rerun bootstrap:

    ```bash
    ./bin/ck8s bootstrap {sc|wc}
    # or
    ./migration/v0.29/apply/10-bootstrap.sh execute
    ```

1. Upgrade Starboard CRDs:

    ```bash
    ./migration/v0.29/apply/11-crds.sh execute
    ```

1. Upgrade kured:

    ```bash
    ./migration/v0.29/apply/20-kured.sh execute
    ```

1. Upgrade metrics-server:

    ```bash
    ./migration/v0.29/apply/20-metrics-server.sh execute
    ```

1. Upgrade fluentd:

    ```bash
    ./migration/v0.29/apply/21-fluentd.sh execute
    ```

1. Sync user-rbac to add extra-workload-admins rolebinding:

    ```bash
    ./migration/v0.29/apply/50-user-rbac.sh execute
    ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.29/apply/80-apply.sh execute
    ```

1. Uninstall prometheus-elasticsearch-exporter:

    ```bash
    ./migration/v0.29/apply/90-uninstalls.sh execute
    ```

## Postrequisite:

- [ ] Check the state of the environment, pods and nodes:

    ```bash
    ./bin/ck8s test sc|wc
    ./bin/ck8s test sc|wc cert-manager
    ./bin/ck8s test sc|wc ingress
    ./bin/ck8s test sc opensearch
    ./bin/ck8s test wc hnc
    ./bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./bin/ck8s ops kubectl sc|wc get nodes
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> **_Note:_** Additionally it is good to check:

- if any alerts generated by the upgrade didn't close;
- if you can login to Grafana, Opensearch or Harbor;
- you can see fresh metrics and logs.
