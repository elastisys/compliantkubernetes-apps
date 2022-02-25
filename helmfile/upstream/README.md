# Upstream maintained Charts

## Example on how to add or update a Chart:

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo up
helm fetch falcosecurity/falco --version 1.5.2 --untar
```

## To consider when upgrading a chart

### starboard-operator
1. The Starboard Operator currently contains a subchart containing a PSP to allow the Trivy scanners to run and the RBAC to use it.
   Keep it until we don't use PSP admission controller anymore.

### kube-prometheus-stack
1. All rules are split between alerts and records, modified to preserve the cluster label in aggregations, and maintained separately in [prometheus-alerts chart](helmfile/charts/prometheus-alerts/)
1. The user Grafana needs to be updated separately in [grafana chart](helmfile/upstream/grafana)
1. The user AlertManager needs to be updated separately in [user-alertmanager chart](helmfile/charts/examples/user-alertmanager)
