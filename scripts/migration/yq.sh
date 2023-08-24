#!/usr/bin/env bash

yq_null() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_null <common|sc|wc> <target>"
  fi

  test "$(yq4 "${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml")" = "null"
}

yq_check() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_check <common|sc|wc> <target> <value>"
  fi

  test "$(yq4 "$2" "$CK8S_CONFIG_PATH/$1-config.yaml")" = "$3"
}

yq_copy() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_copy <common|sc|wc> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - copy: ${2} to ${3}"
    yq4 -i "${3} = ${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_move() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_move <common|sc|wc> <source> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - move: ${2} to ${3}"
    yq4 -i "${3} = ${2} | del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_move_to_file() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]] || [[ ! "${3}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_move_to_file <common|sc|wc> <source> <common|sc|wc> <destination>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - move: ${1} ${2} to ${4} ${3}"
    yq4 -oj -I0 "${2}" "${CK8S_CONFIG_PATH}/${1}-config.yaml" |
    yq4 -i "${4} = load(\"/dev/stdin\")" "${CK8S_CONFIG_PATH}/${3}-config.yaml"
    yq4 -i "del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_add() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_add <common|sc|wc> <destination> <value>"
  fi

  log_info "  - add: ${3} to ${2}"
  yq4 -i "$2 = $3" "$CK8S_CONFIG_PATH/$1-config.yaml"
}

yq_remove() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(common|sc|wc)$ ]]; then
    log_fatal "usage: yq_remove <common|sc|wc> <target>"
  fi

  if ! yq_null "${1}" "${2}"; then
    log_info "  - remove: ${2}"
    yq4 -i "del(${2})" "${CK8S_CONFIG_PATH}/${1}-config.yaml"
  fi
}

yq_merge() {
  yq4 eval-all --prettyPrint "... comments=\"\" | explode(.) as \$item ireduce ({}; . * \$item )" "${@}"
}

yq_paths() {
  yq4 "[.. | select(tag != \"!!map\" and . == \"${1}\") | path | with(.[]; . = (\"\\\"\" + .) + \"\\\"\") | \".\" + join \".\" | sub(\"\\.\\\"[0-9]\\\"+.*\"; \"\")] | sort | unique | .[]"
}
