#!/usr/bin/env bash

falco_event_generator_name="event-generator"
falco_event_generator_namespace="${falco_event_generator_name}"
falco_event_generator_repo="https://falcosecurity.github.io/charts"
falco_event_generator_chart="${falco_event_generator_name}"
falco_event_generator_version="0.3.4"

# Usage: label_test_namespace <namespace>
label_test_namespace() {
  kubectl label ns "${1}" owner=operator
}

# Usage: create_test_application <namespace>
create_test_application() {
  helm -n "${1}" upgrade --install --atomic \
    --repo "${falco_event_generator_repo}" \
    "${falco_event_generator_chart}" "${falco_event_generator_name}" \
    --version "${falco_event_generator_version}" \
    --set securityContext.runAsNonRoot=true \
    --set securityContext.runAsGroup=65534 \
    --set securityContext.runAsUser=65534 \
    --set podSecurityContext.fsGroup=65534 \
    --set config.actions=""
}

# Usage: delete_test_application <namespace>
delete_test_application() {
  helm -n "${1}" uninstall "${falco_event_generator_name}" --wait
}

setup_suite() {
  load "../../bats.lib.bash"

  with_namespace "${falco_event_generator_namespace}"

  echo -e "\033[1m[Deploying event-generator on WC]\033[0m" >&3
  with_kubeconfig wc

  create_namespace
  label_test_namespace "${falco_event_generator_namespace}"

  create_test_application "${falco_event_generator_namespace}"

  echo -e "\033[1m[Starting kube proxy on SC]\033[0m" >&3
  with_kubeconfig sc
  "../scripts/kubeproxy-wrapper.sh" >/dev/null 2>&1 3>&- &
}

teardown_suite() {
  with_kubeconfig wc

  echo -e "\033[1m[Deleting event-generator from WC]\033[0m" >&3
  delete_test_application "${falco_event_generator_namespace}"
  delete_namespace

  echo -e "\033[1m[Stopping kube proxy on SC]\033[0m" >&3
  pkill -f "bash ../scripts/kubeproxy-wrapper.sh"
}
