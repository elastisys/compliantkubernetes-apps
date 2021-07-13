# calico-felix-metrics

This helm chart deploys `calico-felix-metrics`, an application that gathers metrics about the general health of Calico.

## Prerequisites

This chart assumes that [calico metrics are enabled](https://docs.projectcalico.org/maintenance/monitor/monitor-component-metrics).
Use the below commands to check if the metrics are enabled:
```
kubectl get po --selector=k8s-app=calico-node -o=jsonpath='{range .items[*]}{.metadata.annotations.prometheus\.io/scrape=="true"}{.metadata.name}{"\n"}{end}' -n kube-system

kubectl port-forward service/calico-felix-metrics-svc -n kube-system 9091:9091
```
## Deployment

To deploy this helm chart use:
```
./bin/ck8s ops helmfile <cluster> -f helmfile -l app=calico-felix-metrics apply
```
