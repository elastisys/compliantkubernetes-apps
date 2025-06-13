#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"
  load_common "yq.bash"

  log.trace "Configuring for Cosign"
  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Cosign"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  # Key a and key b
  yq.set wc '.kyverno.policies.verifyImageSignature.attestors' \
    '"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIHjN39hDmjvcpwNviJCdrhPozIKX
lfk+eUg2z5b8uhtDJtdDGkeRF+5Bg1LUBDtvsrHbmck2xEe1psIlvaWRyw==
-----END PUBLIC KEY-----
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9FNunqYEBqQzz5FWwn1wAUyvCHbl
BFatuG15LRQ/uxaXazZIYFOSQPvqW716qx4xWXEoKmkFMvkzzuapPgwzgA==
-----END PUBLIC KEY-----
"'

  kubectl create namespace unverifiedspace
  kubectl create namespace securespace
  kubectl label namespace securespace hnc.x-k8s.io/included-namespace=true

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  kubectl delete namespace unverifiedspace securespace
}

teardown() {
  kubectl delete deployment --namespace=unverifiedspace --all
  kubectl delete pod --namespace=unverifiedspace --all
  kubectl delete deployment --namespace=securespace --all
  kubectl delete pod --namespace=securespace --all
}

@test "can NOT deploy image signed by only one key" {
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:a
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}

@test "CAN deploy image signed by two keys" {
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:a-b
  assert_success
}

@test "can NOT deploy image signed by one trusted key and one untrusted key" {
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:a-c
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}
