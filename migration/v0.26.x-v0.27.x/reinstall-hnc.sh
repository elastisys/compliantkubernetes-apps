#!/bin/bash

set -e

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

"${here}/../../bin/ck8s" ops helm wc uninstall hnc -n hnc-system
"${here}/../../bin/ck8s" ops kubectl wc delete hncconfigurations.hnc.x-k8s.io config
"${here}/../../bin/ck8s" ops helmfile wc -l group=hnc apply
