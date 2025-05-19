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
  yq.set wc '.kyverno.policies.verifyImageSignature.certificates' \
  '"-----BEGIN CERTIFICATE-----
MIIDOjCCAiKgAwIBAgIBQDANBgkqhkiG9w0BAQsFADBMMQswCQYDVQQGEwJVUzEL
MAkGA1UECBMCV0ExEDAOBgNVBAcTB1NlYXR0bGUxDzANBgNVBAoTBk5vdGFyeTEN
MAsGA1UEAxMEdGVzdDAeFw0yNTA1MDIwOTI5MDVaFw0yNTA1MDMwOTI5MDVaMEwx
CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMHU2VhdHRsZTEPMA0G
A1UEChMGTm90YXJ5MQ0wCwYDVQQDEwR0ZXN0MIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEA95K6UdAz7c+ItOwRuS9l6JPBmZh75W4eJX+o8FC/hBr2uZjS
DeqWP1+J/juOJzhvp1iHgVK7bZ+jBXVRl+XsNJz44KQ0noL0PYmLWupVPUZ8Sf80
ajXaDFl7KEUUPdCa1TL/gjBwj8Yi1SsiIko2m7gzG4/1D7pTF8QBU6zfe64h9Eu6
9rHn5g/t9DTvWa9AdMrlhrqRGdOurUntyekSo/seZIBIKv3D5oJcXPYBUdIVGpD5
ZDT/UU34CXj0i8fZORZbxYjyfgzpHUB6DdpI40GM5FfeTChqN1m6tqqhUUPboL8o
2jMxGqNrOtSfnRxZA3hlg1amffzzfF1UTTlMkQIDAQABoycwJTAOBgNVHQ8BAf8E
BAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwDQYJKoZIhvcNAQELBQADggEBAHyL
CUskewnyfOlcNjDScQuIY5H+nAat+LiQ/XivOIl+yZ+YjUtAQWp1avF5K2Dup0ZT
UUAxaSBTLHx1xjlT90/4KmHC4K0s8BEmx0mvmCwBiPW+1Bn8BZOl1hx7H3q+EirE
JHINlZrJw0nNsYdBAJSY5oJMz6IXBTx1ZF1GuVe9G+V0osMP/sGP+dKTEE7VIKdO
9DsHqUpsMWDN40blZe1r7eROs3V1k8QE8T+3aMyGmB6X+qQuQY8QdRS0S+HFZnRh
5VV0rToEZqmSHYrvUpIDKbgXzwA+6snF+5lM0HqKJJwh0oMj6cVIXtBDNypAl0PK
/3Kfd6ZM3scDbITvimU=
-----END CERTIFICATE-----
"'

  ck8s ops helmfile wc apply --include-transitive-needs --output simple -l app=kyverno
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "signed image allowed" {
  run kubectl run test-signed --image=ghcr.io/elastisys/test-verify-image:signed
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
