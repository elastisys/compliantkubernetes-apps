#!/usr/bin/env bats

set -ueo pipefail

setup() {
    load "bats-helpers/bats-support/load"
    load "bats-helpers/bats-assert/load"

    export PATH="${BATS_TEST_DIRNAME}/../bin:${PATH}"

    ck8s_config_path_tmp="${BATS_TMPDIR}/ck8s-apps-config"

    export CK8S_CONFIG_PATH="${ck8s_config_path_tmp}"
    export CK8S_ENVIRONMENT_NAME=test
    export CK8S_PGP_FP=529D964DE0BBD900C4A395DA09986C297F8B7757
    export CK8S_CLOUD_PROVIDER=aws
}

teardown() {
    rm -rf "${ck8s_config_path_tmp}"
}

@test "ck8s init requires CK8S_CONFIG_PATH" {
    CK8S_CONFIG_PATH="" run ck8s init
    assert_failure
    assert_output --partial "Missing CK8S_CONFIG_PATH"
}

@test "ck8s init requires CK8S_ENVIRONMENT_NAME" {
    CK8S_ENVIRONMENT_NAME="" run ck8s init
    assert_failure
    assert_output --partial "Missing CK8S_ENVIRONMENT_NAME"
}

@test "ck8s init requires valid CK8S_PGP_FP or valid CK8S_PGP_UID" {
    unset CK8S_PGP_FP

    run ck8s init
    assert_failure
    assert_output --partial "CK8S_PGP_FP and CK8S_PGP_UID can't both be unset"

    CK8S_PGP_FP="123" run ck8s init
    assert_failure
    assert_output --partial "Fingerprint does not exist in gpg keyring"

    CK8S_PGP_UID="asd" run ck8s init
    assert_failure
    assert_output --partial "Unable to get fingerprint from gpg keyring using UID"
}

@test "ck8s init requires CK8S_CLOUD_PROVIDER" {
    CK8S_CLOUD_PROVIDER="" run ck8s init
    assert_failure
    assert_output --partial "Missing CK8S_CLOUD_PROVIDER"
}

@test "ck8s init checks supported cloud providers" {
    CK8S_CLOUD_PROVIDER=foo run ck8s init
    assert_failure
    assert_output --partial "Unsupported cloud provider: foo"
}

@test "ck8s init checks supported flavors" {
    CK8S_CLOUD_PROVIDER=aws CK8S_FLAVOR=foo run ck8s init
    assert_failure
    assert_output --partial "Unsupported flavor: foo"
}

@test "ck8s init is idempotent" {
    # TODO: Convert this to parametric test if it gets implemented:
    # https://github.com/bats-core/bats-core/issues/241
    [ -n "${CK8S_SKIP_LONG_RUNNING_TESTS:-}" ] && skip
    for cloud_provider in $(ck8s providers); do
        for flavor in $(ck8s flavors); do
            export CK8S_CLOUD_PROVIDER="${cloud_provider}"
            export CK8S_FLAVOR="${flavor}"

            local config_1="${CK8S_CONFIG_PATH}/1"
            local config_2="${CK8S_CONFIG_PATH}/2"

            CK8S_CONFIG_PATH="${config_1}" run ck8s init
            assert_success

            cp -R "${config_1}/." "${config_2}/"

            CK8S_CONFIG_PATH="${config_2}" run ck8s init
            assert_success

            run diff "${config_1}/sc-config.yaml" "${config_2}/sc-config.yaml"
            assert_success

            run diff "${config_1}/wc-config.yaml" "${config_2}/wc-config.yaml"
            assert_success

            run diff <(sops -d "${config_1}/secrets.yaml") \
                <(sops -d "${config_2}/secrets.yaml")
            assert_success

            rm -r "${config_1}" "${config_2}"
        done
    done
}
