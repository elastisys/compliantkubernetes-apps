#!/usr/bin/env bash

# Helpers to run docker or podman from within tests

ctr() {
  if docker version >/dev/null 2>&1; then
    docker "${@}"
  else
    podman "${@}"
  fi
}

ctr.insecure() {
  if docker version >/dev/null 2>&1; then
    echo "${ctr_insecure+"--tlsverify=false"}"
  else
    echo "${ctr_insecure+"--tls-verify=false"}"
  fi
}
