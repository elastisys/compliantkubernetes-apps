#!/usr/bin/env bash

# Helpers to run docker or podman from within tests

ctr() {
  if docker version >/dev/null 2>&1 && [[ ! "$(docker version)" =~ Podman ]]; then
    docker "${@}"
  else
    podman "${@}"
  fi
}

ctr.insecure() {
  if docker version >/dev/null 2>&1 && [[ ! "$(docker version)" =~ Podman ]]; then
    docker --tlsverify=false "${@}"
    echo "${ctr_insecure+"--tlsverify=false"}"
  else
    podman "${1}" --tls-verify=false "${@:2}"
  fi
}
