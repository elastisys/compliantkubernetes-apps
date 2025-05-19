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
  yq.set wc '.kyverno.policies.verifyImageSignature.publicKeys' \
'"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
-----END PUBLIC KEY-----
"'

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "signed image allowed" {
  run kubectl run test-signed --image=ghcr.io/kyverno/test-verify-image:signed
  assert_success
  # a signed image is allowed
}

@test "an unsigned image can't run" {
  # an unsigned image is forbidden
  # TODO push an unsigned image to ghcr
  run kubectl run test-unsigned --image=ghcr.io/elastisys/curl-jq:1.0.0 sleep 0
  assert_failure
  # TODO assert output
}

# TODO @test "multiple keys requires multiple signatures" {}
# TODO @test "signed by untrusted key" {}
# TODO @test "signed both trusted and untrusted key?" {}
# TODO @test "deployment?" {}
# TODO @test "unsigned in some namespace where it is disabled" {}
