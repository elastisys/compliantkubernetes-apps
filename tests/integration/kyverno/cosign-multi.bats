#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"
  load_common "yq.bash"

  log.trace "Configuring for Cosign"
  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Cosign"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  yq.set wc '.kyverno.policies.verifyImageSignature.attestors' \
    '"-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEoL0XMcv0rXFo41ZDoVJHzHaelPn9
EZIWF76W/2/z5DCrHWSetz8FjJjvUq5Niw7JxfQRyZte+VISWcLcsUUfnA==
-----END PUBLIC KEY-----
-----BEGIN PUBLIC KEY-----
TODO GENERATE THIS KEY
-----END PUBLIC KEY-----
"'
# TODO generate 2 extra keys, one trusted, one untrusted
# Alice - trusted
# Bob - trusted
# Carol - not trusted

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
: TODO create pod image=A
}

@test "can NOT deploy image signed by only one _trusted_ key" {
: TODO create pod image=AC
}

@test "CAN deploy image signed by only two keys" {
: TODO create pod image=AB
}
