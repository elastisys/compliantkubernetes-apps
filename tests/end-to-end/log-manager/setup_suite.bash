#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"

  with_kubeconfig sc
  with_namespace fluentd-system

  # Pause logs being flushed to object storage
  fluentd_aggregator_replicas="$(kubectl -n "${NAMESPACE}" get statefulset fluentd-aggregator -o jsonpath='{.spec.replicas}')"
  kubectl -n "${NAMESPACE}" scale statefulset fluentd-aggregator --replicas 0 --timeout 5m
}

teardown_suite() {
  load "../../bats.lib.bash"

  # Unpause logs being flushed to object storage
  kubectl -n "${NAMESPACE}" scale statefulset fluentd-aggregator --replicas "${fluentd_aggregator_replicas}" --timeout 5m
}
