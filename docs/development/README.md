# Development: Apps on Kind

(I'll integrate this better when I have tested everything.)

~~The `local-path-provisioner` seems to fail after a while~~

~~Currently it seems like `gatekeeper` might break `local-path-provisioner`~~

~~Labelling the namespaces seem to have done the trick~~

Containerd failed with something about mounting `/dev/input/event*` device, but it seem to work fine after restarting the worker node containers.

## Setup

> [!warning]
> Ensure your `KUBECONFIG` variable is not pointing to a config that you don't want to get edited by `kind`.

> [!important]
> Ensure your `inotify` limits are high enough else [pods might fail with the "too many open files" or similar](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)

> [!important]
> To use rootless `podman` or `docker` you must allow unprivileged user to bind to low port numbers:
> ```sh
> sudo sysctl net.ipv4.ip_unprivileged_port_start=53
> ```

> [!important]
> To use `podman` with their `aardvark` DNS resolver you must edit the CoreDNS ConfigMap to prefer UDP:
> ```diff
> $ kubectl --namespace edit configmap coredns
>
>   forward . ./etc/resolv.conf {
>     max_concurrent 1000
> +   prefer_udp
>   }
>
> $ kubectl --namespace rollout restart deployment coredns
> ```
>

```
kind create cluster --name compliantkubernetes --config docs/development/cluster.yaml
kind get kubeconfig --name compliantkubernetes > "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
kind get kubeconfig --name compliantkubernetes > "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

kubectl create namespace tigera-operator
kubectl create namespace seaweedfs-system
kubectl create namespace minio

kubectl label namespaces local-path-storage tigera-operator seaweedfs-system owner=operator --overwrite=true
kubectl label namespace minio owner=operator --overwrite=true

# kubectl -n seaweedfs-system apply -f ./docs/development/seaweedfs-credentials.yaml

helm --namespace tigera-operator install tigera ./docs/development/charts/projectcalico/tigera-operator-v3.26.4.tgz --wait
#helm --namespace seaweedfs-system install seaweedfs ./docs/development/charts/seaweedfs/seaweedfs-3.59.4.tgz --wait --values ./docs/development/seaweedfs.yaml

# Minio

helm -n minio upgrade --install minio ./docs/development/charts/minio/minio-5.0.14.tgz -f ./docs/development/charts/minio/values.yaml

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
> All deployments have been able to be removed with a plain `destroy`, except `hnc` which requires a second `destroy`.

Using the `baremetal` preset disable all reference to `rook-ceph` and set `standard` as the default storage class.

### Resolve and Ingress

> [!note]
> To be have properly signed certificates you must configure a DNS-01 solver for `cert-manager`.

To allow local access to service endpoints both `ingress-nginx` and `node-local-dns` will need to be setup with NodePorts.

Configuration additions for `ingress-nginx`:

```yaml
# common-config.yaml
ingressNginx:
  controller:
    service:
      enabled: true
      type: NodePort
      nodePorts:
        http: 30080
        https: 30443
```

Configuration additions for `node-local-dns`:

```yaml
# Replace these in the snippet below, {{ .Name }} should remain as it is.
DOMAIN: global.baseDomain
KIND_RESOLVE_IP: # matching the cluster IP of the kube-system/coredns service
KIND_INGRESS_IP: # matching the cluster IP of the ingress-nginx/controller service

# common-config.yaml
nodeLocalDns:
  customConfig: |-
    {{ DOMAIN }}:53 {
      errors
      bind 169.254.20.10 {{ KIND_RESOLVE_IP }}
      template IN A {{ DOMAIN }} {
        match "\.{{ DOMAIN | REPLACE "." WITH "\." }}\.$"
        answer "{{ .Name }} 60 IN A {{ KIND_INGRESS_IP }}"
        fallthrough
      }
      cache 30
      reload
      loop
      forward . 1.1.1.1 1.0.0.1
    }
    .:30053 {
      errors
      log
      template IN A {{ DOMAIN }} {
        match "\.{{ DOMAIN | REPLACE "." WITH "\." }}\.$"
        answer "{{ .Name }} 60 IN A 127.0.64.43"
        fallthrough
      }
      cache 30
      reload
      loop
      forward . 1.1.1.1 1.0.0.1
    }
```

Then when `node-local-dns` is deployed configure your network connection to use `127.0.64.43` as a resolver and you will be able to access the service endpoints using their domain names.
Note that this will make local resolve dependent on `node-local-dns`.

### Both Clusters

- `calico` via `apply --include-transitive-needs --selector app=calico`
  - Needs fix for felix metrics
  - Requires `clusterApi.enabled: true`
- `cert-manager` via `apply --include-transitive-needs --selector app=cert-manager`
- `falco` via `apply --include-transitive-needs --selector app=falco`
  - Will remain in error state as the pods need to be able to either load bpf or kernel module
- `gatekeeper` via `apply --include-transitive-needs --selector app=gatekeeper`
- `ingress-nginx` via `apply --include-transitive-needs --selector app=ingress-nginx`
- `kured` via `apply --include-transitive-needs --selector app=kured`
- `kube-prometheus-stack` via `apply --include-transitive-needs --selector app=prometheus`
- `node-local-dns` via `apply --include-transitive-needs --selector app=node-local-dns`
- `velero` via `apply --include-transitive-needs --selector app=velero`
  - Requires object storage

### Service Cluster

- `dex` via `apply --include-transitive-needs --selector app=dex`
  - Will not pull in `ingress-nginx`
- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Requires object storage
- `grafana` via `apply --include-transitive-needs --selector app=grafana`
  - Will not pull in `ingress-nginx` or `thanos`
- `harbor` via `apply --include-transitive-needs --selector app=harbor`
  - Will not pull in `ingress-nginx`
  - Requires object storage
  - Requires `persistence.disableRedirect: true` with internal S3
- `opensearch` via `apply --include-transitive-needs --selector app=opensearch`
  - Will not pull in `ingress-nginx`
  - Requires object storage
  - Uses significant amount of RAM
- `rclone-sync` via `apply --include-transitive-needs --selector app=rclone-sync`
  - Requires object storage
- `thanos` via `apply --include-transitive-needs --selector app=thanos`
  - Requires object storage

### Workload Cluster

- `fluentd` via `apply --include-transitive-needs --selector app=fluentd`
  - Requires a fix for dev-editable extra configmaps
  - Requires an edit for in-cluster opensearch endpoint (or potentially add that to sc fluentd)
- `hnc` via `apply --include-transitive-needs --selector app=hnc`

## Missing

### Audit

To be tested.

### Object Storage

Works with either `minio` or `seaweedfs`, TBD which one will be included.

Regardless we need to prepare for a better way to handle private S3 endpoints.

### Pull-through Registry Cache

Needs investigation as it is quite easy to hit pull limits.
