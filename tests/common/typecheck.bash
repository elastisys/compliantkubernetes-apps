#!/usr/bin/env bash

# Typecheck the cypress tests .cy.js files against type stubs from cypress/index.d.ts
#
# This file is not meant to be run directly, but is called by a pre-commit hook.
#
# The reason this exists is so that we can use the pre-commit installed cypress module
# to provide type definitions to tsc, thus avoiding installing it at runtime.

set -euo pipefail

declare tests
tests="$(dirname "$(dirname "$(readlink -f "$0")")")"

cleanup() {
  if [[ "$linked" == "1" ]]; then
    rm -f "${tests}/node_modules"
  fi
}
trap cleanup EXIT INT TERM

checker=""
command -v tsc >/dev/null 2>&1 && checker="tsc"
command -v tsgo >/dev/null 2>&1 && checker="tsgo"

linked="0"
if [[ ! -e "${tests}/node_modules" ]]; then
  ln -sf "$(dirname "$(which $checker)")/../lib/node_modules" "${tests}/node_modules"
  linked="1"
fi

if [[ -z "${checker}" ]]; then
  echo "Fatal: neither 'tsc' nor 'tsgo' could be found" >&2
  exit 1
fi

pushd "${tests}" >/dev/null 2>&1 || exit 1
$checker
popd >/dev/null 2>&1
