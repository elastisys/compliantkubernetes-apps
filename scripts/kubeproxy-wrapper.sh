#!/usr/bin/env bash

# Starts a `kubectl proxy` process in the background
# and continually "prods" it with curl until the port 127.0.0.1:8000 becomes open,
# a good indication that further authentication is needed.
#
# Then, it extracts the Dex redirect URL from visiting http://127.0.0.1:8000
# and outputs a "ready" marker along with the extracted URL.
#
# TODO - randomized ports

set -euo pipefail

PROXY_READY_MARKER='%%PROXY_READY%%'

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
  if nc -z 127.0.0.1 8000; then
    redir_url="$(curl --silent -i http://127.0.0.1:8000/ | grep --only-matching --perl-regexp 'Location: \K.+')"
    echo "$PROXY_READY_MARKER $redir_url"
    break
  fi
  sleep 1
done

wait
