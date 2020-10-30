#!/bin/bash

# This is an abstraction of SOPS that makes it possible to share CK8S secrets.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${here}/common.bash"

declare -a split_fingerprints

# Join a list.
# join_by - a b c # a-b-c
join_by() { local IFS="${1}"; shift; echo "${*}"; }

# Load fingerprints from the SOPS config file into `split_fingerprints`.
sops_load_fingerprints() {
    : "${sops_config:?Missing sops config}"
    fingerprints=$(yq r - 'creation_rules[0].pgp' < "$sops_config")
    IFS=',' read -r -a split_fingerprints <<< "${fingerprints}"
}

# Write the fingerprints in `split_fingerprints` in the SOPS config file.
sops_save_fingerprints() {
    fingerprints="$(join_by , "${split_fingerprints[@]}")"
    sops_config_write_fingerprints "${fingerprints}"
}

# Add a PGP fingerprint to the SOPS config file if it doesn't already exist.
sops_add_pgp() {
    sops_load_fingerprints

    for fingerprint in "${split_fingerprints[@]}"; do
        if [ "${1}" = "${fingerprint}" ]; then
            log_error "PGP fingerprint already in sops config: ${sops_config}"
            exit 1
        fi
    done

    split_fingerprints+=("${1}")

    log_info "Adding PGP key: ${1}"

    sops_save_fingerprints
}

# Remove a PGP fingerprint from the SOPS config file if it exists.
sops_remove_pgp() {
    sops_load_fingerprints

    found=false
    for i in "${!split_fingerprints[@]}"; do
        if [ "${1}" = "${split_fingerprints[i]}" ]; then
            unset 'split_fingerprints[i]'
            found=true
            break
        fi
    done
    if [ "${found}" != "true" ]; then
        log_error "PGP fingerprint not found in sops config: ${sops_config}"
        exit 1
    fi

    if [ "${#split_fingerprints[@]}" -eq 0 ]; then
        log_error "Refusing to remove the only remaining PGP key."
        exit
    fi

    log_info "Removing PGP key: ${1}"

    sops_save_fingerprints
}

# Update all secrets with the public keys from the fingerprints in the SOPS
# config file.
sops_update_keys() {
    : "${secrets:?Missing secrets}"
    for secret in "${secrets[@]}"; do
        if [ ! -f "${secret}" ]; then
            log_warning "Secret does not exist: ${secret}"
            continue
        fi

        log_info "Updating keys in: ${secret}"

        # sops updatekeys does not take the --config flag, need to change cwd.
        pushd "${CK8S_CONFIG_PATH}" > /dev/null
        sops updatekeys --yes "${secret}"
        popd > /dev/null
    done
}

# Rotate the data key in all secrets.
sops_rotate_data_key() {
    : "${secrets:?Missing secrets}"
    for secret in "${secrets[@]}"; do
        if [ ! -f "${secret}" ]; then
            log_warning "Secret does not exist: ${secret}"
            continue
        fi

        log_info "Rotating data key and reencrypting: ${secret}"
        sops --config "${sops_config}" -r -i "${secret}"
    done
}

# Add a fingerprint to the SOPS config file if it doesn't already exist and
# update all secrets to include the public key from the fingerprint.
# This would be like doing the following using the sops client:
# 1. Edit .sops.yaml and append fingerprint to PGP creation_rule.
# 2. Run `sops updatekeys --yes [file]` on all secrets files.
add_pgp() {
    fingerprint="${1}"

    sops_add_pgp "${fingerprint}"

    sops_update_keys
}

# Remove a fingerprint from the SOPS config file, update all the secrets and
# rotate the data key to make it no longer possible for old keys to decrypt
# the secrets.
# This would be like doing the following using the sops client:
# 1. Edit .sops.yaml and append fingerprint to PGP creation_rule.
# 2. Run `sops updatekeys --yes [file]` on all secrets files.
# 3. Run `sops -r -i [file]` on all secrets files.
remove_pgp() {
    fingerprint="${1}"

    sops_remove_pgp "${fingerprint}"

    sops_update_keys

    sops_rotate_data_key
}

case "${1}" in
    "add-pgp") add_pgp "${2}" ;;
    "remove-pgp") remove_pgp "${2}" ;;
    *)
        log_error "ERROR: ${1} is not a valid argument"
        log_error "Usage: ${0} <add-pgp|remove-pgp>"
        exit 1
        ;;
esac
