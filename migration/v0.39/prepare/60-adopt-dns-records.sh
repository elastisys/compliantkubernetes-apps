#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "Adopt DNS records for external-dns"

if yq_check common .externalDns.enabled true || yq_check sc .externalDns.enabled true || yq_check wc .externalDns.enabled true; then
  log_info_no_newline "Exteranl DNS is enabled, do you want to adopt DNS records? (Y/n): "
  read -r reply
  if [[ ! "${reply:-y}" =~ ^[yY]$ ]]; then
    exit 1
  fi
else
  log_info "External Dns is not enabled, skipping."
  exit 0
fi

hostedZoneId="${CK8S_HOSTED_ZONE_ID:-""}"
if [[ -z "${hostedZoneId}" ]]; then
  log_info_no_newline "Enter the hosted zone id: "
  read -r reply
  if [[ -z "${reply}" ]]; then
    log_fatal "No hosted zone id entered! Exiting."
  fi
  hostedZoneId="${reply}"
fi

log_info "Adopting DNS records..."
log_info "Fetching AWS credentials..."
if check_sops "$CK8S_CONFIG_PATH/secrets.yaml"; then
  aws_access_key_id=$(yq4 -r '.externalDns.awsRoute53.accessKey' <(sops -d "$CK8S_CONFIG_PATH/secrets.yaml"))
  aws_secret_key_id=$(yq4 -r '.externalDns.awsRoute53.secretKey' <(sops -d "$CK8S_CONFIG_PATH/secrets.yaml"))
else
  # shellcheck disable=SC2034
  aws_access_key_id=$(yq4 -r '.externalDns.awsRoute53.accessKey' "$CK8S_CONFIG_PATH/secrets.yaml")
  # shellcheck disable=SC2034
  aws_secret_key_id=$(yq4 -r '.externalDns.awsRoute53.secretKey' "$CK8S_CONFIG_PATH/secrets.yaml")
fi

if [[ "${aws_access_key_id}" == "null" ]] || [[ "${aws_secret_key_id}" == "null" ]]; then
  log_fatal "Missing AWS credentials!"
fi

export AWS_ACCESS_KEY_ID="${aws_access_key_id}"
export AWS_SECRET_ACCESS_KEY="${aws_secret_key_id}"

log_info "Fetching records..."
records=$(mktemp --suffix="aws_records.json")
aws route53 list-resource-record-sets --hosted-zone-id "${hostedZoneId}" --output json >"${records}"

log_info "Filtering..."
baseDomain=$(yq4 ".global.baseDomain" "$CK8S_CONFIG_PATH/common-config.yaml")
baseDomainRecords=$(jq ".ResourceRecordSets[] | select(.Name | test(\".*.${baseDomain}.$\"))" "${records}")
ARecords=$(echo "${baseDomainRecords}" | jq '. | select(.Type == "A")')
readarray -t recordNames < <(echo "${ARecords}" | jq -r '.Name')

log_info "Fetching txtOwnerId..."
ownerId=$(yq4 ".externalDns.txtOwnerId" <(yq_merge "$CK8S_CONFIG_PATH/common-config.yaml" "$CK8S_CONFIG_PATH/sc-config.yaml" "$CK8S_CONFIG_PATH/wc-config.yaml"))
if [[ "${ownerId}" == "null" ]]; then
  log_fatal "Missing txtOwnerId!"
fi

log_info "Fetching txtPrefix..."
txtPrefix=$(yq4 ".externalDns.txtPrefix" <(yq_merge "$CK8S_CONFIG_PATH/common-config.yaml" "$CK8S_CONFIG_PATH/sc-config.yaml" "$CK8S_CONFIG_PATH/wc-config.yaml"))
if [[ "${txtPrefix}" == "null" ]]; then
  txtPrefix=""
fi

recordFile=$(mktemp --suffix="record-file.json")
for record in "${recordNames[@]}"; do
  record="${record/\\052/"*"}"
  log_info "Creating owner record for ${record}..."
  echo "{
            \"Comment\": \"Creating owner record for ${record}\",
            \"Changes\": [
              {
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                  \"Name\": \"${txtPrefix}${record}\",
                  \"Type\": \"TXT\",
                  \"TTL\": 300,
                  \"ResourceRecords\": [
                    {
                      \"Value\": \"\\\"heritage=external-dns,external-dns/owner=${ownerId}\\\"\"
                    }
                  ]
                }
              }
            ]
          }" >"${recordFile}"
  aws route53 change-resource-record-sets --no-cli-pager --hosted-zone-id "${hostedZoneId}" --change-batch "file://${recordFile}"
done
