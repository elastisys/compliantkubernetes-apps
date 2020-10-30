#!/bin/bash

SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
set -e

echo Testing OPA polices
opa test "${SCRIPTS_PATH}/../../../../helmfile/charts/gatekeeper-templates/policies/" -v
