#!/usr/bin/env bash

set -e

if [ -z "$CK8S_CONFIG_PATH" ]; then
  log "ERROR: CK8S_CONFIG_PATH is not set."
  log "Please set and export the variable before running the script."
  exit 1
fi

usage() {
  echo "Usage: $0 <action> <target>"
  echo "Actions: backup | restore"
  echo "Targets: opensearch | harbor | rclone | velero"
  exit 1
}

# Sets a timestamp log before every message, also colors it purple to make it easier to distinct from rest of the text because why not
PURPLE='\033[0;35m'
NOCOLOR='\033[0m'
log() {
  echo -e "[${PURPLE}$(date +'%Y-%m-%d %H:%M:%S')${NOCOLOR}]: $1"
}

# allows the script to be run from anywhere
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(realpath "$SCRIPT_DIR/..")
CK8S_CMD="$REPO_ROOT/bin/ck8s"

if [ "$#" -ne 2 ]; then
  usage
fi

ACTION="$1"
TARGET="$2"

run_backup() {
  case "$1" in
    opensearch)
      log "Starting OpenSearch backup..."

      local user="admin"
      local password
      password=$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq '.opensearch.adminPassword')
      local os_url="https://opensearch.$(yq '.global.opsDomain' "${CK8S_CONFIG_PATH}/common-config.yaml")"
      log "OpenSearch URL: ${os_url}"

      log "Discovering snapshot repository name..."
      local snapshot_repo
      snapshot_repo=$(curl -kL -s -u "${user}:${password}" "${os_url}/_cat/repositories?v" | awk 'NR==2 {print $1}')
      if [ -z "$snapshot_repo" ]; then
        log "ERROR: Could not find OpenSearch snapshot repository."
        exit 1
      fi
      log "Found snapshot repository: ${snapshot_repo}"

      local snapshot_name="manual-snapshot-$(date +%Y%m%d%H%M%S)"
      log "Taking snapshot: ${snapshot_name}"
      curl -kL -u "${user}:${password}" -X PUT "${os_url}/_snapshot/${snapshot_repo}/${snapshot_name}" -H 'Content-Type: application/json' -d'
      {
        "indices": "*,-.opendistro_security",
        "include_global_state": false
      }
      '

      log "Waiting for snapshot to complete..."
      local status=""
      local retries=60 # 30 min timeout
      while [ $retries -gt 0 ]; do
        status=$(curl -kL -s -u "${user}:${password}" "${os_url}/_snapshot/${snapshot_repo}/${snapshot_name}" | jq -r '.snapshots[0].state')
        log "Current snapshot status: ${status}"

        if [ "$status" = "SUCCESS" ]; then
          log "OpenSearch backup successfully completed."
          return
        elif [ "$status" = "FAILED" ] || [ "$status" = "PARTIAL" ]; then
          log "ERROR: OpenSearch snapshot failed with status: ${status}"
          exit 1
        fi

        sleep 30
        retries=$((retries - 1))
      done

      log "ERROR: Timeout waiting for OpenSearch snapshot to complete."
      exit 1
      ;;
    harbor)
      log "Starting Harbor backup..."
      local backup_job_name="harbor-backup-manual-$(date +%Y%m%d%H%M%S)"
      log "Creating on-demand backup job: $backup_job_name"

      "$CK8S_CMD" ops kubectl sc -n harbor create job "$backup_job_name" --from=cronjob/harbor-backup-cronjob

      log "Waiting for backup job to complete..."
      "$CK8S_CMD" ops kubectl sc -n harbor wait --for=condition=complete "job/$backup_job_name" --timeout=30m

      log "Backup complete. Deleting job: $backup_job_name"
      "$CK8S_CMD" ops kubectl sc -n harbor delete job "$backup_job_name"

      log "Harbor backup successfully completed."
      ;;
    rclone)
      log "Starting Rclone backup..."

      # Check if rclone-sync is enabled before continuing
      log "Checking for rclone-sync cronjobs"
      local cronjob_list
      cronjob_list=$("$CK8S_CMD" ops kubectl sc -n rclone get cronjobs -lapp.kubernetes.io/instance=rclone-sync -oname)

      if [ -z "$cronjob_list" ]; then
        log "ERROR: No rclone-sync cronjobs found."
        log "Please ensure rclone sync is enabled in your configuration and has been applied."
        exit 1
      fi
      local total_jobs
      total_jobs=$(echo "$cronjob_list" | wc -w)
      log "Found ${total_jobs} cronjobs."

      # Create jobs from cronjobs
      for cronjob in $cronjob_list; do
        "$CK8S_CMD" ops kubectl sc -n rclone create job --from "${cronjob}" "${cronjob/#cronjob.batch\/}"
        local job_name=${cronjob/#cronjob.batch\/}
        log "Creating job '${job_name}' from '${cronjob}' cronjob..."
      done

      job_list=$("$CK8S_CMD" ops kubectl sc -n rclone get jobs -lapp.kubernetes.io/instance=rclone-sync -oname)

      log "Waiting for all ${total_jobs} rclone jobs to complete..."
      local retries=480 # these can take a really long time depending on content, so the timeout is set to 4 hours
      while [ $retries -gt 0 ]; do
        
        local job_statuses
        job_statuses=$("$CK8S_CMD" ops kubectl sc -n rclone get jobs -lapp.kubernetes.io/instance=rclone-sync -o json)
        
        local succeeded
        succeeded=$(echo "$job_statuses" | jq '[.items[] | select(.status.succeeded == 1)] | length')
        local failed
        failed=$(echo "$job_statuses" | jq '[.items[] | select(.status.failed > 0)] | length')
        local active
        active=$(echo "$job_statuses" | jq '[.items[] | select(.status.active == 1)] | length')

        log "Job Status -> Total: ${total_jobs} | Succeeded: ${succeeded} | Failed: ${failed} | Active: ${active}"

        if [ "$active" -eq 0 ]; then
          break
        fi

        sleep 30
        retries=$((retries - 1))
      done

      # check if all jobs succeeded or not
      if [ "$(echo "$job_statuses" | jq '[.items[] | select(.status.succeeded == 1)] | length')" -ne "$total_jobs" ]; then
        log "ERROR: Not all rclone jobs succeeded. Please check the logs for failed jobs."
        exit 1
      fi

      log "Cleaning up..."
      for job in $job_list; do
        "$CK8S_CMD" ops kubectl sc -n rclone delete "$job" --ignore-not-found=true
      done

      log "Rclone backup successfully completed."
      ;;
    velero)
      log "Starting Velero backup..."

      local backup_name="manual-backup-$(date +%Y%m%d%H%M%S)"
      log "Creating Velero backup: ${backup_name}"

      "$CK8S_CMD" ops velero wc backup create "$backup_name" --from-schedule velero-daily-backup

      log "Waiting for backup to complete..."
      local phase=""
      local retries=90
      while [ $retries -gt 0 ]; do
        phase=$( "$CK8S_CMD" ops velero wc backup describe "$backup_name" -o json | jq -r .phase )
        log "Current backup phase: ${phase}"

        if [ "$phase" = "Completed" ]; then
          log "Velero backup successfully completed."
          return
        elif [[ "$phase" =~ Failed|PartiallyFailed|Deleting ]]; then
          log "ERROR: Velero backup failed or was deleted with phase: ${phase}"
          exit 1
        fi

        sleep 30
        retries=$((retries - 1))
      done

      log "ERROR: Timeout waiting for Velero backup to complete."
      exit 1
      ;;
    *)
      log "Error: Invalid backup target '$1'."
      usage
      ;;
  esac
}

