#!/usr/bin/env bats

# bats file_tags=general,chart-drift

# This tests check the charts for drift compared to upstream
# - If these tests fail with changes done to charts then that should be reverted, as we do not modify upstream charts.
# - If these tests fail without changes done to charts then that shows that the upstream is either unstable or compromised.

TESTS="$(dirname "$(dirname "${BATS_TEST_DIRNAME}")")"
ROOT="$(dirname "${TESTS}")"

setup_file() {
  "${ROOT}/scripts/charts.sh" repo add
  "${ROOT}/scripts/charts.sh" repo update
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

chart_verify() {
  run "${ROOT}/scripts/charts.sh" verify "${1}"
  assert_success
}

declare -a charts
readarray -t charts < <(yq '.charts | keys | .[]' "${ROOT}/helmfile.d/upstream/index.yaml")

declare chart
for chart in "${charts[@]}"; do
  bats_test_function --description "chart drift - upstream/${chart}" -- "chart_verify" "${chart}"
done
