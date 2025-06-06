#!/usr/bin/env bash

# This script takes care of explaining Welkin Apps config and secrets.
# It's not to be executed on its own but rather via 'ck8s explain'.

set -euo pipefail

declare here root
here="$(dirname "$(readlink -f "$0")")"
root="$(dirname "${here}")"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  log_error "error: invalid argument: \"${1:-}\""
  log_error "usage: ck8s explain <config|secrets> [key.to.parameter]"
  exit 1
}

# Note:
# This function does not properly handle the encoding used for special characters within JSON Pointers.
dereference() {
  # shellcheck disable=SC2016
  yq '. as $root | with(
    .. | select(key == "$ref");
    . = "$root." + (
      sub("#/", "") | split("/") | with(.[]; . = to_json(0) ) | join(".")
    )
  ) | with(
    .. | select(has "$ref");
    . = eval(."$ref")
  )' "$1"
}

hasreference() {
  # shellcheck disable=SC2016
  yq '[.. | select(key == "$ref")] | length != 0' "$1"
}

recvdereference() {
  local data
  data="$(dereference "$1")"

  while [[ "$(hasreference - <<<"${data}")" == true ]]; do
    data="$(dereference - <<<"${data}")"
  done

  echo "${data}"
}

explain() {
  local data schema target
  schema="${1}"
  target="${2:-}"

  data="$(recvdereference "${schema}")"

  if [[ -n "${target}" ]]; then
    local -a path
    readarray -t path <<<"$(yq 'split(".") | .[]' <<<"${target}")"

    for key in "${path[@]}"; do
      case "$(yq ".type" <<<"${data}")" in
      array)
        data="$(yq ".items.properties.${key}" <<<"${data}")"
        ;;
      object)
        if [[ "${key}" == "additionalProperties" ]]; then
          data="$(yq ".additionalProperties" <<<"${data}")"
        else
          data="$(yq ".properties.${key}" <<<"${data}")"
        fi
        ;;
      *)
        log_error "unable to navigate to ${key} on path to ${target} found unnavigable type: $(yq ".type" <<<"${data}")"
        exit 1
        ;;
      esac

      if [[ "${data}" == null ]]; then
        log_error "unable to navigate to ${key} on path to ${target} found nothing"
        exit 1
      fi
    done
  fi

  local title desc type subtype

  title="$(yq ".title // \"${2:-root}\"" <<<"${data}")"
  desc="$(yq '.description // "no description"' <<<"${data}")"
  type="$(yq '.type' <<<"${data}")"

  case "${type}" in
  array)
    subtype="$(yq '.items.type // "any"' <<<"${data}")"
    ;;
  object)
    if [[ "$(yq '.properties // {} | length == 0 and .additionalProperties != false' <<<"${data}")" == "true" ]]; then
      subtype="$(yq '.additionalProperties.type // "any"' <<<"${data}")"
    fi
    ;;
  esac

  if [[ "$(yq '.enum // [] | length != 0' <<<"${data}")" == "true" ]]; then
    subtype="${type}"
    type="enum"
  fi

  echo -e "\e[1m${title}\e[22m"
  echo

  echo "${desc}"
  echo

  export type subtype
  case "${subtype:-}" in
  "object")
    yq --null-input '{"type": strenv(type) + " of " + strenv(subtype) + "s"} | .type line_comment="you can navigate further using .additionalProperties"'
    ;;
  "")
    yq --null-input '{"type": strenv(type)}'
    ;;
  *)
    yq --null-input '{"type": strenv(type) + " of " + strenv(subtype) + "s"}'
    ;;
  esac

  case "${type}" in
  array)
    case "$(yq '.items.type' <<<"${data}")" in
    object)
      echo
      yq '{"properties": .items.properties | keys}' <<<"${data}"
      ;;
    esac
    ;;
  enum)
    echo
    yq '{"options": .enum}' <<<"${data}"
    ;;
  object)
    if [[ "$(yq '.properties // {} | length != 0' <<<"${data}")" == "true" ]]; then
      echo
      yq '{"properties": .properties | keys}' <<<"${data}"
    fi
    ;;
  esac

  if [[ "$(yq '.default == null' <<<"${data}")" == "false" ]]; then
    echo
    yq '{"defaults": .default}' <<<"${data}"
  elif [[ "$(yq '(.type == "array") and (.items.properties // {} | length == 0)' <<<"${data}")" == "true" ]]; then
    echo
    echo "This array lacks defaults"
  elif [[ "$(yq '(.type == "object") and (.properties // {} | length == 0)' <<<"${data}")" == "true" ]]; then
    echo
    echo "This object lacks defaults"
  elif [[ "${type}" != "array" ]] && [[ "${type}" != "object" ]]; then
    echo
    echo "This ${type} lacks defaults"
  fi

  if [[ "$(yq '.examples == null' <<<"${data}")" == "false" ]]; then
    echo
    yq '{"examples": .examples}' <<<"${data}"
  fi

  if [[ "$(yq '(.type == "array") and (.items.examples // [] | length != 0)' <<<"${data}")" == "true" ]]; then
    echo
    yq '{"item examples": .items.examples}' <<<"${data}"
  fi
}

declare schema

case "${1:-}" in
config)
  schema="${root}/config/schemas/config.yaml"
  ;;
secrets)
  schema="${root}/config/schemas/secrets.yaml"
  ;;
*)
  usage "${1:-}"
  ;;
esac

explain "${schema}" "${2:-}"
