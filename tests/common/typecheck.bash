#!/usr/bin/env bash

# Typecheck the cypress tests .cy.js files against type stubs from cypress/index.d.ts
#
# This file is not meant to be run directly, but is called by a pre-commit hook.

set -euo pipefail

declare tests
tests="$(dirname "$(dirname "$(readlink -f "$0")")")"

is_jammy() {
  [[ -f /etc/os-release ]] && [[ "$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)" == "22.04" ]]
}

export PATH="${PATH}:${tests}/node_modules/.bin"

checker=""
command -v tsc >/dev/null 2>&1 && checker="tsc"

# Ubuntu 22.04 doesn't like native typescript, so just use 'tsc'
if ! is_jammy; then
  command -v tsgo >/dev/null 2>&1 && checker="tsgo"
fi

if [[ -z "${checker}" ]]; then
  echo "Fatal: neither 'tsc' nor 'tsgo' could be found, run: npm install" >&2
  exit 1
fi

pushd "${tests}" >/dev/null 2>&1 || exit 1
$checker --noEmit
popd >/dev/null 2>&1
