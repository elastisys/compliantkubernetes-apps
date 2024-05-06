#!/usr/bin/env bash

test_init_successful() {
  assert_file_exists "${CK8S_CONFIG_PATH}/common-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/sc-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/wc-config.yaml"

  assert_file_exists "${CK8S_CONFIG_PATH}/secrets.yaml"

  assert_file_contains "${CK8S_CONFIG_PATH}/secrets.yaml" "sops:"

  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"

  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
}

test_init_idempotent() {
  mkdir "${CK8S_CONFIG_PATH}/one"

  export CONFIG_ONE="${CK8S_CONFIG_PATH}/one"
  export CONFIG_TWO="${CK8S_CONFIG_PATH}/two"

  CK8S_CONFIG_PATH="${CONFIG_ONE}" run ck8s init both
  assert_success

  cp -r "${CONFIG_ONE}" "${CONFIG_TWO}"

  CK8S_CONFIG_PATH="${CONFIG_TWO}" run ck8s init both
  assert_success

  run diff "${CONFIG_ONE}/defaults/common-config.yaml" "${CONFIG_TWO}/defaults/common-config.yaml"
  assert_success

  run diff "${CONFIG_ONE}/common-config.yaml" "${CONFIG_TWO}/common-config.yaml"
  assert_success

  run diff "${CONFIG_ONE}/defaults/sc-config.yaml" "${CONFIG_TWO}/defaults/sc-config.yaml"
  assert_success

  run diff "${CONFIG_ONE}/sc-config.yaml" "${CONFIG_TWO}/sc-config.yaml"
  assert_success

  run diff "${CONFIG_ONE}/defaults/wc-config.yaml" "${CONFIG_TWO}/defaults/wc-config.yaml"
  assert_success

  run diff "${CONFIG_ONE}/wc-config.yaml" "${CONFIG_TWO}/wc-config.yaml"
  assert_success

  run diff <(sops -d "${CONFIG_ONE}/secrets.yaml") <(sops -d "${CONFIG_TWO}/secrets.yaml")
  assert_success

  rm -rf "${CONFIG_ONE}" "${CONFIG_TWO}"
}
