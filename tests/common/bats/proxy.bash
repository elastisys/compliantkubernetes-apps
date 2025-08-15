#!/usr/bin/env bash

# Manages the lifecycle of 'kubectl proxy' processes.
# The ports used are:
# - 18001 for SC
# - 18002 for WC

proxy_pids=()

proxy.start_proxy() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  fi

  # TODO - .user.adminUsers precondition for WC
  local port
  case "${1}" in
  sc) port="18001" ;;
  wc) port="18002" ;;
  *) return ;;
  esac

  if ! nc -z 127.0.0.1:"${port}"; then
    echo -e "\033[1m[Starting kube proxy on ${1}]\033[0m" >&3
    kubectl proxy --port="${port}" --keepalive=3s 3>&- &
    proxy_pids+=($!)
  fi
  curl --silent --retry 10 --retry-all-errors http://127.0.0.1:"${port}"/healthz
}

proxy.stop_all() {
  echo -e "\033[1m[Stopping all kube proxies]\033[0m" >&3
  local pid
  for pid in "${proxy_pids[@]}"; do
    kill "${pid}" || true
  done
}
