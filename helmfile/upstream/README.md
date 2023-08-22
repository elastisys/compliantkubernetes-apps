# Upstream Charts

Charts are managed with the file `index.yaml` and the script `charts.sh`.

> [!NOTE] Most functions relies on the repositories being added and updated in helm:
>
> ```bash
> ./scripts/charts.sh repo add
> ./scripts/charts.sh repo update
> ```

## Adding charts

Add the repository in the index:

```diff
  repositories:

+   <repository-name>: <repository-url>
```

Add the chart in the index:

```diff
  charts:

+   <repository-name>/<chart-name>: <chart-version>
```

Pull the chart:

```bash
./scripts/charts.sh pull <chart-name>
```

> [!NOTE] To use an upstream chart ensure that:
>
> 1. the state file contains `./bases/upstream.yaml` as a base to include the upstream index, and
> 2. the release spec contains `inherit: [ template: <chart-name> ]` to include the chart template.

## Updating charts

Update the chart in the index:

```diff
  charts:

-   <repository-name>/<chart-name>: <old-chart-version>
+   <repository-name>/<chart-name>: <new-chart-version>
```

Pull the chart:

```bash
./scripts/charts.sh pull <chart-name>
```

## Other functions

Check for chart changes:

```bash
./scripts/charts.sh diff all|<chart> all|chart|crds|readme|values <version>
```

Check for chart updates:

```bash
./scripts/charts.sh list all|<chart>
```

Check for chart verification:

```bash
./scripts/charts.sh verify all|<chart>
```

## To consider when upgrading a chart

### kube-prometheus-stack
1. All rules are split between alerts and records, modified to preserve the cluster label in aggregations, and maintained separately in [prometheus-alerts chart](helmfile/charts/prometheus-alerts/)
1. The user Grafana needs to be updated separately in [grafana chart](helmfile/upstream/grafana)
1. The user AlertManager needs to be updated separately in [user-alertmanager chart](helmfile/charts/examples/user-alertmanager)
