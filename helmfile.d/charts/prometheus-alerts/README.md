# Prometheus-alerts

All Welkin alerts must have a severity label to dictate which priority the alert should have.
The different severity levels are:

- critical
- warning _or_ high
- medium
- low

All Welkin alerts must also have a group label.
If the alert does not fit into any specific group or should not be grouped together with other alerts, give the group label the same name as the alert.

## Deviations from the upstream alerts

1. In `fluentd.yaml` we set severity to warning and evaluation time to 10m for `FluentdRecordsCountsHigh`

## OpsGenie

If you want to group alerts for OpsGenie, set `.alerts.opsGenie.updateAlerts` to `true` and also `prometheus.alertmanagerSpec.groupBy` to `[group,severity,cluster]`.
By default no alerts are grouped.
