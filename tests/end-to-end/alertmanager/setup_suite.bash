#!/usr/bin/env bash

setup_suite() {
  load "../../bats.lib.bash"
  load_common "proxy.bash"

  with_kubeconfig sc
  proxy.start_proxy sc

  with_static_wc_kubeconfig
  proxy.start_proxy wc
}

teardown_suite() {
  proxy.stop_all
}
