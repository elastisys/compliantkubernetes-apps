#!/bin/bash

set -euo pipefail

schema=https://raw.githubusercontent.com/kubernetes/kubernetes/refs/heads/release-1.32/api/openapi-spec/swagger.json

docker run --rm redocly/cli bundle --dereferenced "${schema}" | yq4 -o json '.definitions["'"${1}"'"]' | yq4 --prettyPrint
