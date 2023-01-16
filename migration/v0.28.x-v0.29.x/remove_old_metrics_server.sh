#!/bin/bash

set -eo pipefail

./bin/ck8s ops helmfile sc -f helmfile -l app=metrics-server -i destroy

./bin/ck8s ops helmfile wc -f helmfile -l app=metrics-server -i destroy
