#!/usr/bin/env bash
# (return 0 2>/dev/null) && sourced=1 || sourced=0

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=bin/common.bash
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

pushd "${CK8S_CONFIG_PATH}" || exit
adminPassword=$(sops -d secrets.yaml | yq4 '.opensearch.adminPassword')
fluentdPassword=$(sops -d secrets.yaml | yq4 '.opensearch.fluentdPassword')
opsDomain=$(yq4 '.global.opsDomain' common-config.yaml)
popd || exit

function opensearch_check_help() {
  printf "%s\n" "[Usage]: test sc opensearch [ARGUMENT]"
  printf "\t%-25s %s\n" "--cluster-health" "Get cluster health"
  printf "\t%-25s %s\n" "--snapshot-status" "Check snapshot status"
  printf "\t%-25s %s\n" "--breakers" "Check if circuit breakers have been triggered"
  printf "\t%-25s %s\n" "--indices" "Check if there are any missing indices"
  printf "\t%-25s %s\n" "--aliases" "Check if each aliases has a write index"
  printf "\t%-25s %s\n" "--mappings" "Check mappings/fields count & limit"
  printf "\t%-25s %s\n" "--user-roles" "Check configured user roles"
  printf "\t%-25s %s\n" "--ism" "Check ISM"
  printf "\t%-25s %s\n" "--object-store-access" "Check object store access"
  printf "\t%-25s %s\n" "--fluentd" "Check that fluentd can connect to opensearch"
  printf "%s\n" "[NOTE] If no argument is specified, it will go over all of them."

  exit 0
}

function sc_opensearch_checks() {
  if [[ ${#} == 0 ]]; then
    check_opensearch_cluster_health
    check_opensearch_snapshots_status
    check_opensearch_breakers
    check_opensearch_indices
    check_opensearch_aliases
    check_opensearch_mappings
    check_opensearch_user_roles
    check_opensearch_ism
    check_object_store_access
    check_fluentd_connection
    return
  fi
  while [[ ${#} -gt 0 ]]; do
    case ${1} in
    --cluster-health)
      check_opensearch_cluster_health
      ;;
    --snapshot-status)
      check_opensearch_snapshots_status
      ;;
    --breakers)
      check_opensearch_breakers
      ;;
    --indices)
      check_opensearch_indices
      ;;
    --aliases)
      check_opensearch_aliases
      ;;
    --mappings)
      check_opensearch_mappings
      ;;
    --user-roles)
      check_opensearch_user_roles
      ;;
    --ism)
      check_opensearch_ism
      ;;
    --object-store-access)
      check_object_store_access
      ;;
    --fluentd)
      check_fluentd_connection
      ;;
    --help)
      opensearch_check_help
      ;;
    esac
    shift
  done
}

check_opensearch_cluster_health() {
  echo -ne "Checking if opensearch cluster is healthy ... "
  cluster_health=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cluster/health")
  status=$(echo "$cluster_health" | jq -r '.status')
  if [[ $status != "green" ]]; then
    echo -e "failure ❌"
    echo "$cluster_health" | jq
  else
    echo -e "success ✔"
  fi
}

