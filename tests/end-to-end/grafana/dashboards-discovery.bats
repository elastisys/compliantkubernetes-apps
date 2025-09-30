#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"
  load_common "grafana.bash"
  load_common "yq.bash"
  load_assert
}

grafana_logs() {
  kubectl -n monitoring logs "deployment/${1}" -c grafana | grep 'level=error' | grep 'failed to load dashboard'
}

grafana_dashboards() {
  grafana.get_dashboards | jq -r '.items[].metadata.annotations."grafana.app/sourcePath" | sub("^/tmp/dashboards/"; "")'
}

@test "grafana admin can discover dashboards" {
  with_kubeconfig "sc"
  grafana.load_env "ops"

  readarray -t dashboards < <(helmfile -e service_cluster -f "${ROOT}/helmfile.d" -l name=grafana-dashboards template | yq -N 'select(.kind == "ConfigMap") | .data | keys | .[]')

  run grafana_dashboards

  for dashboard in "${dashboards[@]}"; do
    assert_line "${dashboard}"
  done
}

@test "grafana admin can load dashboards without error" {
  with_kubeconfig "sc"

  run grafana_logs ops-grafana

  refute_output
}

@test "grafana dev can discover dashboards" {
  with_kubeconfig "sc"
  grafana.load_env "user"

  readarray -t dashboards < <(helmfile -e service_cluster -f "${ROOT}/helmfile.d" -l name=grafana-dashboards template | yq -N 'select(.kind == "ConfigMap" and .metadata.labels.grafana_dashboard == "1") | .data | keys | .[]')

  run grafana_dashboards

  for dashboard in "${dashboards[@]}"; do
    assert_line "${dashboard}"
  done
}

@test "grafana dev can load dashboards without error" {
  with_kubeconfig "sc"

  run grafana_logs user-grafana

  refute_output
}
