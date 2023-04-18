# README

Currently only includes metrics for Cluster API. This chart adds a ConfigMap with additional config for the [kube-state-metrics](../../upstream/kube-prometheus-stack/chart/kube-state-metrics) chart, which is part of `kube-prometheus-stack`.

The [clusterapi-metrics.yaml](files/clusterapi-metrics.yaml) file was found through [this page](https://github.com/kubernetes-sigs/cluster-api/blob/v1.4.1/hack/observability/kube-state-metrics/crd-config.yaml).
