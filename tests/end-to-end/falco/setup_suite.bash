#!/usr/bin/env bash

# Usage: create_test_namespace <namespace>
create_test_namespace() {
  kubectl create ns "${1}"
}

# Usage: wait_test_namespace <namespace>
wait_test_namespace() {
  kubectl wait --for jsonpath='{.status.phase}'=Active namespace/"${1}"
  kubectl label ns "${1}" owner=operator
}

# Usage: delete_test_namespace <namespace>
delete_test_namespace() {
  kubectl delete ns "${1}"
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

  export EVENT_GENERATOR_NAME="event-generator"
  export EVENT_GENERATOR_NAMESPACE="event-generator"
  export EVENT_GENERATOR_REPO="https://falcosecurity.github.io/charts"
  export EVENT_GENERATOR_CHART="event-generator"

  echo -e "\033[1m[Deploy event-generator on wc]\033[0m Visit \"http://localhost:8000\" to authenticate into wc if the test gets stuck here for too long" >&3
  with_kubeconfig wc

  create_test_namespace "${EVENT_GENERATOR_NAMESPACE}"
  wait_test_namespace "${EVENT_GENERATOR_NAMESPACE}"

  create_test_application "${EVENT_GENERATOR_NAMESPACE}" "${EVENT_GENERATOR_REPO}" "${EVENT_GENERATOR_CHART}" "${EVENT_GENERATOR_NAME}"

  echo -e "\033[1m[Setup kube proxy on sc]\033[0m Visit \"http://localhost:8000\" to authenticate into sc if the test gets stuck here for too long" >&3
  with_kubeconfig sc
  "../scripts/kubeproxy-wrapper.sh" >/dev/null 2>&1 &

}

teardown_suite() {

  with_kubeconfig wc

  delete_test_application "${EVENT_GENERATOR_NAMESPACE}" "${EVENT_GENERATOR_NAME}"
  delete_test_namespace "${EVENT_GENERATOR_NAMESPACE}"

  pkill -f "bash ../scripts/kubeproxy-wrapper.sh"
}
