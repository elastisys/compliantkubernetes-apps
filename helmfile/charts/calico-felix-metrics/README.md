# calico-felix-metrics

This helm chart deploys `calico-felix-metrics`, an application that gathers metrics about the general health of Calico.

To deploy this helm chart use:
```
./bin/ck8s ops helmfile <cluster> -f helmfile -l app=calico-felix-metrics apply
```