check_opensearch_snapshots_status() {
  echo -ne "Checking opensearch snapshots status ... "
  no_error=true
  debug_msg=""
  repo_name=$(yq4 -e '.opensearch.snapshot.repository' "${config['config_file_sc']}")
  repo_exists_status=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_snapshot/${repo_name}" | jq "select(.error)")
  if [[ -z "$repo_exists_status" ]]; then
    snapshots=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cat/snapshots/${repo_name}")
    error=$(echo "$snapshots" | jq '.error' 2>/dev/null || true)
    failed=$(echo "$snapshots" | grep 'FAILED' || true)
    partial=$(echo "$snapshots" | grep 'PARTIAL' || true)

    if [[ "$error" != "" ]] && [[ "$error" != "null" ]]; then
      no_error=false
      debug_msg+="[ERROR] Error in snapshots output: \n $error\n"
    else
      if [[ "$failed" != "" ]]; then
        no_error=false
        debug_msg+="[ERROR] We found some failed snapshots: \n $failed\n"
      fi

      if [[ "$partial" != "" ]]; then
        no_error=false
        debug_msg+="[WARNING] We found some partial snapshots: \n $partial\n"
      fi

      IFS=$'\n' readarray -t data < <(awk '{ print $1 " " $2 " " $3}' <<<"$snapshots")
      IFS=" " read -ra last_snapshot <<<"${data[-1]}"

      if [[ "${#last_snapshot[@]}" -gt 0 ]]; then
        now_epoch=$(date +%s)
        last_snapshot_epoch=${last_snapshot[2]}
        ((diff = now_epoch - last_snapshot_epoch))

        if [[ $diff -gt 86400 ]]; then
          no_error=false
          debug_msg+="[ERROR] The latest snapshot has not been created within the past 24 hours, with status: ${last_snapshot[1]}\n"
        else
          debug_msg+="[WARNING] The latest snapshot has been created within the past 24 hours, with status: ${last_snapshot[1]}\n"
        fi
      else
        no_error=false
        debug_msg+="[ERROR] No snapshots found, if this is a brand new cluster this can safely be ignored\n"
      fi
    fi
  else
    no_error=false
    debug_msg=$(echo -e "$repo_exists_status" | jq)
  fi

  if $no_error; then
    echo "success ✔"
    echo "[DEBUG] All snapshots are either completed or in progress"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi
}

check_opensearch_indices() {
  echo -ne "Checking opensearch indices status ... "
  debug_msg=""
  no_error=true

  for index in 'other' 'kubernetes' 'kubeaudit' 'authlog'; do
    res=$(curl -w "%{http_code}" -o /dev/null -ksIL -u admin:"${adminPassword}" -X HEAD "https://opensearch.${opsDomain}/${index}")
    if [[ $res != "200" ]]; then
      debug_msg+="[ERROR] Missing index : ${index}\n"
      no_error=false
    fi
  done

  if $no_error; then
    echo "success ✔"
    echo -e "[DEBUG] All indices are present"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi
}

check_opensearch_breakers() {
  echo -ne "Checking opensearch breakers ... "
  breakers_data=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_nodes/_all/stats/breaker")
  no_error=true
  debug_msg=""
  nodes_data=$(echo "$breakers_data" | jq ".nodes")
  readarray -t nodes < <(jq -c 'to_entries[]' <<<"$nodes_data")

  for node in "${nodes[@]}"; do
    node_name=$(jq '.key' <<<"$node")
    readarray -t breakers < <(jq -c '.value.breakers | to_entries[]' <<<"$node")
    for breaker in "${breakers[@]}"; do
      tripped=$(jq ".value.tripped" <<<"$breaker")
      name=$(jq ".key" <<<"$breaker")
      if [[ $tripped == "1" ]]; then
        no_error=false
        debug_msg+="[DEBUG] A circuit breaker : $name has been triggered for node: $node_name\n"
      fi
    done
  done

  if $no_error; then
    echo "success ✔"
    echo "[DEBUG] None of the circuit breakers has been triggered"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi

}

