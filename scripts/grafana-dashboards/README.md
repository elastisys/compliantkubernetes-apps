# Grafana Dashboards updates script

## Description

The script will clone the upstream mixin repositories for the Grafana dashboards that we used from kube-prometheus-stack, apply some of our customization and create the dashboards.

## Structure

- `Makefile` - contains all the commands for creating the dashboards. The script will use the [helmfile.d/charts/grafana-dashboards/dashboards](https://github.com/elastisys/compliantkubernetes-apps/tree/main/helmfile.d/charts/grafana-dashboards/dashboards) as the destination for writing the new dashboards.
- `configs` - contains all the mixin configs, each folder name matching the upstream source repository.
    - [alertmanager-mixin](https://github.com/prometheus/alertmanager/tree/main/doc/alertmanager-mixin)
    - [etcd-mixin](https://github.com/etcd-io/etcd/tree/main/contrib/mixin)
    - [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin)
    - [node-mixin](https://github.com/prometheus/node_exporter/tree/master/docs/node-mixin)
    - [prometheus-mixin](https://github.com/prometheus/prometheus/tree/main/documentation/prometheus-mixin)
    - [thanos-mixin](https://github.com/thanos-io/thanos/tree/main/mixin)

In each of this directories you will find two files:

1. `dashboards.jsonnet` - used to re-name the output dashboards and make small changes to the json (e.g. set the timezone to "").
1. `mixin.libsonnet` - used to overwrite some of the upstream variables. The sources with all the options are linked inside the file.

## Commands

1. `make` or `make help` - will display a list of available commands.
1. `make dep` - will install the necessary dependencies (e.g jsonnet, jsonnet-bundler).
1. `make thanos-mixin` - will clone the upstream thanos-mixin repository and build the dashboards. Re-run is not currently supported, if you need to re-run a command remove the directory used for the clone `rm -rf ./thanos-mixin` first.
1. `make coredns-dashboards` - some dashboards do not have a mixin repository or the `.json` is already available. For them curl is used to download and write them to the correct destination.
1. `make clean` - remove the temporary local directories used to clone the upstream mixin repositories.
