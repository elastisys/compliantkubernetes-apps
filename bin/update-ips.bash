#!/bin/bash

# This script synchronizes the network policy configuration.

# Usage: update-ips.bash <cluster> <apply|dry-run>
#   cluster: What cluster config to check for (sc, wc or both).
#   apply: Update the config.
#   dry-run: Output the diff, don't update the config.

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

check_cluster="${1}" # sc, wc or both
dry_run=true
if [[ "${2}" == "apply" ]]; then
  dry_run=false
fi
has_diff=0

# Get the value of the config option or the provided default value if the
# config option is unset.
#
# Usage: yq_read <cluster> <config_option> <default_value>
yq_read() {
  local cluster="${1}"
  local config_option="${2}"
  local default_value="${3}"

  local value

  for config_file in "${config["override_${cluster}"]}" \
                      "${config["override_common"]}" \
                      "${config["default_${cluster}"]}" \
                      "${config["default_common"]}"
  do
    value=$(yq4 "${config_option}" "${config_file}")

    if [[ "${value}" != "null" ]]; then
      echo "${value}"
      return
    fi
  done

  echo "${default_value}"
}

# Get the value of the secrets config option or the provided default value if
# the secrets config option is unset.
#
# Usage: yq_read_secret <config_option> <default_value>
yq_read_secret() {
  local config_option="${1}"
  local default_value="${2}"

  local value
  value=$(sops -d "${secrets["secrets_file"]}" | yq4 "${config_option}")

  if [[ "${value}" != "null" ]]; then
    echo "${value}"
    return
  fi

  echo "${default_value}"
}

# Execute a yq expression on a config file.
#
# Usage: yq_eval <config_file> <config_option> <expression>
yq_eval() {
  local config_file="${1}"
  local config_option="${2}"
  local expression="${3}"

  local config_filename="${config_file//${CK8S_CONFIG_PATH}\//}"

  local out
  if ${dry_run}; then
    out=/dev/stdout
  else
    out=/dev/null
  fi

  diff -U3 --color=always \
      --label "${config_filename}" <(yq4 -P "${config_file}") \
      --label expected <(yq4 -P "${expression}" "${config_file}") > "${out}" && return

  if ${dry_run}; then
    log_warning "Diff found for ${config_option} in ${config_filename} (diff shows actions needed to be up to date)"
  else
    yq4 -i "${expression}" "${config_file}"
  fi

  has_diff=$((has_diff + 1))
}

# Determine if Swift is enabled in the configuration.
swift_enabled() {
  [ "$(yq_read "sc" '.harbor.persistence.type' "false")" = "swift" ] && return 0
  [ "$(yq_read "sc" '.thanos.objectStorage.type' "false")" = "swift" ] && return 0
  for source_type in $(yq_read "sc" '.objectStorage.sync.buckets.[].sourceType' ""); do
    [ "${source_type}" = "swift" ] && return 0
  done
  return 1
}

# Determine if Rsync is enabled in the configuration.
rsync_enabled() {
  [ "$(yq_read "sc" '.objectStorage.sync.enabled' "false")" = "true" ] && \
    [ "$(yq_read "sc" '.networkPolicies.rcloneSync.enabled' "false")" = "true" ]
}

