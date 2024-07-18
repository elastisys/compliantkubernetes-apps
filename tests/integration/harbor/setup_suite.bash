#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"

  auto_setup sc app=cert-manager app=dex app=harbor app=ingress-nginx app=node-local-dns
}

teardown_suite() {
  load "../../bats.lib.bash"

  auto_teardown
}

setup_harbor() {
  ck8s ops helmfile sc apply --include-transitive-needs --output simple -lapp=harbor
}

teardown_harbor() {
  ck8s ops helmfile sc destroy -lapp=harbor

  ck8s ops kubectl sc delete pvc -n harbor --all
}
