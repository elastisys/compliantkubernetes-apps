#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

environment=$1

# Somewhat ugly, but Helm will not support labeling namespaces
# https://github.com/helm/helm/issues/3503
helmfile -f "${here}/helmfile/helmfile.yaml" \
    -e "${environment}" template  | kubectl apply -f -
