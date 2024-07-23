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
  log.trace "setup harbor"

  # reloading ingresses might make ingress-nginx unavailable
  ck8s ops kubectl sc wait pod -n ingress-nginx -lapp.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --for condition=Ready --timeout 60s

  ck8s ops helmfile sc apply -lapp=harbor --output simple --wait

  ck8s ops kubectl sc wait pod -n harbor -lapp=harbor --for condition=Ready --timeout 60s

  # reloading ingresses might make ingress-nginx unavailable
  ck8s ops kubectl sc wait pod -n ingress-nginx -lapp.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --for condition=Ready --timeout 60s
}

teardown_harbor() {
  log.trace "teardown harbor"

  ck8s ops helmfile sc destroy -lapp=harbor --deleteWait

  ck8s ops kubectl sc delete pvc -n harbor --all
  ck8s ops kubectl sc delete po -n harbor --all
}
