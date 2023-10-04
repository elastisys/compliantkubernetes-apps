#!/usr/bin/env bats

setup() {
  load "../common/lib"

  common_setup
}

grafana_sc_dashboard_logs() {
  kubectl -n monitoring logs "deployment/${1}" grafana-sc-dashboard | sed -rn 's#\{"time": ".+", "msg": "Writing /tmp/dashboards/(.+) \(ascii\)", "level": "INFO"\}#- \1#p' | sort -u
}

grafana_logs() {
    kubectl -n monitoring logs "deployment/${1}" grafana | grep 'level=error' | sed -rn 's#.*dashboards/(.+) error="(.+)"#error: \1: \2#p' | sort -u
}

@test "grafana admin dashboard discovery" {
  with_kubeconfig "sc"

  run grafana_sc_dashboard_logs ops-grafana

  while read -r line; do
    assert_line "${line}"
  done < "${ROOT}/tests/end-to-end/grafana-dashboards-admin.yaml"
}

@test "grafana dev dashboard discovery" {
  with_kubeconfig "sc"

  run grafana_sc_dashboard_logs user-grafana

  while read -r line; do
    assert_line "${line}"
  done < "${ROOT}/tests/end-to-end/grafana-dashboards-dev.yaml"
}

@test "grafana admin dashboard load without error" {
  with_kubeconfig "sc"

  run grafana_logs ops-grafana

  refute_output
}


@test "grafana dev dashboard load without error" {
  with_kubeconfig "sc"

  run grafana_logs user-grafana

  refute_output
}
