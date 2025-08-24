#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"

  with_kubeconfig sc
  with_namespace fluentd-system

  # Temporarily allow all traffic
  if kubectl get crd globalnetworkpolicies.crd.projectcalico.org; then
    kubectl apply -f "${BATS_CWD}/end-to-end/log-manager/resources/calico-allow-all.yaml" >&3 2>&1
    # Give the CNI a bit of time to settle (arbitrary, I know..)
    sleep 15
  fi

  kctl="kubectl -n ${NAMESPACE}"

  # -> downscale monitoring the blackbox exporter to 0
  blackbox_exporter_replicas="$(scale_down monitoring deployment/prometheus-blackbox-exporter)"
  prom="kube-prometheus-stack-prometheus"
  kubectl patch prometheus "${prom}" -n monitoring --type='merge' --patch='{"spec": {"paused": true}}'
  scale_down monitoring "sts/prometheus-${prom}"

  # Pause logs being flushed to object storage:
  # -> remove output config from forwarders, otherwise they'll try to reach inexisting pods
  mkdir -p "${BATS_SUITE_TMPDIR}"
  $kctl get configmap fluentd-forwarder -o yaml >"${BATS_SUITE_TMPDIR}/fluentd-forwarder-cm.yaml"
  $kctl patch configmap fluentd-forwarder --type json \
    --patch="[{\"op\": \"remove\", \"path\": \"/data/30-output.conf\"}]" >&3 2>&1 || true
  rollout_forwarder

  # -> downscale the aggregator to 0
  fluentd_aggregator_replicas="$(scale_down "${NAMESPACE}" statefulset/fluentd-aggregator)"
}

teardown_suite() {
  load "../../bats.lib.bash"

  # Unpause logs being flushed to object storage:
  # -> scale the aggregator back up
  $kctl scale statefulset fluentd-aggregator --replicas "${fluentd_aggregator_replicas}" --timeout 5m
  $kctl wait --for=condition=ready pod -l app=aggregator --timeout 5m
  echo 'pod/app=aggregator ready' >&3

  # -> restore the forwarder output config
  $kctl replace --force -f "${BATS_SUITE_TMPDIR}/fluentd-forwarder-cm.yaml" >&3 2>&1
  rollout_forwarder

  # -> scale monitoring back up
  scale_up monitoring deployment/prometheus-blackbox-exporter "${blackbox_exporter_replicas}"
  kubectl -n monitoring patch prometheus "${prom}" --type='merge' --patch='{"spec": {"paused":false}}'
  kubectl -n monitoring wait --for=jsonpath='{.subsets[*].addresses[*].ip}' endpoints "${prom}"

  # Delete allow-all policy
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
  $kctl rollout restart daemonset/fluentd-forwarder
  $kctl rollout status daemonset/fluentd-forwarder --timeout 5m
  echo 'statefulset/fluentd-forwarder rolled out' >&3
}
