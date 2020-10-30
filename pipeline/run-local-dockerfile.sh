#!/bin/bash
# This script builds and runs the dev docker file with mounted Home directory.
set -e
SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"

docker build -t elastisys/ck8s-ops:latest "${SCRIPTS_PATH}"
docker build -t ck8s-ops -f "${SCRIPTS_PATH}/Dockerfile.dev" "${SCRIPTS_PATH}"
docker run \
    -ti \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -u "$(id -u):$(id -g)" \
    -v "$HOME:$HOME" \
    -e GPG_TTY=/dev/pts/0 \
    --entrypoint /bin/bash \
    -w "$(pwd)" \
    ck8s-ops
