# calico-felix-metrics

This helm chart deploys `calico-felix-metrics`, an application that gathers metrics about NetworkPolicies.

To deploy this helm chart use:
```
./bin/ck8s ops helmfile <cluster> -f helmfile -l app=calico-felix-metrics apply
```
