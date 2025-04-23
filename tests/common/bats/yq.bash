#!/usr/bin/env bash

# Helpers for running yq

# conditionally run yq4 or yq depending on how it is installed
yq() {
  if command -v yq4 >/dev/null; then
    command yq4 "${@}"
  else
    if ! command yq -V | grep --extended-regexp "v4\." >/dev/null 2>&1; then
      echo -e -n "[\e[31mck8s\e[0m] expecting the yq binary to be at least version v4" 1>&2
      exit 1
    else
      command yq "${@}"
    fi
  fi
}

# note: more correct than yq.dig for complex data such as maps that can be merged
# usage: yq.get <cluster> <config-key> <default>
yq.get() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  elif [[ -z "${2:-}" ]]; then
    fail "missing config key argument"
  fi

  local value
  value="$(yq ea "explode(.) as \$item ireduce ({}; . * \$item) | $2 | ... comments=\"\"" "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" "${CK8S_CONFIG_PATH}/defaults/$1-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" "${CK8S_CONFIG_PATH}/$1-config.yaml")"

  if [[ -n "${value#null}" ]]; then
    echo "${value}"
  else
    echo "${3:-}"
  fi
}

# note: more efficient than yq.get for simple data such as scalars that cannot be merged
# usage: yq.dig <cluster> <config-key> <default>
yq.dig() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  elif [[ -z "${2:-}" ]]; then
    fail "missing config key argument"
  fi

  local value
  value="$(yq ea "explode(.) | $2 | select(. != null) | {\"wrapper\": .} as \$item ireduce ({}; . * \$item) | .wrapper | ... comments=\"\"" "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" "${CK8S_CONFIG_PATH}/defaults/$1-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" "${CK8S_CONFIG_PATH}/$1-config.yaml")"

  if [[ -n "${value#null}" ]]; then
    echo "${value}"
  else
    echo "${3:-}"
  fi
}

# usage: yq.set <config-file> <config-key> <value>
yq.set() {
  if ! [[ "${1:-}" =~ ^(common|secrets|sc|wc)$ ]]; then
    fail "invalid or missing config file argument"
  elif [[ -z "${2:-}" ]]; then
    fail "missing config key argument"
  elif [[ -z "${3:-}" ]]; then
    fail "missing value argument"
  fi

  if [[ "${1}" =~ ^(common|sc|wc)$ ]]; then
    yq -i "${2} = ${3}" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  elif [[ "${1}" == "secrets" ]]; then
    sops --set "${2} ${3}" "${CK8S_CONFIG_PATH}/secrets.yaml"
  fi
}

# usage: yq.secret <config-key> <default>
yq.secret() {
  if [[ -z "${1:-}" ]]; then
    fail "missing config key argument"
  fi

  local value
  value="$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq "$1 | ... comments=\"\"")"

  if [[ -n "${value#null}" ]]; then
    echo "${value}"
  else
    echo "${2:-}"
  fi
}

# usage: yq.continue_on <cluster> <config-key>
yq.continue_on() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  elif [[ -z "${2:-}" ]]; then
    fail "missing config key argument"
  fi

  if [[ "$(yq.dig "$1" "$2" "false")" != "true" ]]; then
    skip "$1/$2 - disabled"
  fi
}
