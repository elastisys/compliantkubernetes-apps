#!/usr/bin/env bash

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

if "${here}/../../bin/ck8s" ops helm wc uninstall hnc -n hnc-system ; then
    "${here}/../../bin/ck8s" ops kubectl wc delete hncconfigurations.hnc.x-k8s.io config
    "${here}/../../bin/ck8s" ops helmfile wc -l group=hnc apply
else
    printf "\nCheck that the hnc -n hnc-system helm release (not helmfile) was properly removed"
    printf "\nAlso check that the k8s resources were removed (deployments, services, hooks)"
    printf "\nIf the release and resources were removed then you may proceed\n"
    read -r -p 'Continue? [y/N] ' response
    if [[ "${response}" == [yY] ]] ; then
        "${here}/../../bin/ck8s" ops kubectl wc delete hncconfigurations.hnc.x-k8s.io config
        "${here}/../../bin/ck8s" ops helmfile wc -l group=hnc apply
    else
        printf "Exiting..."
        exit 0
    fi
fi
