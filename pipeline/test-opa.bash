#!/bin/bash

set -eu

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

echo Testing OPA polices

opa test -v "${here}/../helmfile/charts/gatekeeper-templates/policies/"
