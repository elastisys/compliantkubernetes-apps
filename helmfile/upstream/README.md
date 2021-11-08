# Upstream maintained Charts

## Example on how to add or update a Chart:

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo up
helm fetch falcosecurity/falco --version 1.5.2 --untar
```

## To consider when upgrading a chart

### starboard-operator
1. The Starboard Operator currently uses a subchart containing a PSP to allow the Trivy scanners to run and the RBAC to use it. Keep it until it is supported upstream.

### kube-prometheus-stack
1. Some alerts rules (e.g alert manager) are kept and maintained separately in [prometheus-alerts chart](helmfile/charts/prometheus-alerts/)
1. The Prometheus wc reader need to be updated separately in [prometheus-instance chart](helmfile/charts/prometheus-instance/)
1. The user Grafana needs to be updated separately in [grafana chart](helmfile/upstream/grafana)
1. The user AlertManager needs to be updated separately in [user-alertmanager chart](helmfile/charts/examples/user-alertmanager)
