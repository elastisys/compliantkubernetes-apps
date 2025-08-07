#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"
  load_assert
}

grafana_sc_dashboard_logs() {
  kubectl -n monitoring logs "deployment/${1}" -c grafana-sc-dashboard | grep '^{.*}$' | jq -r '.msg | select(match("^Writing")) | sub("^Writing /tmp/dashboards/"; "") | sub(" .*"; "")'
}

grafana_logs() {
  kubectl -n monitoring logs "deployment/${1}" -c grafana | grep 'level=error' | grep 'failed to load dashboard'
}

@test "grafana admin can discover dashboards" {
  with_kubeconfig "sc"

  readarray -t dashboards < <(helmfile -e service_cluster -f "${ROOT}/helmfile.d" -l name=grafana-dashboards template | yq -N 'select(.kind == "ConfigMap") | .data | keys | .[]')

  run grafana_sc_dashboard_logs ops-grafana

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

  readarray -t dashboards < <(helmfile -e service_cluster -f "${ROOT}/helmfile.d" -l name=grafana-dashboards template | yq -N 'select(.kind == "ConfigMap" and .metadata.labels.grafana_dashboard == "1") | .data | keys | .[]')

  run grafana_sc_dashboard_logs user-grafana

  for dashboard in "${dashboards[@]}"; do
    assert_line "${dashboard}"
  done
}

@test "grafana dev can load dashboards without error" {
  with_kubeconfig "sc"

  run grafana_logs user-grafana

  refute_output
}
