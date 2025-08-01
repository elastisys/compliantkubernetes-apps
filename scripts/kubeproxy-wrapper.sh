#!/usr/bin/env bash

# Starts a `kubectl proxy` process in the background and continually "prods" it
# with curl until either:
#
# - the port 127.0.0.1:8001 becomes open, a good indication that the proxy is ready,
#   in which case we emit the PROXY_READY_MARKER;
#
# - the port 127.0.0.1:8000 becomes open, a good indication that further (dex)
#   authentication is needed. In this case, it extracts the Dex redirect URL from visiting
#   http://127.0.0.1:8000 and outputs the PROXY_WAITING_FOR_DEX_MARKER along with the
#   redirect URL.

set -euo pipefail

PROXY_READY_MARKER='%%PROXY_READY%%'
PROXY_WAITING_FOR_DEX_MARKER='%%PROXY_WAITING_FOR_DEX%%'

cleanup() {
  if [[ -n "$proxy_pid" ]] && kill -0 "$proxy_pid" 2>/dev/null; then
    kill "$proxy_pid"
  fi
  if [[ -n "$curl_pid" ]] && kill -0 "$curl_pid" 2>/dev/null; then
    kill "$curl_pid"
  fi
  exit 0
}

trap cleanup EXIT INT TERM

kubectl proxy 2>&1 &
proxy_pid=$!

curl --silent --retry 10 --retry-all-errors http://127.0.0.1:8001/healthz 2>&1 &
curl_pid=$!

# wait until port 8000 is open
for _ in $(seq 1 30); do
  if ! kill -0 "${curl_pid}" >/dev/null 2>&1; then
    # must've already authenticated, emit READY marker without redirect url and break
    echo "$PROXY_READY_MARKER"
    break
  fi
  if nc -z 127.0.0.1 8000; then
    dex_url="$(curl --silent -i http://127.0.0.1:8000/ | grep --only-matching --perl-regexp 'Location: \K.+')"
    # waiting for local authentication through Dex
    echo "$PROXY_WAITING_FOR_DEX_MARKER $dex_url"
    break
  fi
  sleep 1
done

wait
