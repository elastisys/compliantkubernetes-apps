#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"
  load_common "yq.bash"

  log.trace "Configuring for Cosign"
  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Cosign"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  yq.set wc '.kyverno.policies.verifyImageSignature.attestor' \
    '"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIHjN39hDmjvcpwNviJCdrhPozIKX
lfk+eUg2z5b8uhtDJtdDGkeRF+5Bg1LUBDtvsrHbmck2xEe1psIlvaWRyw==
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

@test "CAN deploy a pod with a signed image" {
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:cosign-a
  assert_success
}

@test "can NOT deploy a pod with an unsigned image" {
  run kubectl run test-unsigned --namespace=securespace --image=ghcr.io/elastisys/curl-jq:1.0.0 sleep 0
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}

@test "CAN deploy an unsigned image in namespace where verification is not enabled" {
  run kubectl run test-unsigned --namespace=unverifiedspace --image=ghcr.io/elastisys/curl-jq:1.0.0 sleep 0
  assert_success
}

@test "CAN deploy a deployment with a signed image" {
  run kubectl create deployment secure-deploy --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:cosign-a
  assert_success
}

@test "can NOT deploy a deployment with an unsigned image" {
  run kubectl create deployment test-unsigned --namespace=securespace --image=ghcr.io/elastisys/curl-jq:1.0.0
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}

@test "can NOT change a deployment to an unsigned image" {
  run kubectl create deployment secure-deploy --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:cosign-a
  assert_success

  run kubectl set image deployment secure-deploy --namespace=securespace secure-deploy=ghcr.io/elastisys/curl-jq:1.0.0
  assert_failure
}

@test "can NOT run image signed by untrusted key" {
  run kubectl create deployment test-unsigned --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:cosign-c
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}
