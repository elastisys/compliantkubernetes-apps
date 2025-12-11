#!/usr/bin/env bats

# bats file_tags=releases,general,prometheus

setup_file() {
  # for dynamically registering tests using `bats_test_function`
  bats_require_minimum_version 1.11.1

  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init openstack capi dev
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_common "yq.bash"
  load_common "env.bash"
  env.private
}

teardown_file() {
  env.teardown
  gpg.teardown
}

declare -a clusters=("service" "workload")

for cluster in "${clusters[@]}"; do
  bats_test_function \
    --description "check ${cluster} cluster alerting rules" \
    -- check_alerting_rules "${cluster}"
done

check_alerting_rules() {
  local -r cluster="${1}_cluster"

  run --separate-stderr bats_pipe \
    helmfile -f "${ROOT}/helmfile.d" -e "${cluster}" -l app=prometheus -l chart=charts/prometheus-alerts template --log-level error \
    \| yq eval-all '[select(.kind == "PrometheusRule") | .spec.groups[]] | {"groups": .}' \
    \| promtool check rules --no-lint-fatal /dev/stdin

  assert_success
}
