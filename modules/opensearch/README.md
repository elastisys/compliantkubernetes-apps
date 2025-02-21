# OpenSearch module

- Does not support `opensearch.clientNode.dedicatedPods = false` or `opensearch.dataNode.dedicatedPods = false`

## Single cluster use

If you're using a local kind cluster and don't have access to another cluster while developing you can instead write the "remote" secrets and resources to the same cluster by creating secret like this:

```shell
kubectl -n crossplane-system create secret generic wc-kubeconfig \
    --from-literal=value="$(
        kind get kubeconfig --name <name> |
        sed 's|server:.*|server: https://kubernetes.default|'
    )"
```

Note however that the environment configurations have the same name and will therefore overwrite each other when only one cluster is used.
