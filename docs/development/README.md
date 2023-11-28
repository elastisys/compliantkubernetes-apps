# Development: Apps on Kind

(I'll integrate this better when I have tested everything.)

~~The `local-path-provisioner` seems to fail after a while~~

~~Currently it seems like `gatekeeper` might break `local-path-provisioner`~~

~~Labelling the namespaces seem to have done the trick~~

Containerd failed with something about mounting `/dev/input/event*` device, but it seem to work fine after recreating the kind cluster

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
kubectl create namespace seaweedfs-system

kubectl label namespaces local-path-storage tigera-operator seaweedfs-system owner=operator --overwrite=true

kubectl -n seaweedfs-system apply -f ./docs/development/seaweedfs-credentials.yaml

helm --namespace tigera-operator install tigera ./docs/development/charts/projectcalico/tigera-operator-v3.26.4.tgz --wait
helm --namespace seaweedfs-system install seaweedfs ./docs/development/charts/seaweedfs/seaweedfs-3.59.4.tgz --wait --values ./docs/development/seaweedfs.yaml

kubectl label namespace calico-apiserver calico-system owner=operator --overwrite=true
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

- `calico` via `apply --include-transitive-needs --selector app=calico`
  - Needs fix for felix metrics
  - Requires `clusterApi.enabled: true`
- `cert-manager` via `apply --include-transitive-needs --selector app=cert-manager`
- `falco` via `apply --include-transitive-needs --selector app=falco`
  - Will remain in error state as the pods need to be able to either load bpf or kernel module
- `gatekeeper` via `apply --include-transitive-needs --selector app=gatekeeper`
- `kured` via `apply --include-transitive-needs --selector app=kured`
- `kube-prometheus-stack` via `apply --include-transitive-needs --selector app=prometheus`
- `velero` via `apply --include-transitive-needs --selector app=velero`
  - Requires object storage

### Service Cluster

- `dex` via `apply --include-transitive-needs --selector app=dex`
  - Will not pull in `ingress-nginx`
- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Requires object storage
  - Requires a fix to check S3 protocol
- `grafana` via `apply --include-transitive-needs --selector app=grafana`
  - Will not pull in `ingress-nginx`
  - Requires object storage due to `thanos`
- `harbor` via `apply --include-transitive-needs --selector app=harbor`
  - Will not pull in `ingress-nginx`
  - Requires object storage
- `opensearch` via `apply --include-transitive-needs --selector app=opensearch`
  - Will not pull in `ingress-nginx`
  - Requires object storage
  - Uses significant amount of RAM
- `rclone-sync` via `apply --include-transitive-needs --selector app=rclone-sync`
  - Requires object storage
- `thanos` via `apply --include-transitive-needs --selector app=thanos`
  - Requires object storage
  - Requires a fix to check S3 protocol

### Workload Cluster

- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Requires a fix for dev-editable extra configmaps
  - Requires an edit for in-cluster opensearch endpoint (or potentially add that to sc fluentd)
- `hnc` via `apply --include-transitive-needs --selector app=hnc`
  - Has a race condition on `destroy` but it works the second time

## Missing

### Audit

To be tested.

### Ingress

To be tested.
I'll see if I can include some glue to setup a proxy+resolver in some easy way.

### Object Storage

Works with either `minio` or `seaweedfs`, TBD which one will be included.

Regardless we need to prepare for a better way to handle private S3 endpoints.

### Pull-through Registry Cache

Needs investigation as it is quite easy to hit pull limits.
