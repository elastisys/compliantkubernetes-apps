#!/usr/bin/env bash

install_storage_class_provider() {
    : "${storageclass_path:?Missing storageclass path}"
    case "${1}" in
    "nfs-client")
        echo "Install nfs-client-provisioner" >&2
        helmfile -f "${storageclass_path}/helmfile/helmfile.yaml" \
            -e "${2}" -l app=nfs-client-provisioner apply --suppress-diff
    ;;
    "local-storage")
        echo "Install local-storage storage class" >&2
        kubectl apply -f "${storageclass_path}/manifests/local-storage-class.yaml"

        echo "Install local-volume-provisioner" >&2
        helmfile -f "${storageclass_path}/helmfile/helmfile.yaml" \
            -e "${2}" -l app=local-volume-provisioner apply --suppress-diff
    ;;
    "cinder-storage")
        storage=$(kubectl get storageclasses.storage.k8s.io -o json | jq '.items[].metadata | select(.name == "cinder-storage") | .name')
        if [ -z "${storage}" ]; then
            echo "Install cinder-storage storage class" >&2
            kubectl apply -f "${storageclass_path}/manifests/cinder-storage.yaml"
        fi
    ;;
    "ebs-gp2")
        storage=$(kubectl get storageclasses.storage.k8s.io -o json | jq '.items[].metadata | select(.name == "ebs-gp2") | .name')
        if [ -z "${storage}" ]; then
            echo "Install EBS GP2 storage class" >&2
            kubectl apply -f "${storageclass_path}/manifests/ebs-gp2.yaml"
        fi
    ;;
    esac
}
