#!/usr/bin/env bash

# This script ensure that regardless if one uses docker or podman it is still possible to manage files properly from within containers.

set -euo pipefail

declare root
root="$(dirname "$(dirname "$(readlink -f "$0")")")"

declare runtime

if command -v docker > /dev/null; then
  runtime="docker"
elif command -v podman > /dev/null; then
  runtime="podman"
else
  echo "error: no container runtime found" >&2
  exit 1
fi

declare -a args
args=("-i" "--rm" "--workdir" "/src" "--network" "none" "--user" "$(id -u):$(id -g)")

if [[ "$("${runtime}" version)" =~ Podman ]]; then
  runtime="podman"

  args+=("--userns" "keep-id")

  if [[ "$(podman info | yq4 '.host.security.selinuxEnabled')" == "true" ]]; then
    args+=("--mount" "type=bind,src=${root},dst=/src,relabel=shared")
  else
    args+=("--mount" "type=bind,src=${root},dst=/src")
  fi
else
  args+=("--mount" "type=bind,src=/etc/passwd,dst=/etc/passwd,ro")
  args+=("--mount" "type=bind,src=/etc/group,dst=/etc/group,ro")

  args+=("--mount" "type=bind,src=${root},dst=/src")
fi

"${runtime}" run "${args[@]}" "${@}"
