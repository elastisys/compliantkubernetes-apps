#!/bin/bash
# (return 0 2>/dev/null) && sourced=1 || sourced=0

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=bin/common.bash
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

function sc_certmanager_check_help(){
    printf "%s\n" "[Usage]: test sc cert-manager [ARGUMENT]";
    printf "\t%-25s %s\n" "--cluster-issuers" "Check cluster issuers";
    printf "\t%-25s %s\n" "--certificates" "Check cluster certificates";
    printf "\t%-25s %s\n" "--challenges" "Check challenges";
    printf "%s\n" "[NOTE] If no argument is specified, it will go over all of them.";

    exit 0;
}

function sc_cert_manager_checks(){
    if [[ ${#} == 0 ]]; then
        echo "Running all checks ..."
        check_sc_certmanager_cluster_issuers
        check_sc_certmanager_apps_certificates
        exit 0
    fi
    while [[ ${#} -gt  0 ]]; do
      case ${1} in
          --cluster-issuers )
            check_sc_certmanager_cluster_issuers
          ;;
          --certificates )
            check_sc_certmanager_apps_certificates
          ;;
          --challenges )
            check_sc_certmanager_challenges
          ;;
          --help )
            sc_certmanager_check_help
          ;;
      esac
      shift
    done
}

function check_sc_certmanager_cluster_issuers(){
  echo -ne "Checking cert manager cluster issuers ... "
  no_error=true
  debug_msg=""

  clusterIssuers=("letsencrypt-prod" "letsencrypt-staging")

  for clusterIssuer in "${clusterIssuers[@]}"; do
    if kubectl get ClusterIssuer "$clusterIssuer" &> /dev/null; then
      jsonData=$(kubectl get ClusterIssuer "$clusterIssuer" -ojson)
      cluster_issuer_status=$(echo "$jsonData" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
      if [[ "$cluster_issuer_status" == "True" ]]; then
        IFS='-' read -ra data <<< "$clusterIssuer"
        readarray custom_solvers < <(yq4 e -o=j -I=0 ".issuers.${data[0]}.${data[1]}.solvers[]" "${config['config_file_sc']}")
        if ! [ ${#custom_solvers[@]} -eq 0 ]; then
            for custom_solver in "${custom_solvers[@]}"; do
              challenge_solver=$(echo "$custom_solver" | jq ". | del( .selector ) | keys[] ");
              solver_exist=$(kubectl get ClusterIssuer "$clusterIssuer" -oyaml | yq4 e -o=j -I=0 ".spec.acme.solvers[].$challenge_solver")
              if [[ $solver_exist == "null" ]]; then
                no_error=false
                debug_msg+="[ERROR] Missing custom solver : $challenge_solver for Cluster Issuer : $clusterIssuer\n"
              fi
            done
        fi

      else
        no_error=false
        debug_msg+="[ERROR] ClusterIssuer $clusterIssuer is not ready\n"
      fi

    else
      no_error=false
      debug_msg+="[ERROR] ClusterIssuer $clusterIssuer does not exist\n"
    fi
  done

  if $no_error; then
    echo "success ✔"
    echo -e "[DEBUG] All ClusterIssuer resources are present and ready, with correct solvers"
  else
    echo "failure ❌";
    echo -e "$debug_msg"
  fi
}

function check_sc_certmanager_apps_certificates() {
  echo -ne "Checking cert manager for Apps Certificates ... "
  no_error=true
  debug_msg=""

  certificates=(
    "dex dex-tls"
    "opensearch-system opensearch-admin"
    "opensearch-system opensearch-ca"
    "opensearch-system opensearch-dashboards-ingress-cert"
    "opensearch-system opensearch-http"
    "opensearch-system opensearch-ingress-cert"
    "opensearch-system opensearch-transport"
  )

  enable_harbor=$(yq4 -e '.harbor.enabled' "${config['config_file_sc']}" 2>/dev/null)
  enable_thanos=$(yq4 -e '.thanos.enabled' "${config['config_file_sc']}" 2>/dev/null)
  enable_user_grafana=$(yq4 -e '.user.grafana.enabled' "${config['config_file_sc']}" 2>/dev/null)

  if "${enable_harbor}"; then
    certificates+=(
        "harbor harbor-core-cert"
        "harbor harbor-notary-cert"
        "harbor harbor-core-ingress-cert"
        "harbor harbor-notary-ingress-cert"
    )
  fi

  if "${enable_user_grafana}"; then
    certificates+=(
        "monitoring grafana-ops-general-tls"
        "monitoring user-grafana-tls"
    )
  fi

  if "${enable_thanos}"; then
    thanos_subdomain=$(yq4 -e '.thanos.receiver.subdomain' "${config['config_file_sc']}")
    opsDomain=$(yq4 -e '.global.opsDomain' "${config['config_file_sc']}")
    certificates+=(
        "thanos $thanos_subdomain.$opsDomain-tls"
    )
  fi

  for cert in "${certificates[@]}"; do
    read -r -a arr <<< "$cert"
    namespace="${arr[0]}"
    name="${arr[1]}"
    if kubectl get "Certificate" -n "$namespace" "$name" &> /dev/null; then
      certificate_data=$(kubectl get "Certificate" -n "$namespace" "$name" -ojson)
      cert_renewal_time=$(echo "$certificate_data" | jq -r ".status.renewalTime")
      cert_expiry_time=$(echo "$certificate_data" | jq -r ".status.notAfter")
      cert_status=$(echo "$certificate_data" | jq -r ".status.conditions[] | select(.type==\"Ready\") | .status")
      cert_status_message=$(echo "$certificate_data" | jq -r ".status.conditions[] | select(.type==\"Ready\") | .message")
      if [[ "$cert_status" != "True" ]]; then
        no_error=false
        debug_msg+="[ERROR] $cert_status_message \n"
      else
        now_date=$(date +%s)
        expiry_date=$(date -d "$cert_expiry_time" +%s)
        renew_date=$(date -d "$cert_renewal_time" +%s)
        ((expiry_diff=(expiry_date-now_date)/86400))
        ((renew_diff=(renew_date-now_date)/86400))
        if [[ $expiry_diff -lt 1 ]]; then
          no_error=false
          debug_msg+="[ERROR] $name will expire in less than $expiry_diff day(s)\n"
        else
          debug_msg+="[DEBUG] Certificate: $name is Ready, will expire in $expiry_diff day(s), will be renewed in $renew_diff day(s)\n"
        fi
      fi
    else
      no_error=false
      debug_msg+="[ERROR]: Missing certificate : $name in namespace $namespace\n"
    fi
  done

  if $no_error; then
    echo "success ✔"
    echo -e "$debug_msg"
  else
    echo "failure ❌";
    echo -e "$debug_msg"
  fi
}

function check_sc_certmanager_challenges(){
  echo -ne "Checking cert manager Challenges ... "
  no_error=true
  debug_msg=""

  challenges_data=$(kubectl get challenges -A -ojson)

  readarray -t pending_challenges < <(jq -c '.items[] | select(.status.state=="pending")' <<< "$challenges_data")

  if ! [[ $(echo "$challenges_data" | jq '.items | length') -eq 0 ]]; then
    if [[ ${#pending_challenges[@]} != 0 ]]; then
      no_error=false
      debug_msg+="[ERROR] There are some pending challenges\n"
      for pending_challenge in "${pending_challenges[@]}"; do
        challenge_name=$(echo "$pending_challenge" | jq -r ".metadata.name")
        challenge_namespace=$(echo "$pending_challenge" | jq -r ".metadata.namespace")
        pending_reason=$(echo "$pending_challenge" | jq -r ".status.reason")
        debug_msg+="Challenge $challenge_name in the $challenge_namespace namepsace is pending because : $pending_reason\n"
      done
    fi
  fi

  orders_data=$(kubectl get orders -A -ojson)

  if ! [[ $(echo "$orders_data" | jq '.items | length') -eq 0 ]]; then
    readarray -t errored_orders < <(jq -c '.items[] | select(.status.state=="errored")' <<< "$orders_data")

    if [[ ${#errored_orders} != 0 ]]; then
      no_error=false
      debug_msg+="[ERROR] There some errored orders\n"
      for errored_order in "${errored_orders[@]}"; do
        order_name=$(echo "$errored_order" | jq -r ".metadata.name")
        order_namespace=$(echo "$errored_order" | jq -r ".metadata.namespace")
        errored_reason=$(echo "$errored_order" | jq -r ".status.reason")
        debug_msg+="Order $order_name in the $order_namespace namepsace is errored because : $errored_reason\n"
      done
    fi
  fi

  if $no_error; then
    echo "success ✔"
    echo -e "[DEBUG] There are no pending challenges, or errored orders"
  else
    echo "failure ❌";
    echo -e "$debug_msg"
  fi
}
