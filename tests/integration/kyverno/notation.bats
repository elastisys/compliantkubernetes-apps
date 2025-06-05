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
  yq.set wc '.kyverno.policies.verifyImageSignature.attestors' \
'"-----BEGIN CERTIFICATE-----
MIIDhDCCAmygAwIBAgIUQDXugI95YJTsy4cKf0fb2F6DMhYwDQYJKoZIhvcNAQEL
BQAwUTELMAkGA1UEBhMCU0UxEjAQBgNVBAoMCUVsYXN0aXN5czEMMAoGA1UECwwD
TVNFMSAwHgYDVQQDDBdJbWFnZSBTaWduaW5nIFRlc3QgQ2VydDAeFw0yNTA1MTkx
MzE3MzJaFw0yNTA2MTgxMzE3MzJaMFExCzAJBgNVBAYTAlNFMRIwEAYDVQQKDAlF
bGFzdGlzeXMxDDAKBgNVBAsMA01TRTEgMB4GA1UEAwwXSW1hZ2UgU2lnbmluZyBU
ZXN0IENlcnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCVKXMh4x32
AVONcMyFTKZgsoeldZGNJnwyNFTRBuUQhgM4yqjpsWnFmxP4lCYjMGGi2Y1FX4Oo
CX5XostV5FbI/tCizo1oFbMULk/OJOl2WmFTp429K/2VS8QHd9gFi6dUi0Qe1DWx
XuGQReK9e9veU5G9J478vSchqQiB6x/Xdhk1KWNr+PyLP1CU9nu5b34T+Fw32+K3
sNoz+b+ATDwB36Jmqv6DmkHbeBEz0iLUf282+0QysosjmvwiiXTZp+WEAyqvDl6Y
/of2HWujc8kwHY3dKnibtlRs2vOcQ7cjFLErRCzs5W5wZufmKr+IL2ecZDAdhAn9
G0aCT30eEE9XAgMBAAGjVDBSMAkGA1UdEwQCMAAwDgYDVR0PAQH/BAQDAgeAMBYG
A1UdJQEB/wQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRAMgIrJU6MsxT7upbT5y2H
dxrjUjANBgkqhkiG9w0BAQsFAAOCAQEAJvoaNUYWGV+RluohwPO53Xc7Gi6gPzK1
gCf5gMzKg231IlvqHe/jxGIhoE+JPCEctb2mDBl6lKz/h8HSrtC4Hcd28CiHM0WR
1CU2WULlXYTkS03Oc3Jz14JcJ6S5U2yRcOAj0Ly9zu8zy5O9W41b1wPyOnqZdUc6
ojBKxnWOcwwv+Cf8w4fKORb8FrpwynajFmt0u1JaeFVUUFQwD8Zft9yXx8V+jsjH
riW+YqloGCNVJK4D5Vw4OYlWUETlxdOyp4FMnZ2SOxiDGXE7LKXY+a7M2S71VcZZ
E/h1SgwfB3awlula/iFTpuLFqpVr7SimJ3CsWajbXU13k/lawPJ1+g==
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
