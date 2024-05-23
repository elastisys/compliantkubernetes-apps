#!/usr/bin/env bash

set -eo pipefail

for CLUSTER in sc wc; do
  echo "Applying the new prometheus-operator on $CLUSTER..."
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
  ./bin/ck8s ops kubectl $CLUSTER apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.50.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
done
