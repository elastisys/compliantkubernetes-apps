# Grafana-dashboards

The Rook/Ceph dashboards were found through [this page](https://rook.io/docs/rook/v1.6/ceph-monitoring.html).

- Ceph cluster: https://grafana.com/dashboards/2842
- Ceph OSD (Single): https://grafana.com/dashboards/5336 (fixed bug in this where "osd.0" should be "$osd" in a few places)
- Ceph pools: https://grafana.com/dashboards/5342

The Ingress nginx dashboard was likely found through [this page](https://grafana.com/grafana/dashboards/16677-ingress-nginx-overview/). It has at least been altered to work with `honorLabels` in the servicemonitor, i.e. when the `namespace` label points to the ingress namespace instead of the controller namespace.

The Grafana dashboards for general Kubernetes metrics were found on [this page](https://github.com/dotdc/grafana-dashboards-kubernetes).
