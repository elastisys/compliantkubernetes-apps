#!/usr/bin/env bash

# TODO
# ----
# Generalize the creation of security plugin objects,
# as it is now duplicated for each individual object.
# -----

set -e

wait_until_ready=600
poll_interval=5

auth="${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}"
os_url="https://{{ .Values.opensearch.clusterEndpoint }}"
osd_url="http://{{ .Values.opensearch.dashboardsEndpoint }}"

snapshot_repository="{{ .Values.config.snapshots.repository }}"

create_indices="{{ .Values.config.createIndices }}"

users='{{ toJson .Values.config.securityPlugin.users }}'
roles='{{ toJson .Values.config.securityPlugin.roles }}'
rolesmappings='{{ toJson .Values.config.securityPlugin.roles_mapping }}'

template_names=$(ls /files/*.template.json 2> /dev/null | sed s/^.*\\/\// | cut -f1 -d.)
policy_names=$(ls /files/*.policy.json 2> /dev/null | sed s/^.*\\/\// | cut -f1 -d.)

log_error_exit() {
  description=$1
  error_msg=$2
  echo "${description}" 1>&2
  echo "${error_msg}" 1>&2
  exit 1
}

wait_for_dashboards() {
  starttime_s=$(date +%s)
  while [ $(($(date +%s) - starttime_s)) -le ${wait_until_ready} ]; do
    status=$(curl --insecure -u "${auth}" --silent "${osd_url}/api/status" | grep "^{" | jq -r .'status.overall.state')
    if [ "${status}" = "green" ]; then
      echo "OpenSearch Dashboards is ready"
      break
    fi
    echo "OpenSearch Dashboards is not ready yet"
    sleep ${poll_interval}
  done
}

setup_dashboards() {
  echo
  echo "Setting up OpenSearch Dashboards"
  resp=$(curl -s -kL -X POST "${osd_url}/api/saved_objects/_import?overwrite=true" \
    -H "osd-xsrf: true" \
    --form file=@/files/dashboards.ndjson -u "${auth}")
  success=$(echo "${resp}" | grep "^{" | jq -r '.success')
  if [ "${success}" != "true" ]; then
    log_error_exit "Failed to set up OpenSearch Dashboards" "${resp}"
  fi
}

# Returns true if:
# - Snapshot repository is registered, and
# - registered repositories' bucket name is the same as the one given
check_s3_repository_bucket() {
  resp=$(curl -u "${auth}" --insecure --silent "${os_url}/_snapshot/${snapshot_repository}")
  if [ "$(echo $resp | jq -r '."'${snapshot_repository}'".settings.bucket')" = "{{ .Values.config.s3.bucketName }}" ]; then
    return 0
  fi
  return 1
}

check_azure_repository_container() {
  resp=$(curl -u "${auth}" --insecure --silent "${os_url}/_snapshot/${snapshot_repository}")
  if [ "$(echo $resp | jq -r '."'${snapshot_repository}'".settings.container')" = "{{ .Values.config.azure.containerName }}" ]; then
    return 0
  fi
  return 1
}

register_s3_repository() {
  echo
  echo "Registering S3 snapshot repository"
  resp=$(curl --insecure -X PUT "${os_url}/_snapshot/${snapshot_repository}" \
    -H 'Content-Type: application/json' \
    -d' {"type": "s3", "settings":{ "bucket": "{{ .Values.config.s3.bucketName }}", "client": "default"}}' \
    -s -k -u "${auth}")
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" != "true" ]; then
    log_error_exit "Failed to register S3 repository" "${resp}"
  fi
}

register_gcs_repository() {
  echo
  echo "Registering GCS snapshot repository"
  resp=$(curl --insecure -X PUT "${os_url}/_snapshot/${snapshot_repository}" \
    -H 'Content-Type: application/json' \
    -d' {"type": "gcs", "settings":{ "bucket": "{{ .Values.config.gcs.bucketName }}", "client": "default"}}' \
    -s -k -u "${auth}")
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" != "true" ]; then
    log_error_exit "Failed to register GSC repository" "${resp}"
  fi
}

register_azure_repository() {
  echo
  echo "Registering Azure Blob Storage snapshot repository"
  resp=$(curl --insecure -X PUT "${os_url}/_snapshot/${snapshot_repository}" \
    -H 'Content-Type: application/json' \
    -d' {"type": "azure", "settings":{ "container": "{{ .Values.config.azure.containerName }}", "client": "default" }}' \
    -s -k -u "${auth}")
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" != "true" ]; then
    log_error_exit "Failed to register Azure repository" "${resp}"
  fi
}

create_index_template() {
  name="${1}"
  overwrite_templates="{{ .Values.config.overwriteTemplates }}"
  # The opendistro API uses a value representing 'strict create' rather than
  # 'overwrite_templates', therefore negate
  case "${overwrite_templates}" in
    true) strict="false" ;;
    false) strict="true" ;;
    *) log_error_exit "Unknown value for .Values.config.overwriteTemplates, should be 'true' or 'false'" "" ;;
  esac
  filename="${name}.template.json"
  echo "Creating index template from file '${filename}'"
  resp=$(curl --insecure -X PUT "${os_url}/_index_template/${name}?create=${strict}" \
    -H "Content-Type: application/json" -s \
    -d@/files/${filename} -k -u "${auth}")
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" != "true" ]; then
    if [ "${overwrite_templates}" = "false" ] \
        && echo "${resp}" | grep "already exists" > /dev/null ; then
      echo "Index template '${name}' already exists, do nothing"
    else
      log_error_exit "Failed to create index template from template '${filename}'" "${resp}"
    fi
  fi
}

setup_policy() {
  create_update_policy() {
    update_policies="{{ .Values.config.updatePolicies }}"

    update_policy() {
      policy=$1
      policy_json=$(curl --insecure -X GET "${os_url}/_plugins/_ism/policies/${policy}" \
        -H "Content-Type: application/json" -k -s \
        -u "${auth}")
      seq_no=$(echo "${policy_json}" | jq -r '._seq_no')
      primary_term=$(echo "${policy_json}" | jq -r '._primary_term')
      resp=$(curl --insecure -X PUT "${os_url}/_plugins/_ism/policies/${policy}?if_seq_no=${seq_no}&if_primary_term=${primary_term}" \
        -H "Content-Type: application/json" -k -s \
        -d@"/files/${policy}.policy.json" \
        -u "${auth}")
      id=$(echo "${resp}" | grep "^{" | jq -r '._id')
      if [ "${id}" != "${policy}" ]; then
        log_error_exit "Failed to update policy '${policy}'" "${resp}"
      fi
      echo "Updated policy '${policy}'"
    }

    policy="${1}"
    echo "Creating policy '${policy}'"
    resp=$(curl --insecure -X PUT "${os_url}/_plugins/_ism/policies/${policy}" \
      -H "Content-Type: application/json" \
      -d@"/files/${policy}.policy.json" -k -s \
      -u "${auth}")
    status=$(echo "${resp}" | grep "^{" | jq -r '.status')
    id=$(echo "${resp}" | grep "^{" | jq -r '._id')
    if [ "${status}" = 409 ]; then # policy already exists
      echo "Policy '${policy}' already exists"
      if [ "${update_policies}" = "true" ]; then update_policy "${policy}"; fi
    elif [ "${id}" != "${policy}" ]; then
      log_error_exit "Unknown response, failed to create policy?" "${resp}"
    fi
  }

  echo
  echo "Creating and adding ISM policies"
  create_update_policy "${1}"
}

init_indices() {
  echo
  echo "Creating initial indices"

  for idx in other kubernetes kubeaudit authlog; do
    indices=$(curl --insecure -X GET "${os_url}/_cat/aliases/${idx}" \
      -k -s -u "${auth}")
    if echo "${indices}" | grep "true" > /dev/null; then # idx exists
      echo "Index '${idx}' already exists"
    else # create idx
      resp=$(curl --insecure -X PUT "${os_url}/%3C${idx}-default-%7Bnow%2Fd%7D-000001%3E" \
        -H 'Content-Type: application/json' \
        -k -s -u "${auth}" \
        -d '{"aliases": {"'"${idx}"'": {"is_write_index": true }}}')
      acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
      if [ "${acknowledged}" = "true" ]; then
        echo "Created index '${idx}'"
      else
        log_error_exit "Failed to create index '${idx}'" "${resp}"
      fi
    fi
  done
}

create_role() {
  role_name="$1"; role_definition="$2"
  response=$(curl --insecure -X PUT "${os_url}/_plugins/_security/api/roles/${role_name}" \
    -H 'Content-Type: application/json' \
    -k -s -u "${auth}" \
    -d "${role_definition}")

  status=$(echo "${response}" | grep "^{" | jq -r '.status')

  case "${status}" in
    CREATED|OK)
      echo "Role '${role_name}' created"
      ;;
    *)
      log_error_exit "Failed to create role '${role_name}'" "${response}"
      ;;
  esac
}

create_rolemapping() {
  rolemapping_name="$1"; role_definition="$2"
  response=$(curl --insecure -X PUT "${os_url}/_plugins/_security/api/rolesmapping/${rolemapping_name}" \
    -H 'Content-Type: application/json' \
    -k -s -u "${auth}" \
    -d "${role_definition}")

  status=$(echo "${response}" | grep "^{" | jq -r '.status')

  case "${status}" in
    CREATED|OK)
      echo "Rolemapping '${rolemapping_name}' created"
      ;;
    *)
      log_error_exit "Failed to create role mapping '${rolemapping_name}'" "${response}"
      ;;
  esac
}

create_user() {
  user_name="$1"; user_info="$2"
  response=$(curl --insecure -X PUT "${os_url}/_plugins/_security/api/internalusers/${user_name}" \
    -H 'Content-Type: application/json' \
    -k -s -u "${auth}" \
    -d "${user_info}")

  status=$(echo "${response}" | grep "^{" | jq -r '.status')

  case "${status}" in
    CREATED|OK)
      echo "User '${user_name}' created"
      ;;
    *)
      log_error_exit "Failed to create user '${user_name}'" "${response}"
      ;;
  esac
}

create_update_snapshot_policy() {
  echo
  echo "Checking if snapshot policy exists"
  policy_resp=$(curl --insecure -X GET "${os_url}/_plugins/_sm/policies/snapshot_management_policy" -s -k -u "${auth}")
  seq_no=$(echo "${policy_resp}" | grep "^{" | jq -r '._seq_no')
  primary_term=$(echo "${policy_resp}" | grep "^{" | jq -r '._primary_term')
  if [ "${seq_no}" != "null" ] && [ "${primary_term}" != "null" ]; then
    echo "Updating snapshot policy"
    resp=$(curl --insecure -X PUT "${os_url}/_plugins/_sm/policies/snapshot_management_policy?if_seq_no=${seq_no}&if_primary_term=${primary_term}" \
    -H 'Content-Type: application/json' \
    -s -k -u "${auth}" \
    -d '{
      "description": "Snapshot Management Policy",
      "creation": {
        "schedule": {
          "cron": {
            "expression": "{{ .Values.config.snapshots.backupSchedule }}",
            "timezone": "UTC"
          }
        },
        "time_limit": "1h"
      },
      "deletion": {
        "schedule": {
          "cron": {
            "expression": "{{ .Values.config.snapshots.retentionSchedule }}",
            "timezone": "UTC"
          }
        },
        "condition": {
          "max_age": "{{ .Values.config.snapshots.retentionAge }}",
          "min_count": {{ .Values.config.snapshots.min }},
          "max_count": {{ .Values.config.snapshots.max }}
        },
        "time_limit": "1h"
      },
      "snapshot_config": {
        "repository": "{{ .Values.config.snapshots.repository }}",
        "date_format": "yyyy-MM-dd-HH:mm:ss",
        "timezone": "UTC",
        "indices": "{{ .Values.config.snapshots.indices }}",
        "include_global_state": "false"
      }
    }')
  else
    echo "Creating snapshot policy"
    resp=$(curl --insecure -X POST "${os_url}/_plugins/_sm/policies/snapshot_management_policy" \
      -H 'Content-Type: application/json' \
      -s -k -u "${auth}" \
      -d '{
        "description": "Snapshot Management Policy",
        "creation": {
          "schedule": {
            "cron": {
              "expression": "{{ .Values.config.snapshots.backupSchedule }}",
              "timezone": "UTC"
            }
          },
          "time_limit": "1h"
        },
        "deletion": {
          "schedule": {
            "cron": {
              "expression": "{{ .Values.config.snapshots.retentionSchedule }}",
              "timezone": "UTC"
            }
          },
          "condition": {
            "max_age": "{{ .Values.config.snapshots.retentionAge }}",
            "min_count": {{ .Values.config.snapshots.min }},
            "max_count": {{ .Values.config.snapshots.max }}
          },
          "time_limit": "1h"
        },
        "snapshot_config": {
          "repository": "{{ .Values.config.snapshots.repository }}",
          "date_format": "yyyy-MM-dd-HH:mm:ss",
          "timezone": "UTC",
          "indices": "{{ .Values.config.snapshots.indices }}",
          "include_global_state": "false"
        }
      }')
  fi

  policy_id=$(echo "${resp}" | grep "^{" | jq -r '._id')
  if [ "${policy_id}" == "null" ]; then
    log_error_exit "Failed to create snapshot policy" "${resp}"
  fi
}

wait_for_dashboards
setup_dashboards

{{ if .Values.config.s3.enabled -}}
if ! check_s3_repository_bucket; then
  register_s3_repository
else
  echo
  echo "Skip registering S3 snapshot repository"
fi
{{ else if .Values.config.gcs.enabled -}}
register_gcs_repository
{{ else if .Values.config.azure.enabled -}}
if ! check_azure_repository_container; then
  register_azure_repository
else
  echo
  echo "Skip registering Azure Blob Storage snapshot repository"
fi
{{- end }}

[ -n "${template_names}" ] && echo && echo "Creating index templates"
for template in ${template_names}; do
  create_index_template ${template}
done

[ -n "${policy_names}" ] && echo && echo "Creating ISM policies"
for policy in ${policy_names}; do
  setup_policy ${policy}
done

if [ "${create_indices}" = "true" ]; then init_indices; fi

echo
echo "Creating roles"
for row in $(echo "${roles}"  | jq -r '.[] | @base64'); do
    _jq() {
      echo "${row}" | base64 -d | jq -r ${1}
    }

    create_role "$(_jq '.role_name')" "$(_jq '.definition')"
done

echo
echo "Creating role mappings"
for row in $(echo "${rolesmappings}" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 -d | jq -r ${1}
    }

    create_rolemapping "$(_jq '.mapping_name')" "$(_jq '.definition')"
done

echo
echo "Creating users"
for row in $(echo "${users}"  | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 -d | jq -r ${1}
    }

    create_user "$(_jq '.username')" "$(_jq '.definition')"
done

create_update_snapshot_policy

echo
echo "Done configuring OpenSearch and Dashboards"
