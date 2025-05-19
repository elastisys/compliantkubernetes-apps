#!/usr/bin/env bats
#
# Test only validation, not signing and such

setup_file() {
  # Configure to use Notary

  load "../../bats.lib.bash"
  load_common "yq.bash"

  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Notary"'
  yq.set wc '.kyverno.policies.verifyImageSignature.publicKeys' \
'"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
-----END PUBLIC KEY-----
"'

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load_assert
}

@test "ensure signature validation enforced" {
  # an unsigned image is forbidden
  run kubectl run test-unsigned --image=docker.io/library/hello-world
  assert_failure
  # TODO assert output

  run kubectl run test-signed --image=ghcr.io/kyverno/test-verify-image:signed
  assert_success
  # a signed image is allowed
}

# TODO @test "multiple keys requires multiple signatures" {}
# TODO @test "signed by untrusted key" {}
# TODO @test "signed both trusted and untrusted key?" {}
# TODO @test "deployment?" {}
# TODO @test "unsigned in some namespace where it is disabled" {}
