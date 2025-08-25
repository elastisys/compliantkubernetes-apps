#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"

  with_kubeconfig sc
  with_namespace fluentd-system

  # Temporarily allow all traffic to not cause dropped packets and fail the Network Policy test suite.
  if kubectl get crd globalnetworkpolicies.crd.projectcalico.org; then
    kubectl apply -f "${BATS_CWD}/end-to-end/log-manager/resources/calico-allow-all.yaml" >&3 2>&1
    # Give the CNI a bit of time to settle (arbitrary, I know..)
    sleep 15
  fi

  # Both Prometheus and the blackbox exporter will attempt to reach inexisting pods if they aren't
  # scaled down, causing dropped packets and failing the Network Policy test suite.
  # -> downscale prometheus and its blackbox exporter
  blackbox_exporter_replicas="$(scale_down monitoring deployment/prometheus-blackbox-exporter)"
  prom="kube-prometheus-stack-prometheus"
  kubectl patch prometheus "${prom}" -n monitoring --type='merge' --patch='{"spec": {"paused": true}}'
  scale_down monitoring "sts/prometheus-${prom}"

  # Pause logs being flushed to object storage.
  # -> remove output configuration from forwarders, otherwise they'll try to reach the inexisting
  # aggregator pods
  mkdir -p "${BATS_SUITE_TMPDIR}"
  kubectl -n "${NAMESPACE}" get configmap fluentd-forwarder -o yaml >"${BATS_SUITE_TMPDIR}/fluentd-forwarder-cm.yaml"
  kubectl -n "${NAMESPACE}" patch configmap fluentd-forwarder --type json \
    --patch="[{\"op\": \"remove\", \"path\": \"/data/30-output.conf\"}]" >&3 2>&1 || true
  rollout_forwarder

  # -> downscale the aggregator to 0
  fluentd_aggregator_replicas="$(scale_down "${NAMESPACE}" statefulset/fluentd-aggregator)"
}

teardown_suite() {
  load "../../bats.lib.bash"

  # Unpause logs being flushed to object storage:
  # -> scale the aggregator back up
  kubectl -n "${NAMESPACE}" scale statefulset fluentd-aggregator --replicas "${fluentd_aggregator_replicas}" --timeout 5m
  kubectl -n "${NAMESPACE}" wait --for=condition=ready pod -l app=aggregator --timeout 5m
  echo 'pod/app=aggregator ready' >&3

  # -> restore the forwarder output config
  kubectl -n "${NAMESPACE}" replace --force -f "${BATS_SUITE_TMPDIR}/fluentd-forwarder-cm.yaml" >&3 2>&1
  rollout_forwarder

  # -> scale monitoring back up
  scale_up monitoring deployment/prometheus-blackbox-exporter "${blackbox_exporter_replicas}"
  kubectl -n monitoring patch prometheus "${prom}" --type='merge' --patch='{"spec": {"paused":false}}'
  kubectl -n monitoring wait --for=jsonpath='{.subsets[*].addresses[*].ip}' endpoints "${prom}"

  # Delete the allow-all policy
  if kubectl get crd globalnetworkpolicies.crd.projectcalico.org; then
    kubectl delete -f "${BATS_CWD}/end-to-end/log-manager/resources/calico-allow-all.yaml" --ignore-not-found >&3 2>&1
  fi
}

scale_down() {
  local -r ns="${1}"
  local -r object="${2}"
  kubectl -n "${ns}" get "${object}" -o jsonpath='{.spec.replicas}'
  kubectl -n "${ns}" scale "${object}" --replicas 0 --timeout 5m >&3 2>&1
}

scale_up() {
  local -r ns="${1}"
  local -r object="${2}"
  local -r replicas="${3}"
  kubectl -n "${ns}" scale "${object}" --replicas "${replicas}" --timeout 5m >&3 2>&1
}

rollout_forwarder() {
  kubectl -n "${NAMESPACE}" rollout restart daemonset/fluentd-forwarder
  kubectl -n "${NAMESPACE}" rollout status daemonset/fluentd-forwarder --timeout 5m
  echo 'statefulset/fluentd-forwarder rolled out' >&3
}
