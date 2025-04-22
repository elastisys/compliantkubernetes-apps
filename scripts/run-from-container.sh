#!/usr/bin/env bash

# This script ensure that regardless if one uses docker or podman it is still possible to manage files properly from within containers.

# Environment variables:
# - FORWARD_ENVIRONMENT - Used for end-to-end tests
# - FORWARD_RUNTIME - Used for integration tests

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

# conditionally run yq4 or yq depending on how it is installed
yq() {
  if command -v yq4 >/dev/null; then
    command yq4 "${@}"
  else
    if ! command yq -V | grep --extended-regexp "v4\." >/dev/null 2>&1; then
      log.error "expecting the yq binary to be at least version v4"
    else
      command yq "${@}"
    fi
  fi
}

declare runtime

if command -v docker >/dev/null && docker version >/dev/null 2>&1 && [[ ! "$(docker version)" =~ Podman ]]; then
  runtime="docker"
elif command -v podman >/dev/null; then
  runtime="podman"
else
  log.fatal "no container runtime found" >&2
fi

declare -a args
args=("--init" "--rm")

if [[ -t 0 ]] && [[ -t 1 ]] && [[ -z "${CI:-}" ]]; then
  args+=("-it")
fi

args+=("--hostname" "compliantkubernetes-apps-tests")
args+=("--workdir" "${root}")
args+=("--env" "LANG=C.UTF-8")

# Prepare podman to work with selinux
if [[ "${runtime}" == "podman" ]]; then
  if [[ "${FORWARD_ENVIRONMENT:-false}" == "true" ]] || [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
    args+=("--security-opt" "label=disable")
  else
    relabel=",relabel=shared"
  fi
fi

# Use host network to allow container work with the environment as the host would
if [[ "${FORWARD_ENVIRONMENT:-false}" == "true" ]] || [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
  args+=("--network" "host")
fi

# Use host user to allow container work with the files as the host would
args+=("--user" "$(id -u):$(id -g)")
if [[ "${runtime}" == "docker" ]]; then
  args+=("--mount" "type=bind,src=/etc/passwd,dst=/etc/passwd,ro")
  args+=("--mount" "type=bind,src=/etc/group,dst=/etc/group,ro")
else
  args+=("--userns" "keep-id")
fi

# Prepare runtime directory for additional mounts
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  args+=("--env" "XDG_RUNTIME_DIR")
  if [[ "${runtime}" == "docker" ]]; then
    args+=("--tmpfs" "${XDG_RUNTIME_DIR}:uid=$(id -u),gid=$(id -g)")
  else
    args+=("--mount" "type=tmpfs,dst=${XDG_RUNTIME_DIR},chown")
  fi
fi

# Prepare container runtime socket
if [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
  if [[ "${runtime}" == "docker" ]]; then
    declare docker_gid
    docker_gid="$(getent group docker | awk -F: '{ print $3 }')"
    args+=("--group-add" "${docker_gid}")
    args+=("--mount" "type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock")
  else
    args+=("--env" "KIND_EXPERIMENTAL_PROVIDER=podman")
    args+=("--mount" "type=bind,src=${XDG_RUNTIME_DIR}/podman/podman.sock,dst=${XDG_RUNTIME_DIR}/podman/podman.sock")
  fi
fi

if [[ "${FORWARD_ENVIRONMENT:-false}" == "true" ]] || [[ "${FORWARD_RUNTIME:-false}" == "true" ]]; then
  # Prepare container graphics
  if [[ -n "${DISPLAY:-}" ]]; then
    args+=("--env" "DISPLAY")
    args+=("--mount" "type=bind,src=/run/dbus,dst=/run/dbus")
    args+=("--device" "/dev/dri")
    args+=("--ipc" "host")
  fi

  if [[ -n "${XAUTHORITY:-}" ]]; then
    args+=("--env" "XAUTHORITY")
    args+=("--mount" "type=bind,src=${XAUTHORITY},dst=${XAUTHORITY}")
  fi

  # Prepare container home
  args+=("--env" "HOME")
  if [[ "${runtime}" == "docker" ]]; then
    args+=("--tmpfs" "${HOME}:uid=$(id -u),gid=$(id -g)")
  else
    args+=("--mount" "type=tmpfs,dst=${HOME},chown")
  fi
fi

if [[ "${FORWARD_ENVIRONMENT:-false}" == "true" ]]; then
  args+=("--mount" "type=bind,src=${HOME}/.kube/cache/oidc-login,dst=${HOME}/.kube/cache/oidc-login")

  # Prepare container gpg
  declare GNUPGHOME GNUPGSOCKETDIR
  GNUPGHOME="${GNUPGHOME:-"${HOME}/.gnupg"}"
  GNUPGSOCKETDIR="$(gpgconf --list-dirs socketdir)"
  export GNUPGHOME

  args+=("--env" "GNUPGHOME")
  args+=("--mount" "type=bind,src=${GNUPGHOME},dst=${GNUPGHOME}")
  if [[ "${GNUPGHOME}" != "${GNUPGSOCKETDIR}" ]]; then
    args+=("--mount" "type=bind,src=${GNUPGSOCKETDIR},dst=${GNUPGSOCKETDIR}")
  fi

  # Prepare container env
  args+=("--env" "CK8S_CONFIG_PATH")
  args+=("--mount" "type=bind,src=${CK8S_CONFIG_PATH},dst=${CK8S_CONFIG_PATH}")
fi

# Check if we are in a work tree
if command -v git &>/dev/null; then
  declare gitdir
  if gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null)"; then
    if [[ "${gitdir%"/.git/"*}" != "${root}" ]]; then
      # Prepare container repo root
      args+=("--mount" "type=bind,src=${gitdir%"/.git/"*},dst=${gitdir%"/.git/"*}${relabel:-}")
    fi
  fi
  # else rely on relative mount only
fi

# Prepare container repo
args+=("--env" "APPS_PATH=${root}")
args+=("--mount" "type=bind,src=${root},dst=${root}${relabel:-}")

"${runtime}" run "${args[@]}" "${@}"