# Fetch the InternalIP, Calico tunnel IP and Wireguard IP of Kubernetes
# nodes using a label selector.
#
# If the label selector isn't specified, all nodes will be returned.
#
# Usage: get_kubectl_ips <cluster> <label>
get_kubectl_ips() {
  local cluster="${1}"
  local label="${2}"

  local label_argument=""
  if [[ "${label}" != "" ]]; then
    label_argument="-l ${label}"
  fi

  local -a ips_internal
  local -a ips_calico
  local -a ips_wireguard
  mapfile -t ips_internal < <("${here}/ops.bash" kubectl "${cluster}" get node "${label_argument}" -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
  mapfile -t ips_calico < <("${here}/ops.bash" kubectl "${cluster}" get node "${label_argument}" -o jsonpath='{.items[*].metadata.annotations.projectcalico\.org/IPv4IPIPTunnelAddr}')
  mapfile -t ips_wireguard < <("${here}/ops.bash" kubectl "${cluster}" get node "${label_argument}" -o jsonpath='{.items[*].metadata.annotations.projectcalico\.org/IPv4WireguardInterfaceAddr}')

  local -a ips
  read -r -a ips <<< "${ips_internal[*]} ${ips_calico[*]} ${ips_wireguard[*]}"

  if [ ${#ips[@]} -eq 0 ]; then
    log_error "No IPs for ${cluster} nodes with label ${label} was found"
    exit 1
  fi

  echo "${ips[@]}"
}

# Fetch the IPs from a domain.
#
# Usage: get_dns_ips <domain>
get_dns_ips() {
  local domain="${1}"

  local -a ips
  mapfile -t ips < <(dig +short "${domain}" | grep '^[.0-9]*$')
  if [ ${#ips[@]} -eq 0 ]; then
    log_error "No IPs for ${domain} was found"
    exit 1
  fi
  echo "${ips[@]}"
}

# Fetch the Swift URL.
#
# Usage: get_swift_url <swift_config_option>
get_swift_url() {
  local swift_config_option="${1}"

  local auth_url
  local os_token
  local swift_url
  local swift_region
  local response

  auth_url="$(yq_read "sc" "${swift_config_option}.authUrl" "")"
  swift_region="$(yq_read "sc" "${swift_config_option}.region" "")"

  if [ -n "$(yq_read_secret "${swift_config_option}.username" "")" ]; then
    response=$(curl -i -s -H "Content-Type: application/json" -d '
        {
          "auth": {
            "identity": {
              "methods": ["password"],
              "password": {
                "user": {
                  "name": "'"$(yq_read_secret "${swift_config_option}.username" '""')"'",
                  "domain": { "name": "'"$(yq_read "sc" "${swift_config_option}.domainName" '""')"'" },
                  "password": "'"$(yq_read_secret "${swift_config_option}.password" '""')"'"
                }
              }
            },
            "scope": {
              "project": {
                "name": "'"$(yq_read "sc" "${swift_config_option}.projectName" '""')"'",
                "domain": { "name": "'"$(yq_read "sc" "${swift_config_option}.projectDomainName" '""')"'" }
              }
            }
          }
        }' "${auth_url}/auth/tokens")
  elif [ -n "$(yq_read_secret "${swift_config_option}.applicationCredentialID" "")" ]; then
    response=$(curl -i -s -H "Content-Type: application/json" -d '
        {
          "auth": {
            "identity": {
              "methods": ["application_credential"],
              "application_credential": {
                "id": "'"$(yq_read_secret "${swift_config_option}.applicationCredentialID" '""')"'",
                "secret": "'"$(yq_read_secret "${swift_config_option}.applicationCredentialSecret" '""')"'"
              }
            }
          }
        }' "${auth_url}/auth/tokens")
  fi

  os_token=$(echo "${response}" | grep -oP "x-subject-token:\s+\K\S+")
  swift_url=$(echo "${response}" | tail -n +15 | jq -r '.[].catalog[] | select( .type == "object-store" and .name == "swift") | .endpoints[] | select(.interface == "public" and .region == "'"${swift_region}"'") | .url')

  curl -i -s -X DELETE -H "X-Auth-Token: ${os_token}" -H "X-Subject-Token: ${os_token}" "${auth_url}/auth/tokens" >/dev/null

  echo "${swift_url}"
}

# Sort IP addresses.
#
# For example, [1.0.0.10, 1.0.0.2] would be reordered to [1.0.0.2, 1.0.0.10].
sort_ips() {
  python3 -c "import ipaddress; import sys; ips = [ipaddress.ip_address(ip) for ip in sys.argv[1:]]; ips.sort(); [print(ip) for ip in ips]" "${@}"
}

# Check if an IP address is part of a CIDR address block.
#
# Usage: check_ip_in_cidr <ip> <cidr>
check_ip_in_cidr() {
  local ip="${1}"
  local cidr="${2}"

  python3 -c "import ipaddress; exit(0) if ipaddress.ip_address('${ip}') in ipaddress.ip_network('${cidr}') else exit(1)"
}

# Returns CIDRs that are filtered so that:
# 1. Old CIDR entries are returned with existing suffix if it contains new IPs.
# 2. New CIDR entries are returned with a /32 suffix.
# 3. Returned CIDRs are sorted and unique.
#
# Usage: process_ips_to_cidrs <config_file> <config_option> <ip> [<ip> ...]
process_ips_to_cidrs() {
  local config_file="${1}"
  local config_option="${2}"
  shift 2

  local -a new_cidrs
  local -a old_cidrs

  readarray -t old_cidrs <<< "$(yq4 "${config_option} | .[]" "${config_file}")"

  for ip in "${@}"; do
    for cidr in "${old_cidrs[@]}"; do
      if [[ "${cidr}" != "" ]] && ! [[ "${cidr}" =~ .*/32 ]] && check_ip_in_cidr "${ip}" "${cidr}"; then
        new_cidrs+=("${cidr}")
        continue 2
      fi
    done

    new_cidrs+=("${ip}/32")
  done

  yq4 'split(" ") | unique | .[]' <<< "${new_cidrs[@]}"
}

# Parse the host from an URL.
parse_url_host() {
  echo "${1}" | sed 's/https\?:\/\///' | sed 's/[:\/].*//'
}

# Parse the port from an URL.
#
# Usage: parse_url_port <url> <default_port>
parse_url_port() {
  port="$(echo "${1}" | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"
  [ -z "${port}" ] && port="${2}"
  echo "${port}"
}

# Updates the configuration to allow IPs.
#
# Usage: allow_ips <config_file> <config_option> <ip> [<ip> ...]
allow_ips() {
  local config_file="${1}"
  local config_option="${2}"
  shift 2

  local -a ips
  readarray -t ips <<< "$(sort_ips "${@}")"

  local -a cidrs
  readarray -t cidrs <<< "$(process_ips_to_cidrs "${config_file}" "${config_option}" "${ips[@]}")"

  local list
  list=$(echo "[$(for v in "${cidrs[@]}"; do echo "${v},"; done)]" | yq4 -oj)

  yq_eval "${config_file}" "${config_option}" "${config_option} = ${list}"
}

# Updates the configuration to allow ports.
#
# Usage: allow_ports <config_file> <config_option> <port> [<port> ...]
allow_ports() {
  local config_file="${1}"
  local config_option="${2}"
  shift 2

  local ports
  ports=$(echo "[$(for v in "${@}"; do echo "${v},"; done)]" | yq4 -oj sort)

  yq_eval "${config_file}" "${config_option}" "${config_option} = ${ports}"
}

# Updates the configuration to allow the IPs of the domain.
#
# Usage: allow_domain <config_file> <config_option> <dns_record>
allow_domain() {
  local config_file="${1}"
  local config_option="${2}"
  local dns_record="${3}"

  local -a ips dns_ips
  dns_ips=$(get_dns_ips "${dns_record}")
  readarray -t ips <<< "$(echo "${dns_ips}" | tr ' ' '\n')"

  allow_ips "${config_file}" "${config_option}" "${ips[@]}"
}

# Check if a string is a valid IP address.
#
# Usage: is_ip_address <string>
is_ip_address() {
  python3 -c "import ipaddress; import sys; ipaddress.ip_address(sys.argv[1])" "${1}" > /dev/null 2>&1
}

# Updates the configuration to allow the host domain or IP address.
#
# Usage: allow_host <config_file> <config_option> <host>
allow_host() {
  local config_file="${1}"
  local config_option="${2}"
  local host="${3}"

  if is_ip_address "${host}"; then
    allow_ips "${config_file}" "${config_option}" "${host}"
  else
    allow_domain "${config_file}" "${config_option}" "${host}"
  fi
}

# Updates the configuration to allow the IPs of Kubernetes nodes.
#
# If the node label is empty all nodes are allowed.
#
# Usage: allow_nodes <cluster> <config_option> <node_label>
allow_nodes() {
  local cluster="${1}"
  local config_option="${2}"
  local label="${3}"

  local config_file="${config["override_${cluster}"]}"

  local -a ips kubectl_ips
  kubectl_ips=$(get_kubectl_ips "${cluster}" "${label}")
  readarray -t ips <<< "$(echo "${kubectl_ips}" | tr ' ' '\n')"

  allow_ips "${config_file}" "${config_option}" "${ips[@]}"
}

# Allow object storage in the common network policy configuration.
allow_object_storage() {
  local cluster="${check_cluster}"
  if [ "${check_cluster}" == "both" ]; then
    cluster="sc"
  fi

  local url
  local host
  local port
  url=$(yq_read "${cluster}" '.objectStorage.s3.regionEndpoint' "")
  host=$(parse_url_host "${url}")
  port=$(parse_url_port "${url}" 443)

  allow_host "${config["override_common"]}" '.networkPolicies.global.objectStorage.ips' "${host}"
  allow_ports "${config["override_common"]}" '.networkPolicies.global.objectStorage.ports' "${port}"
}

# Allow ingresses in the common network policy configuration.
allow_ingress() {
  local cluster="${check_cluster}"
  if [ "${check_cluster}" == "both" ]; then
    cluster="sc"
  fi

  local base_domain
  local ops_domain
  base_domain="$(yq_read "${cluster}" '.global.baseDomain' "")"
  ops_domain="$(yq_read "${cluster}" '.global.opsDomain' "")"

  allow_domain "${config["override_common"]}" '.networkPolicies.global.scIngress.ips' "grafana.${ops_domain}"
  allow_domain "${config["override_common"]}" '.networkPolicies.global.wcIngress.ips' "non-existing-subdomain.${base_domain}"
}

# Synchronize the Swift object storage network policy configuration.
#
# If the endpoint config option is unset the existing network policy
# configuration is removed.
#
# Usage: sync_swift <swift_config_option> <netpol_config_option>
sync_swift() {
  local swift_config_option="${1}"
  local netpol_config_option="${2}"

  local os_auth_url
  local os_auth_host
  local os_auth_port
  os_auth_url="$(yq_read "sc" "${swift_config_option}.authUrl" "")"

  if [ -z "${os_auth_url}" ]; then
    yq_eval "${config["override_sc"]}" "${netpol_config_option}" 'del('"${netpol_config_option}"')'
    return
  fi

  os_auth_host=$(parse_url_host "${os_auth_url}")
  os_auth_port=$(parse_url_port "${os_auth_url}" 5000)

  local -a object_storage_swift_ips
  local -a object_storage_swift_ports

  # shellcheck disable=SC2207
  object_storage_swift_ips+=($(get_dns_ips "${os_auth_host}"))
  object_storage_swift_ports+=("${os_auth_port}")

  local swift_url
  local swift_host
  local swift_port
  swift_url="$(get_swift_url "${swift_config_option}")"
  swift_host=$(parse_url_host "${swift_url}")
  swift_port=$(parse_url_port "${swift_url}" 443)

  # shellcheck disable=SC2207
  object_storage_swift_ips+=($(get_dns_ips "${swift_host}"))
  object_storage_swift_ports+=("${swift_port}")

  allow_ips "${config["override_sc"]}" "${netpol_config_option}.ips" "${object_storage_swift_ips[@]}"
  allow_ports "${config["override_sc"]}" "${netpol_config_option}.ports" "${object_storage_swift_ports[@]}"
}

# Synchronize the Rclone sync network policy configuration.
#
# If the endpoint config option is unset the existing network policy
# configuration is removed.
#
# Usage: sync_rclone <endpoint_config_option> <netpol_config_option>
sync_rclone() {
  local endpoint_config_option="${1}"
  local netpol_config_option="${2}"

  local url
  local host
  local port
  url=$(yq_read "sc" "${endpoint_config_option}" "")
  host=$(parse_url_host "${url}")
  port=$(parse_url_port "${url}" 443)

  if [ -n "${host}" ]; then
    allow_domain "${config["override_sc"]}" "${netpol_config_option}.ips" "${host}"
    allow_ports "${config["override_sc"]}" "${netpol_config_option}.ports" "${port}"
    return
  fi

  yq_eval "${config["override_sc"]}" "${netpol_config_option}" 'del('"${netpol_config_option}"')'
}

# TODO: Remove when config validation is in-place.
# https://github.com/elastisys/compliantkubernetes-apps/issues/1427
validate_config() {
  yq_read_required() {
    local cluster="${1}"
    local config_option="${2}"

    local value

    value=$(yq_read "${cluster}" "${config_option}" "")

    if [ -z "${value}" ]; then
      log_error "${config_option} is not configured, check your common-config.yaml (or ${cluster}-config.yaml)"
      exit 1
    fi
  }

  local cluster="${check_cluster}"
  if [ "${check_cluster}" == "both" ]; then
    cluster="sc"
  fi

  yq_read_required "${cluster}" '.objectStorage.s3.regionEndpoint'
  yq_read_required "${cluster}" '.global.opsDomain'
  yq_read_required "${cluster}" '.global.baseDomain'

  if swift_enabled; then
    yq_read_required "sc" '.objectStorage.swift.authUrl'
    yq_read_required "sc" '.objectStorage.swift.region'
    if [ -z "$(yq_read_secret '.objectStorage.swift.username' "")" ] && [ -z "$(yq_read_secret '.objectStorage.swift.applicationCredentialID' "")" ]; then
      log_error "No Swift username or application credential ID, check your secrets.yaml"
      exit 1
    fi
  fi

  rsync_enabled || return 0

  local destination_s3=false
  local destination_swift=false

  local sync_default_buckets
  local sync_destination_type
  local harbor_persistence_type
  local thanos_object_storage_type
  local bucket_destination_types

  sync_default_buckets="$(yq_read "sc" '.objectStorage.sync.syncDefaultBuckets' "false")"
  sync_destination_type="$(yq_read "sc" '.objectStorage.sync.destinationType' "")"
  harbor_persistence_type="$(yq_read "sc" '.harbor.persistence.type' "false")"
  thanos_object_storage_type="$(yq_read "sc" '.thanos.objectStorage.type' "false")"
  bucket_destination_types=$(yq_read "sc" '.objectStorage.sync.buckets.[].destinationType' "")

  if [ "${sync_default_buckets}" == "true" ]; then
    if [ "${harbor_persistence_type}" == "swift" ] || [ "${thanos_object_storage_type}" == "swift" ]; then
        destination_swift=true
    fi
  fi
  for bucket_type in ${bucket_destination_types}; do
    if [ "${bucket_type}" == "swift" ]; then
      destination_swift=true
    elif [ "${bucket_type}" == "s3" ]; then
      destination_s3=true
    fi
  done

  if [ "${destination_s3}" == "true" ] || [ "${sync_destination_type}" == "s3" ]; then
    yq_read_required "sc" '.objectStorage.sync.s3.regionEndpoint'
  fi

  if [ "${destination_swift}" == "true" ] || [ "${sync_destination_type}" == "swift" ]; then
    yq_read_required "sc" '.objectStorage.sync.swift.authUrl'
    if [ -z "$(yq_read_secret '.objectStorage.sync.swift.username' "")" ] && [ -z "$(yq_read_secret '.objectStorage.sync.swift.applicationCredentialID' "")" ]; then
      log_error "No RClone sync Swift username or application credential ID, check your secrets.yaml"
      exit 1
    fi
  fi
}

validate_config

allow_object_storage

allow_ingress

if [[ "${check_cluster}" =~ ^(sc|both)$ ]]; then
  allow_nodes "sc" '.networkPolicies.global.scApiserver.ips' "node-role.kubernetes.io/control-plane="
  allow_nodes "sc" '.networkPolicies.global.scNodes.ips' ""

  if swift_enabled; then
    sync_swift '.objectStorage.swift' '.networkPolicies.global.objectStorageSwift'
  fi
fi

if [[ "${check_cluster}" =~ ^(wc|both)$ ]]; then
  allow_nodes "wc" '.networkPolicies.global.wcApiserver.ips' "node-role.kubernetes.io/control-plane="
  allow_nodes "wc" '.networkPolicies.global.wcNodes.ips' ""
fi

if rsync_enabled; then
  sync_rclone '.objectStorage.sync.s3.regionEndpoint' '.networkPolicies.rcloneSync.destinationObjectStorageS3'
  sync_swift '.objectStorage.sync.swift' '.networkPolicies.rcloneSync.destinationObjectStorageSwift'
  sync_rclone '.objectStorage.sync.secondaryUrl' '.networkPolicies.rcloneSync.secondaryUrl'
fi

exit ${has_diff}