check_opensearch_aliases() {
  echo -ne "Checking opensearch aliases indices mapping ... "
  no_error=true
  debug_msg=""

  curl -sk -o /tmp/response -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cat/aliases"

  aliases=$(awk '{print $1}' </tmp/response)
  aliases_arr=("$aliases")

  uniq_aliases=$(echo "${aliases_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  for alias in $uniq_aliases; do
    if ! [[ $alias =~ ^[\.*] ]]; then

      alias_data=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_alias/${alias}")
      is_write_index="$(echo "$alias_data" | jq ".[].aliases.$alias.is_write_index | select(. == true)")"
      if [[ "$is_write_index" == "" ]]; then
        no_error=false
        debug_msg+="[DEBUG] Alias : $alias has no write index \n"
      fi

    fi
  done

  if $no_error; then
    echo "success ✔"
    echo "[DEBUG] All aliases have write indices associated with them"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi

}

check_opensearch_mappings() {
  echo -ne "Checking opensearch mappings/fields ... "
  no_error=true
  warn=false
  debug_msg="INDEX\t\t\t\t\t\t| #FIELDS \t| LIMIT \n"
  debug_msg+="------------------------------------------------------------------------\n"

  indices_data=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cat/indices" | awk '{print $3}' | tr '\n' ' ')
  IFS=' ' read -ra indices <<<"$indices_data"
  for index in "${indices[@]}"; do
    fields_limit=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/${index}/_settings" | jq -r ".[\"${index}\"].settings.index.mapping.total_fields.limit")
    fields_count=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/${index}/_field_caps?fields=*" | jq -r ".fields | keys | length")

    if [[ $fields_limit != "null" ]]; then
      fields_limit_usage=$((fields_count * 100 / fields_limit))
      if [[ $fields_count -gt $fields_limit ]]; then
        no_error=false
      fi
      if [[ $fields_limit_usage -gt 50 ]]; then
        warn=true
        debug_msg+="${index}\t\t ${fields_count} \t\t ${fields_limit} \n"
      fi
    fi
  done

  if $no_error; then
    echo "success ✔"
    echo "[DEBUG] Fields limit has not been reached yet"
    if $warn; then
      echo -e "$debug_msg"
    fi
  else
    echo "failure ❌"
    echo "[ERROR] Some fields limit have been crossed"
    echo -e "$debug_msg"
  fi
}

check_opensearch_user_roles() {
  echo -ne "checking user roles mappings ... "
  no_error=true
  debug_msg=""

  readarray configuredMappings < <(yq4 e -o=j -I=0 '.opensearch.extraRoleMappings[]' "${config['config_file_sc']}")

  rolesmapping=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_plugins/_security/api/rolesmapping")

  for roleMapping in "${configuredMappings[@]}"; do
    configured_mapping_name=$(echo "$roleMapping" | yq4 e '.mapping_name' -)
    configured_users=$(echo "$roleMapping" | yq4 e '.definition.users[]' -)
    res=$(echo "$rolesmapping" | jq ".\"$configured_mapping_name\"")
    if [[ $res != "null" ]]; then
      users=$(echo "$rolesmapping" | jq -r ".\"$configured_mapping_name\".users[]")
      if [[ "$users" != "$configured_users" ]]; then
        no_error=false
        debug_msg+="[ERROR] Missing users < ${configured_users//$'\n'/ }> != < $users >, for role mapping: $configured_mapping_name \n"
      fi
    else
      no_error=false
      debug_msg+="[ERROR] Missing role mapping_name ${roleMapping} \n"
    fi
  done

  if $no_error; then
    echo "success ✔"
    echo "[DEBUG] User roles are configured correctly"
  else
    echo "failure ❌"
    echo -ne "$debug_msg"
  fi
}

check_opensearch_ism() {
  echo -ne "Checking opensearch Index State Management ... "
  no_error=true
  debug_msg=""

  default_policies_enabled=$(yq4 -e '.opensearch.ism.defaultPolicies' "${config['config_file_sc']}")
  if [[ $default_policies_enabled == "true" ]]; then
    default_policies=("kubernetes" "kubeaudit" "authlog" "other")
    for policy in "${default_policies[@]}"; do
      res=$(curl -w "%{http_code}" -o /dev/null -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_plugins/_ism/policies/${policy}")
      if [[ $res != "200" ]]; then
        no_error=false
        debug_msg+="[ERROR] Missing default policy : ${policy}\n"
      fi
    done
  fi

  readarray -t additional_policies < <(yq4 e -o=j -I=0 '.opensearch.ism.additionalPolicies | keys' "${config['config_file_sc']}")

  additional_policies=("${additional_policies//,/ }")
  additional_policies=("${additional_policies##[}")
  additional_policies=("${additional_policies%]}")
  read -ra additional_policies <<<"${additional_policies[@]}"

  for policy in "${additional_policies[@]}"; do
    policy_name=$(echo "$policy" | awk -F'.' '{print $1}' | tr '"' ' ')
    res=$(curl -w "%{http_code}" -o /dev/null -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_plugins/_ism/policies/${policy_name}")
    if [[ $res != "200" ]]; then
      no_error=false
      debug_msg+="[ERROR] Missing additional policy : ${policy_name}\n"
    fi
  done

  write_indices_data=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cat/aliases?format=json" | jq -r '.[] | select(.is_write_index == "true") | .index' | tr '\n' ' ')
  read -ra write_indices <<<"$write_indices_data"
  for write_index in "${write_indices[@]}"; do

    rollover_age_days=$(yq4 -e '.opensearch.ism.rolloverAgeDays' "${config['config_file_sc']}")
    ((rollover_limit = rollover_age_days * 86400000))

    epoch_now=$(date +%s%3N)
    write_index_creation_date=$(curl -sk -u admin:"${adminPassword}" -X GET "https://opensearch.${opsDomain}/_cat/indices/${write_index}?h=creation.date")

    ((creation_lapse = epoch_now - write_index_creation_date))

    if [[ $creation_lapse -gt $rollover_limit ]]; then
      no_error=false
      debug_msg+="[ERROR]The write index : $write_index is old and has not been rolled over as expected\n"
    fi

  done

  if $no_error; then
    echo "success ✔"
    echo -e "[DEBUG] There are no missing default/additional policies"
    echo -e "[DEBUG] All write indices are rolled over as expected"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi
}

# TODO: skip if object store is behind firewall (only reachable from cluster/bastion)
check_object_store_access() {
  echo -ne "Checking opensearch snapshot bucket access... "
  no_error=true
  debug_msg=""
  EX_NOTFOUND=12
  EX_OK=0
  EX_ACCESSDENIED=77
  EX_CONFIG=78
  snapshot_bucket=$(yq4 -e '.objectStorage.buckets.opensearch' "${config['config_file_sc']}")

  if [ ! -f "${CK8S_CONFIG_PATH}/.state/s3cfg.ini" ]; then
    no_error=false
    debug_msg="[SKIP] S3 configuration file missing"
  else
    command=$(
      s3cmd --config <(sops -d "${CK8S_CONFIG_PATH}"/.state/s3cfg.ini) ls s3://"${snapshot_bucket}" >/dev/null 2>&1
      echo $?
    )
    if [[ ${command} -eq $EX_OK ]]; then
      debug_msg="[DEBUG] Snapshot bucket ${snapshot_bucket} exist and can be accessed"
    elif [[ ${command} -eq $EX_NOTFOUND ]]; then
      no_error=false
      debug_msg="[ERROR] S3 error: 404 (NoSuchBucket): The specified bucket ${snapshot_bucket} does not exist."
    elif [[ ${command} -eq $EX_ACCESSDENIED ]]; then
      no_error=false
      debug_msg="[ERROR] S3 error: Insufficient permissions to perform the operation on S3"
    elif [[ ${command} -eq $EX_CONFIG ]]; then
      no_error=false
      debug_msg="[ERROR] S3 error: Configuration file error"
    else
      no_error=false
      debug_msg="[ERROR] An error happened, please try again"
    fi
  fi

  if $no_error; then
    echo "success ✔"
    echo -e "$debug_msg"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi
}

check_fluentd_connection() {
  echo -ne "Checking if fluentd can connect to opensearch... "
  no_error=true
  debug_msg=""

  res=$(curl -w "%{http_code}" -o /dev/null -ksIL -u fluentd:"${fluentdPassword}" -X HEAD "https://opensearch.${opsDomain}/")
  if [[ $res != "200" ]]; then
    debug_msg+="[ERROR] $res : Fluentd cannot connect to opensearch.\nPlease check your credentials"
    no_error=false
  fi

  if $no_error; then
    echo "success ✔"
    echo -e "[DEBUG] Fluentd is able to connect to Opensearch"
  else
    echo "failure ❌"
    echo -e "$debug_msg"
  fi

}
