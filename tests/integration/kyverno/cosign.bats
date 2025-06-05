#!/usr/bin/env bats
#
# Test only validation, not signing and such

setup_file() {
  # Configure to use Cosign

  load "../../bats.lib.bash"
  load_common "yq.bash"

  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Cosign"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  yq.set wc '.kyverno.policies.verifyImageSignature.attestors' \
'"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEoL0XMcv0rXFo41ZDoVJHzHaelPn9
EZIWF76W/2/z5DCrHWSetz8FjJjvUq5Niw7JxfQRyZte+VISWcLcsUUfnA==
-----END PUBLIC KEY-----
"'

  kubectl create namespace securespace
  kubectl label namespace securespace hnc.x-k8s.io/included-namespace=true

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  kubectl delete namespace securespace
}

@test "signed image allowed" {
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/test-verify-image:signed
  assert_success
}

@test "an unsigned image can't run" {
  run kubectl run test-unsigned --namespace=securespace --image=ghcr.io/elastisys/curl-jq:1.0.0 sleep 0
  assert_failure
# TODO assert output --partial="what does it say here?"
}

# TODO @test "multiple keys requires multiple signatures" {}
# TODO @test "signed by untrusted key" {}
# TODO @test "signed both trusted and untrusted key?" {}
# TODO @test "deployment?" {}

@test "unsigned in some namespace where it is disabled" {
  run kubectl run test-unsigned --namespace=default --image=ghcr.io/elastisys/curl-jq:1.0.0 sleep 0
  assert_success
}
