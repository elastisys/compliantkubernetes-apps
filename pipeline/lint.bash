#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"

# TODO: Try to get rid of the NFS server IP.
# We need to set the NFS server IP on Exoscale for the nfs-provisioner.
NFS_SC_SERVER_IP=127.0.0.1 helmfile -e service_cluster -f "${here}/../helmfile/" lint
NFS_WC_SERVER_IP=127.0.0.1 helmfile -e workload_cluster -f "${here}/../helmfile/" lint

helmfile -e service_cluster -f "${here}/../bootstrap/namespaces/helmfile/" lint
helmfile -e workload_cluster -f "${here}/../bootstrap/namespaces/helmfile/" lint

NFS_SC_SERVER_IP=127.0.0.1 helmfile -e service_cluster -f "${here}/../bootstrap/storageclass/helmfile/" lint
NFS_WC_SERVER_IP=127.0.0.1 helmfile -e workload_cluster -f "${here}/../bootstrap/storageclass/helmfile/" lint
