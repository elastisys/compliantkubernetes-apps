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
  # TODO # yq.set wc '.kyverno.policies.verifyImageSignature.publicKeys' '"-----BEGIN"'

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load_assert
}

@test "ensure signature validation enforced" {
  # an unsigned image is forbidden
  run kubectl run test-unsigned --image=harbor.long-running.dev-ck8s.com/kyverno-tests/unsigned
  assert_failure
  # TODO assert output

  run kubectl run test-signed --image=harbor.long-running.dev-ck8s.com/kyverno-tests/notary-signed
  assert_success
  # a signed image is allowed
}

# TODO @test "multiple keys requires multiple signatures" {}
# TODO @test "signed by untrusted key" {}
# TODO @test "signed both trusted and untrusted key?" {}
# TODO @test "deployment?" {}
# TODO @test "unsigned in some namespace where it is disabled" {}
