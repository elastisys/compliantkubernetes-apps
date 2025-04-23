#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"
  load_common "yq.bash"

  log.trace "Configuring for Notary"
  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Notary"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  yq.set wc '.kyverno.policies.verifyImageSignature.attestor' \
    '"-----BEGIN CERTIFICATE-----
MIIDiDCCAnCgAwIBAgIUbuQtBbiAUYgkqtd8Af0PijxnkY4wDQYJKoZIhvcNAQEL
BQAwUzELMAkGA1UEBhMCU0UxEjAQBgNVBAoMCUVsYXN0aXN5czEMMAoGA1UECwwD
TVNFMSIwIAYDVQQDDBlJbWFnZSBTaWduaW5nIFRlc3QgQ2VydCBhMB4XDTI1MDYx
MzExNTIzNFoXDTI1MDcxMzExNTIzNFowUzELMAkGA1UEBhMCU0UxEjAQBgNVBAoM
CUVsYXN0aXN5czEMMAoGA1UECwwDTVNFMSIwIAYDVQQDDBlJbWFnZSBTaWduaW5n
IFRlc3QgQ2VydCBhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlSlz
IeMd9gFTjXDMhUymYLKHpXWRjSZ8MjRU0QblEIYDOMqo6bFpxZsT+JQmIzBhotmN
RV+DqAl+V6LLVeRWyP7Qos6NaBWzFC5PziTpdlphU6eNvSv9lUvEB3fYBYunVItE
HtQ1sV7hkEXivXvb3lORvSeO/L0nIakIgesf13YZNSlja/j8iz9QlPZ7uW9+E/hc
N9vit7DaM/m/gEw8Ad+iZqr+g5pB23gRM9Ii1H9vNvtEMrKLI5r8Iol02aflhAMq
rw5emP6H9h1ro3PJMB2N3Sp4m7ZUbNrznEO3IxSxK0Qs7OVucGbn5iq/iC9nnGQw
HYQJ/RtGgk99HhBPVwIDAQABo1QwUjAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUQDICKyVOjLMU+7qW
0+cth3ca41IwDQYJKoZIhvcNAQELBQADggEBAGYEtQZPADiBMgCPUngSMq4mZPRZ
JaQ9OVr05BpdtiKq5uXkXAlnC7Xdb1MHCKRCBdtr63agugo+ByCefe5gklykA/Nb
VCm5ZUP9ea4JbQ0QfDVzwIP37BV0jff5JOMtaCvzqeKbi6Qo1XMGLj+BEPD3pvQk
SYbIAXYZsXYx6ewA65QVtz2FiRB1Cjz+OmZS6LCeeaklHy6vCiHyDK1ImXsCqT2Q
OZLRlcv5A8L8pDscIRU3bMDH9kXinF0ZplxMZJw+iRDxO5qpgZkbBIhmhoYpFsfa
yzdFQc2SeWn7xclpNIa2iYuaZTFgojEdlRUBrm5RLaTDbL2DE+uKXrGDuEc=
-----END CERTIFICATE-----
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
  run kubectl run test-signed --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:notation-a
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
  run kubectl create deployment secure-deploy --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:notation-a
  assert_success
}

@test "can NOT deploy a deployment with an unsigned image" {
  run kubectl create deployment test-unsigned --namespace=securespace --image=ghcr.io/elastisys/curl-jq:1.0.0
  assert_failure
  assert_output --partial "verify-image-signature: 'failed to verify image"
}

@test "can NOT change a deployment to an unsigned image" {
  run kubectl create deployment secure-deploy --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:notation-a
  assert_success

  run kubectl set image deployment secure-deploy --namespace=securespace secure-deploy=ghcr.io/elastisys/curl-jq:1.0.0
  assert_failure
}

@test "can NOT run image signed by untrusted key" {
  run kubectl create deployment test-unsigned --namespace=securespace --image=ghcr.io/elastisys/kyverno-test-image:notation-c
  assert_failure
  assert_output --partial "signature is not produced by a trusted signer"
}
