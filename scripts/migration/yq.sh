#!/usr/bin/env bash

# warning: only shows consistent results on anything that is not a map
yq_dig() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_dig <sc|wc> <target>"
  fi

  yq ea "explode(.) | ${2} | select(. != null) | {\"wrapper\": .} as \$item ireduce ({}; . * \$item) | .wrapper | ... comments=\"\"" "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" "${CK8S_CONFIG_PATH}/defaults/${1}-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
}

yq_null() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_null <common|sc|wc> <target>"
  fi

  test "$(yq "${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml")" = "null"
}

yq_check() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_check <common|sc|wc> <target> <value>"
  fi

  test "$(yq "${2}" "$CK8S_CONFIG_PATH/${1}-config.yaml")" = "${3}"
}

yq_copy() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_copy <common|sc|wc> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - copy: ${2} to ${3}"
    yq -i "${3} = ${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_move() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_move <common|sc|wc> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - move: ${2} to ${3}"
    yq -i "${3} = ${2} | del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_move_to_file() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]] || [[ ! "${3}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_move_to_file <common|sc|wc> <source> <common|sc|wc> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - move: ${1} ${2} to ${4} ${3}"
    yq -oj -I0 "${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml" |
      yq -i "${4} = load(\"/dev/stdin\")" "${CK8S_CONFIG_PATH}/${3}-config.yaml"
    yq -i "del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_add() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_add <common|sc|wc> <destination> <value>"
  fi

  log_info "  - add: ${3} to ${2}"
  yq -i "${2} = ${3}" "$CK8S_CONFIG_PATH/${1}-config.yaml"
}

yq_remove() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_remove <common|sc|wc> <target>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - remove: ${2}"
    yq -i "del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_merge() {
  yq eval-all --prettyPrint "... comments=\"\" | explode(.) as \$item ireduce ({}; . * \$item )" "${@}"
}

yq_paths() {
  yq "[.. | select(tag != \"!!map\" and . == \"${1}\") | path | with(.[]; . = (\"\\\"\" + .) + \"\\\"\") | \".\" + join \".\" | sub(\"\\.\\\"[0-9]\\\"+.*\"; \"\")] | sort | unique | .[]"
}
