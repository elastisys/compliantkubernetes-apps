# Modules

Publish a configuration package:

```shell
./hack/push-package.bash metrics-server v0.0.1
```

Verify that there are no diffs between the existing release and the module payload:

```shell
helmfile -f ../helmfile.d -e service_cluster template --selector app=metrics-server |
    crossplane render /dev/stdin ./metrics-server/apis/composition.yaml ./hack/functions.yaml |
    yq4 'select(.kind == "Release")' |
    ./hack/crossplane-helm.bash diff metrics-server /dev/stdin
```
