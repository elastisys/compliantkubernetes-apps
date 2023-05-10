# Upgrade to v0.30.x

> **Warning**: Upgrade only supported from v0.29.x.

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

### Important - PodSecurityPolicies

> **Warning**: This release of apps migrates from Kubernetes PodSecurityPolicies to Kubernetes PodSecurityStandards using namespace labels and Gatekeeper PodSecurityPolicies using constraints and mutations.

After performing the upgrade it is possible to disable Kubernetes PodSecurityPolicy admission.

After doing the `disruptive` step for either the automatic or manual method, you should follow these steps to disable Kubernetes PSP:

1. Disable PSP admission for the clusters

    For compliantkubernetes-kubespray you can follow [5. Disable Pod Security Policies](https://github.com/elastisys/compliantkubernetes-kubespray/blob/main/migration/v2.20.0-ck8sx-v2.21.0-ck8s1/upgrade-cluster.md) to disable PodSecurityPolicies.

1. Clean up leftover rolebindings bypassing PSP admission:

    ```bash
    ./migration/v0.30/apply/14-kubernetes-psp.sh clean
    ```

1. If you want to enable Gatekeeper PSP for rook-ceph, set `rookCeph.enabled` to `true` in your `common-config.yaml`.

## Automatic method

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.30.x
    ```

    > **Optional**
    > Configure ingress nginx:
    >It is now possible from the config nginx to use NodePort.
    > This is configured under `ingressNginx.controller`
    > ```yaml
    > # Use NodePort instead
    > useHostPort: false
    > service:
    >   enabled: true
    >   type: NodePort
    >   nodePorts:
    >     http: 30080
    >     https: 30443
    > ```

1. Prepare upgrade - *non-disruptive*

    > *Done before maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.30 prepare
    ```

1. Apply upgrade - *disruptive*

    > *Done during maintenance window.*

    ```bash
    ./bin/ck8s upgrade v0.30 apply
    ```

## Manual method

### Prepare upgrade - *non-disruptive*

> *Done before maintenance window.*

1. Pull the latest changes and switch to the correct branch:

    ```bash
    git pull
    git switch -d v0.30.x
    ```

1. Update override `promIndexAlerts` limit for `authlog`:

    ```bash
    ./migration/v0.30/prepare/05-increase-promIndexAlerts-authlog.sh
    ```

1. Update Gatekeeper configuration:

    ```bash
    ./migration/v0.30/prepare/09-gatekeeper.sh
    ```

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    ./bin/ck8s init
    # or
    ./migration/v0.30/prepare/10-init.sh
    ```

1. **Optional** Configure ingress nginx:

    It is now possible from the config nginx to use NodePort.

    This is configured under `ingressNginx.controller`

    ```yaml
    # Use NodePort instead
    useHostPort: false
    service:
      enabled: true
      type: NodePort
      nodePorts:
        http: 30080
        https: 30443
    ```
1. **Optional** Enable opensearch-securityadmin if disabled.

    ```diff
    # sc-config.yaml
    opensearch:
    - securityadmin:
    -   enabled: false
    ```

    This is necessary to update the permissions for opensearch-configurer.
    If opensearch-securityadmin is left disabled, opensearch-configurer will continue to always register the snapshot repository when run.
    Note, that any manual edits done to the security config will be wiped once opensearch-securityadmin has run.
    The need to manually have to edit the security config should be less significant now as it is possible to create static users by configuring `opensearch.extraUsers` in `secrets.yaml`.

1. Check if user-alertmanager is disabled and disable it in the overwrite `common-config`:

    ```bash
    ./migration/v0.30/prepare/20-user-alertmanager.sh
    ```

1. Migrate the prometheusConfigReloader resources requests and limits to the new format:

    ```bash
    ./migration/v0.30/prepare/30-prometheus-config-reloader.sh
    ```

1. Migrate starboard to trivy configurations:

    ```bash
    ./migration/v0.30/prepare/40-starboard-to-trivy.sh
    ```

1. Migrate velero restic to nodeAgent configurations:

    ```bash
    ./migration/v0.30/prepare/50-velero-restic-to-nodeagent.sh
    ```

### Apply upgrade - *disruptive*

> *Done during maintenance window.*

1. Rerun bootstrap:

    ```bash
    ./bin/ck8s bootstrap {sc|wc}
    # or
    ./migration/v0.30/apply/10-bootstrap.sh execute
    ```

1. Apply the new kube-prometheus-stack CRDs:

    ```bash
    ./migration/v0.30/apply/11-prometheus-operator-crds.sh execute
    ```

1. Update network policies:

    ```bash
    ./migration/v0.30/apply/12-netpol.sh execute
    ```

1. Apply the new Gatekeeper pod security policies:

    ```bash
    ./migration/v0.30/apply/13-gatekeeper-psp.sh execute
    ```

1. Apply bypass for Kubernetes pod security policy admission:

    ```bash
    ./migration/v0.30/apply/14-kubernetes-psp.sh execute
    ```

1. Remove node-exporter and kube-state-metrics:

    ```bash
    ./migration/v0.30/apply/20-remove-kube-prometheus-components.sh execute
    ```

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    # or
    ./migration/v0.30/apply/80-apply.sh execute
    ```

1. Uninstall the old starboard stack including starboard-operator and its exporters:

    ```bash
    ./migration/v0.29/apply/90-uninstalls.sh execute
    ```

1. Restart pods violating the new Gatekeeper PSPs

    ```bash
    ./migration/v0.30/apply/99-psp-violations.sh execute
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
    ./bin/ck8s ops helm sc|wc list -A --all
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> **_Note:_** Additionally it is good to check:

- if any alerts generated by the upgrade didn't close;
- if you can login to Grafana, Opensearch or Harbor;
- you can see fresh metrics and logs.
