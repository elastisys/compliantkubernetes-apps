# Development: Apps on Kind

(I'll integrate this better when I have tested everything.)

~~The `local-path-provisioner` seems to fail after a while~~

~~Currently it seems like `gatekeeper` might break `local-path-provisioner`~~

Containerd failed with something about mounting `/dev/input/event*` device, but it seem to work fine after recreating the kind cluster

Labelling the namespaces seem to have done the trick

## Setup

> [!warning]
> Ensure your `KUBECONFIG` variable is not pointing to a config that you don't want to get edited by `kind`.

> [!important]
> Ensure your `inotify` limits are high enough else [pods might fail with the "too many open files" or similar](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)

```
kind create cluster --name compliantkubernetes --config docs/development/cluster.yaml
kind get kubeconfig --name compliantkubernetes > "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
kind get kubeconfig --name compliantkubernetes > "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

kubectl create namespace tigera-operator
helm -n tigera-operator install tigera ./docs/development/charts/projectcalico/tigera-operator-v3.26.4.tgz

kubectl label namespace calico-apiserver calico-system local-path-storage tigera-operator owner=operator
```

## Teardown

```sh
kind delete cluster --name compliantkubernetes
```

## Deploy

> [!note]
> These have been tested with an initial bootstrap then using the new helmfile setup.
>
> All deployments have been able to be removed with a plain `destroy`.

Using the `baremetal` preset disable all reference to `rook-ceph` and set `standard` as the default storage class.

### Both Clusters

- `cert-manager` via `apply --include-transitive-needs --selector app=cert-manager`
- `falco` via `apply --include-transitive-needs --selector app=falco`
  - Will remain in error state as the pods need to be able to either load bpf or kernel module
- `gatekeeper` via `apply --include-transitive-needs --selector app=gatekeeper`
- `kured` via `apply --include-transitive-needs --selector app=kured`
- `kube-prometheus-stack` via `apply --include-transitive-needs --selector app=prometheus`
- `velero` via `apply --include-transitive-needs --selector app=velero`
  - Will not template as it requires object storage

### Service Cluster

- `dex` via `apply --include-transitive-needs --selector app=dex`
  - Will not pull in `ingress-nginx`
- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Will not template as it requires object storage
- `grafana` via `apply --include-transitive-needs --selector app=grafana`
  - Will not template as it requires `thanos` which requires  object storage
- `harbor` via `apply --include-transitive-needs --selector app=harbor`
  - Will not pull in `ingress-nginx`
  - Not with `harbor.backup.enabled: true`
  - Not with `harbor.persistence.type: objectStorage`
  - Requires a fix for DNS networkpolicies
- `opensearch` via `apply --include-transitive-needs --selector app=opensearch`
  - Will not pull in `ingress-nginx`
  - Not with `opensearch.snapshot.enabled: true`
  - Requires a fix for dex service endpoint and netpol
  - Uses significant amount of RAM
- `rclone-sync` via `apply --include-transitive-needs --selector app=rclone-sync`
  - Will not template as it requires object storage
- `thanos` via `apply --include-transitive-needs --selector app=thanos`
  - Will not template as it requires object storage

### Workload Cluster

- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Not with `fluentd.audit.enabled: true`
  - Requires a fix for dev-editable extra configmaps
- `hnc` via `apply --include-transitive-needs --selector app=hnc`
  - Has a race condition on `destroy` but it works the second time

## Missing

### Audit

To be tested.

### Ingress

To be tested.
I'll see if I can include some glue to setup a proxy+resolver in some easy way.

### Object Storage

To be tested as dev/test dependency.
