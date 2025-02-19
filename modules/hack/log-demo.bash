#!/bin/bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

root="${here}/../.."

"${root}/bin/ck8s" ops helmfile sc apply -l name=ingress-nginx --include-transitive-needs

# TODO: update-ips

"${root}/bin/ck8s" ops helmfile sc apply -l name=module-opensearch --include-transitive-needs

"${root}/bin/ck8s" ops helmfile sc apply -l name=opensearch-securityadmin --include-transitive-needs

"${root}/bin/ck8s" ops helmfile sc apply -l name=opensearch-configurer --include-transitive-needs

"${root}/bin/ck8s" ops helmfile wc apply -l name=module-fluentd-forwarder --include-transitive-needs

# TODO: patch secret, show propagation
