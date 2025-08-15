#!/usr/bin/env bash

# Manages the lifecycle of 'kubectl proxy' processes.
#
# Proxies are started on random ports, and their port numbers are passed back
# to the Cypress layer via the <SC|WC>_PROXY_PORT environment variables.

proxy_pids=()

# Usage: proxy.start_proxy <wc|sc>
proxy.start_proxy() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  fi

  # TODO - .user.adminUsers precondition for WC

  local -r fifo="${TMPDIR:-/tmp}/kube-proxy-fifo-${RANDOM}"
  mkfifo "$fifo"

  echo -e "\033[1m[Starting kube proxy for ${1}]\033[0m" >&3
  kubectl proxy --port=0 --keepalive=3s >"$fifo" 2>&1 &
  proxy_pids+=($!)

  local -r port=$(grep -m 1 -oP "serve on \S*:\K[0-9]+" "$fifo")
  rm -f "$fifo"

  curl --silent --retry 10 --retry-all-errors "http://127.0.0.1:${port}/healthz"

  echo -e "\033[1m[Kube proxy for ${1} started on port=${port}]\033[0m" >&3

  case "${1}" in
  sc) export SC_PROXY_PORT="${port}" ;;
  wc) export WC_PROXY_PORT="${port}" ;;
  *) return ;;
  esac
}

# Usage: proxy.stop_all
proxy.stop_all() {
  echo -e "\033[1m[Stopping all kube proxies]\033[0m" >&3
  local pid
  for pid in "${proxy_pids[@]}"; do
    kill "${pid}" || true
  done
}
