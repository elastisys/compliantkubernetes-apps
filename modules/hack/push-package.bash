#!/bin/bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

name="${1}"
version="${2:-latest}"

repository="harbor.long-running.dev-ck8s.com/apps-crossplane-poc"

pushd "${here}/../${name}" >/dev/null

crossplane xpkg build --ignore definition-gen.yaml -o "/tmp/${name}.xpkg"
trap 'rm "/tmp/${name}.xpkg"' EXIT

crossplane xpkg push -f "/tmp/${name}.xpkg" "${repository}/${name}:${version}"

popd >/dev/null
