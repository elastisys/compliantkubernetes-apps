#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"
  load_common "yq.bash"

  log.trace "Configuring for Notary"
  yq.set wc '.kyverno.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.enabled' true
  yq.set wc '.kyverno.policies.verifyImageSignature.type' '"Notary"'
  yq.set wc '.kyverno.policies.verifyImageSignature.ignoreRekorTlog' true
  # Key a and key b
  yq.set wc '.kyverno.policies.verifyImageSignature.attestors' \
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
-----BEGIN CERTIFICATE-----
MIIDiDCCAnCgAwIBAgIUfWB5PTNFlUN9Cqj+cjE1kQlt/fowDQYJKoZIhvcNAQEL
BQAwUzELMAkGA1UEBhMCU0UxEjAQBgNVBAoMCUVsYXN0aXN5czEMMAoGA1UECwwD
TVNFMSIwIAYDVQQDDBlJbWFnZSBTaWduaW5nIFRlc3QgQ2VydCBiMB4XDTI1MDYx
MzExNTIzNFoXDTI1MDcxMzExNTIzNFowUzELMAkGA1UEBhMCU0UxEjAQBgNVBAoM
CUVsYXN0aXN5czEMMAoGA1UECwwDTVNFMSIwIAYDVQQDDBlJbWFnZSBTaWduaW5n
IFRlc3QgQ2VydCBiMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtPNw
jYMU/GTzVhxVbu9AqnwU8FlUbTo0xE0vpxIfy4a5E5/FX/Shzc5LI5Ep3GWm4EQr
vunhwrjGic88KtgMlZ62mGF3d1FtcB+FsMI2xuf0TOfQCs9UqP3GAum8Drlib5kQ
fHG4jDwWWgPTKFvMqIvN+XREfQghP4pi0i8c/M0mxIbqWrUGho46oxNijbSfgWpZ
nPKrjfwQ7Rdu78FIqOKQdQIG0qJQm06pdf+ZThn+X1GLNQwDoMYniZW3uD4oivOW
6GYpYUy1bQRmE8agbx1XfPjLW9RxECr7MQEASMUM3WjvY4SR28SmTz7O8llZeVO5
DyazQUzyjLpCbLRw+wIDAQABo1QwUjAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUVrGHDj8LEMaX+6mx
RNcYrTFq+yowDQYJKoZIhvcNAQELBQADggEBAAhHm4SuzuUkqyYHu5BtM3P6K2Ve
gxG2mOcgJ/rdqdnHRfONvQQ7NAxnh+e5bN7hXIKAc1+CghANvfgZpJ0YXrB6efjR
FHcGqXFQRvmAak5bS3VFjkvVG+QhVAK/1k7be/c8KDlcTFlXeW/cuGQ6tuxGHlnX
HuPNOOqcHELzQuusCsoCEN6jSPN25JT0coivz7ZiEktrFpRmu13/NjUaOva56psS
VnKywpKJGXu6qoeaaTw75Lv6UUBYPfP2yzi7Ml64b+Frt4bSwg+okfzFIce4UpNG
5mHLA7SKEYpRwDaCgKqo1oCXxwpMChMs+ENGDmlURICZ3As9gO2sSXHmlU0=
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