run_restore() {
  case "$1" in
    opensearch)
      log "Starting OpenSearch restore..."
      
      local user="admin"
      local password
      password=$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq '.opensearch.adminPassword')
      local os_url="https://opensearch.$(yq '.global.opsDomain' "${CK8S_CONFIG_PATH}/common-config.yaml")"
      log "OpenSearch URL: ${os_url}"

      log "Discovering snapshot repository name..."
      local snapshot_repo
      snapshot_repo=$(curl -kL -s -u "${user}:${password}" "${os_url}/_cat/repositories?v" | awk 'NR==2 {print $1}')
      if [ -z "$snapshot_repo" ]; then
        log "ERROR: Could not find OpenSearch snapshot repository."
        exit 1
      fi
      log "Found snapshot repository: ${snapshot_repo}"

      log "Finding latest successful snapshot..."
      local latest_snapshot
      latest_snapshot=$(curl -kL -s -u "${user}:${password}" -X GET "${os_url}/_snapshot/${snapshot_repo}/_all" | jq -r '.snapshots | map(select(.state == "SUCCESS")) | sort_by(.start_time_in_millis) | .[-1].snapshot')
      if [ -z "$latest_snapshot" ] || [ "$latest_snapshot" = "null" ]; then
          log "ERROR: No successful snapshots found to restore."
          exit 1
      fi
      log "Found latest snapshot to restore: ${latest_snapshot}"

      local indices_to_restore="kubernetes-*,kubeaudit-*,other-*,authlog-*"
      log "Will restore indices matching pattern: ${indices_to_restore}"

      log "Closing existing indices matching the restore pattern..."
      curl -kL -s -u "${user}:${password}" -X POST "${os_url}/${indices_to_restore}/_close?pretty"

      log "Starting restore from snapshot ${latest_snapshot}..."
      curl -kL -s -u "${user}:${password}" -X POST "${os_url}/_snapshot/${snapshot_repo}/${latest_snapshot}/_restore?pretty" -H 'Content-Type: application/json' -d'
      {
        "indices": "'"${indices_to_restore}"'"
      }
      '

      log "Waiting for cluster health to become green..."
      local status=""
      local retries=60 # 30 min timeout
      while [ $retries -gt 0 ]; do
        status=$(curl -kL -s -u "${user}:${password}" "${os_url}/_cluster/health" | jq -r '.status')
        log "Current cluster status: ${status}"

        if [ "$status" = "green" ]; then
          log "OpenSearch restore complete and cluster is healthy."
          return
        fi

        sleep 30
        retries=$((retries - 1))
      done

      log "ERROR: Timeout waiting for OpenSearch cluster to become healthy after restore."
      exit 1
      ;;
    harbor)
      log "Starting Harbor restore..."

      "$CK8S_CMD" harbor-restore

      log "Harbor restore successfully completed."
      ;;
    rclone)
      log "Starting Rclone restore..."

      # Check if rclone-restore is enabled before continuing
      log "Checking for rclone-restore cronjobs"
      local cronjob_list
      cronjob_list=$("$CK8S_CMD" ops kubectl sc -n rclone get cronjobs -lapp.kubernetes.io/instance=rclone-restore -oname)

      if [ -z "$cronjob_list" ]; then
        log "ERROR: No rclone-restore cronjobs found."
        log "Please ensure rclone restore is enabled in your configuration and has been applied."
        exit 1
      fi
      local total_jobs
      total_jobs=$(echo "$cronjob_list" | wc -w)
      log "Found ${total_jobs} cronjobs."

      # Create jobs from cronjobs
      for cronjob in $cronjob_list; do
        "$CK8S_CMD" ops kubectl sc -n rclone create job --from "${cronjob}" "${cronjob/#cronjob.batch\/}"
        local job_name=${cronjob/#cronjob.batch\/}
        log "Creating job '${job_name}' from '${cronjob}' cronjob..."
      done

      local job_list
      job_list=$("$CK8S_CMD" ops kubectl sc -n rclone get jobs -lapp.kubernetes.io/instance=rclone-restore -oname)

      log "Waiting for all ${total_jobs} rclone jobs to complete..."
      local retries=480 # 4 hour timeout
      while [ $retries -gt 0 ]; do
        
        local job_statuses
        job_statuses=$("$CK8S_CMD" ops kubectl sc -n rclone get jobs -lapp.kubernetes.io/instance=rclone-restore -o json)
        
        local succeeded
        succeeded=$(echo "$job_statuses" | jq '[.items[] | select(.status.succeeded == 1)] | length')
        local failed
        failed=$(echo "$job_statuses" | jq '[.items[] | select(.status.failed > 0)] | length')
        local active
        active=$(echo "$job_statuses" | jq '[.items[] | select(.status.active == 1)] | length')

        log "Job Status -> Total: ${total_jobs} | Succeeded: ${succeeded} | Failed: ${failed} | Active: ${active}"

        if [ "$active" -eq 0 ]; then
          break
        fi

        sleep 30
        retries=$((retries - 1))
      done

      # Check if all jobs succeeded
      if [ "$(echo "$job_statuses" | jq '[.items[] | select(.status.succeeded == 1)] | length')" -ne "$total_jobs" ]; then
        log "ERROR: Not all rclone jobs succeeded. Please check the logs for failed jobs."
        exit 1
      fi

      log "Cleaning up..."
      for job in $job_list; do
        "$CK8S_CMD" ops kubectl sc -n rclone delete "$job" --ignore-not-found=true
      done

      log "Rclone restore successfully completed."
      ;;
    velero)
      log "Starting Velero restore..."

      log "Finding latest completed Velero backup..."
      local latest_backup
      latest_backup=$( "$CK8S_CMD" ops velero wc backup get -o json | jq -r '.items | map(select(.status.phase == "Completed")) | sort_by(.metadata.creationTimestamp) | .[-1].metadata.name' )

      if [ -z "$latest_backup" ] || [ "$latest_backup" = "null" ]; then
        log "ERROR: No completed Velero backups found to restore from."
        exit 1
      fi
      log "Found latest backup to restore: ${latest_backup}"

      log "Deleting Alertmanager secret..."
      "$CK8S_CMD" ops kubectl wc delete secret -n alertmanager alertmanager-kube-prometheus-stack-alertmanager --ignore-not-found=true

      local restore_name="restore-$(date +%Y%m%d%H%M%S)"
      log "Creating restore '${restore_name}' from backup '${latest_backup}'"
      "$CK8S_CMD" ops velero wc restore create "$restore_name" --from-backup "$latest_backup"

      log "Waiting for restore to complete..."
      local phase=""
      local retries=60 # 30 min timeout
      while [ $retries -gt 0 ]; do
        phase=$( "$CK8S_CMD" ops velero wc restore get "$restore_name" -o json | jq -r .status.phase )
        log "Current restore phase: ${phase}"

        if [ "$phase" = "Completed" ]; then
          log "Velero restore successfully completed."
          return
        elif [[ "$phase" =~ Failed|PartiallyFailed ]]; then
          log "ERROR: Velero restore failed with phase: ${phase}"
          exit 1
        fi

        sleep 30
        retries=$((retries - 1))
      done
      
      log "ERROR: Timeout waiting for Velero restore to complete."
      exit 1
      ;;
    *)
      log "Error: Invalid restore target '$1'."
      usage
      ;;
  esac
}

case "$ACTION" in
  backup)
    run_backup "$TARGET"
    ;;
  restore)
    run_restore "$TARGET"
    ;;
  *)
    log "Error: Invalid action '$ACTION'."
    usage
    ;;
esac
