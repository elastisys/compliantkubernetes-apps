#!/usr/bin/env bash

falco_event_generator_name="event-generator"
falco_event_generator_namespace="${falco_event_generator_name}"
falco_event_generator_repo="https://falcosecurity.github.io/charts"
falco_event_generator_chart="${falco_event_generator_name}"

# Usage: create_test_namespace <namespace>
create_test_namespace() {
  kubectl create ns "${1}" --dry-run=client -o yaml | kubectl apply -f -
}

# Usage: wait_test_namespace <namespace>
wait_test_namespace() {
  kubectl wait --for jsonpath='{.status.phase}'=Active namespace/"${1}"
  kubectl label ns "${1}" owner=operator
}

# Usage: delete_test_namespace <namespace>
delete_test_namespace() {
  kubectl delete ns "${1}" --wait=true
}

# Usage: create_test_application <namespace> <applicationRepo> <applicationChart> <applicationName>
create_test_application() {
  helm -n "${1}" upgrade --install --atomic --repo "${2}" "${3}" "${4}" \
    --set securityContext.runAsNonRoot=true \
    --set securityContext.runAsGroup=65534 \
    --set securityContext.runAsUser=65534 \
    --set podSecurityContext.fsGroup=65534 \
    --set config.actions=""
}

# Usage: delete_test_application <namespace> <applicationName>
delete_test_application() {
  helm -n "${1}" uninstall "${2}" --wait
}

setup_suite() {
  load "../../bats.lib.bash"

  echo -e "\033[1m[Deploy event-generator on wc]\033[0m Visit \"http://localhost:8000\" to authenticate into wc if the test gets stuck here for too long" >&3
  with_kubeconfig wc

  create_test_namespace "${falco_event_generator_namespace}"
  wait_test_namespace "${falco_event_generator_namespace}"

  create_test_application "${falco_event_generator_namespace}" "${falco_event_generator_repo}" "${falco_event_generator_chart}" "${falco_event_generator_name}"

  echo -e "\033[1m[Setup kube proxy on sc]\033[0m Visit \"http://localhost:8000\" to authenticate into sc if the test gets stuck here for too long" >&3
  with_kubeconfig sc
  "../scripts/kubeproxy-wrapper.sh" >/dev/null 2>&1 &
}

teardown_suite() {
  with_kubeconfig wc

  delete_test_application "${falco_event_generator_namespace}" "${falco_event_generator_name}"
  delete_test_namespace "${falco_event_generator_namespace}"

  pkill -f "bash ../scripts/kubeproxy-wrapper.sh"
}
