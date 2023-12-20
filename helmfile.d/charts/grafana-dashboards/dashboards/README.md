# README

The Rook/Ceph dashboards were found through [this page](https://rook.io/docs/rook/v1.6/ceph-monitoring.html).

- Ceph cluster: https://grafana.com/dashboards/2842
- Ceph OSD (Single): https://grafana.com/dashboards/5336
- Ceph pools: https://grafana.com/dashboards/5342

The Thanos dashboards are from [this page](https://github.com/thanos-io/thanos/tree/main/mixin)
To generate the Thanos dashboards execute the following commands from this directory:

1. Install the necessary tools

```bash
make tools_install
```

1. Install Thanos mixin

```bash
make thanos_install
```

1. Create the dashboards

```bash
make thanos_dashboards
```

1. Clean

```bash
make clean
```
