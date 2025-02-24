# capability-log-write

Render locally:

```bash
crossplane render examples/xr.yaml apis/composition.yaml examples/functions.yaml -e examples/receivers.yaml
```

Apply manually:

```bash
kubectl apply -f apis

kubectl create secret generic foo --dry-run=client -o yaml |
    kubectl label -f - logwrites.capabilities.elastisys.com="" --local -o yaml |
    kubectl apply -f -

kubectl apply -f examples/xr.yaml
```
