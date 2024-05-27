#!/usr/bin/env bash

# This script ensure that regardless if one uses docker or podman it is still possible to manage files properly from within containers.

# FORWARD_ENVIRONMENT - To be used for end-to-end tests
# FORWARD_RUNTIME - To be used for integration tests

set -euo pipefail

declare root
root="$(dirname "$(dirname "$(readlink -f "$0")")")"

log.info.no_newline() {
  echo -en "[\e[34mck8s\e[0m] ${*}" 1>&2
}
log.info() {
  log.info.no_newline "${*}\n"
}
log.warn.no_newline() {
  echo -e -n "[\e[33mck8s\e[0m] ${*}" 1>&2
}
log.warn() {
  log.warn.no_newline "${*}\n"
}
log.error.no_newline() {
  echo -e -n "[\e[31mck8s\e[0m] ${*}" 1>&2
}
log.error() {
  log.error.no_newline "${*}\n"
}
log.fatal() {
  log.error "${*}"
  exit 1
}
log.continue() {
  if [[ "${CK8S_AUTO_APPROVE:-false}" != "true" ]]; then
    log.warn.no_newline "${1} [y/N]: "

    read -r reply
    if ! [[ "${reply}" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
      log.fatal "aborted"
    fi
  fi
}

yq() {
  if command -v yq4 > /dev/null; then
    command yq4 "${@}"
  else
    command yq "${@}"
  fi
}

declare runtime

if command -v docker > /dev/null; then
  runtime="docker"
elif command -v podman > /dev/null; then
  runtime="podman"
else
  log.fatal "no container runtime found" >&2
fi

declare -a args
args=("--rm")

if [[ -t 1 ]] && [[ -z "${CI:-}" ]]; then
  args+=("-it")
fi

args+=("--hostname" "compliantkubernetes-apps-tests" "--workdir" "${root}")

if [[ "${FORWARD_ENVIRONMENT:-false}" == "true" ]] || [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
  log.continue "forward your environment and/or runtime to container ${1:-}?"
  args+=("--network" "host")
fi

args+=("--user" "$(id -u):$(id -g)")

if [[ "$("${runtime}" version)" =~ Podman ]]; then
  runtime="podman"

  args+=("--userns" "keep-id")

  if [[ "$(podman info | yq '.host.security.selinuxEnabled')" == "true" ]]; then
    declare relabel=",relabel=shared"
  fi

  args+=("--mount" "type=bind,src=${root},dst=${root}${relabel:-}")

  if [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
    args+=("--env" "KIND_EXPERIMENTAL_PROVIDER=podman")
    args+=("--env" "XDG_RUNTIME_DIR")
    args+=("--mount" "type=tmpfs,dst=${XDG_RUNTIME_DIR},chown")
    args+=("--mount" "type=bind,src=${XDG_RUNTIME_DIR}/podman/podman.sock,dst=${XDG_RUNTIME_DIR}/podman/podman.sock${relabel:-}")
    args+=("--security-opt" "label=disable")
  fi
else
  args+=("--mount" "type=bind,src=/etc/passwd,dst=/etc/passwd,ro")
  args+=("--mount" "type=bind,src=/etc/group,dst=/etc/group,ro")

  args+=("--mount" "type=bind,src=${root},dst=${root}")

  if [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
    args+=("--mount" "type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock")
  fi
fi

"${runtime}" run "${args[@]}" "${@}"
