#!/bin/bash
# OBS! the lists containing customer namepsaces, admins and allowed oauth will not be migrated correctly. Please check these manually.
# The same is true for External traffic whitelisting.
set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
file_wc=${CK8S_CONFIG_PATH}/wc-config.yaml
if [[ -f $file_wc ]]; then
    echo "file: $file_wc already exists. Delete existing file if you want to replace it."
    exit 1
fi
file_sc=${CK8S_CONFIG_PATH}/sc-config.yaml
if [[ -f $file_sc ]]; then
    echo "file: $file_sc already exists. Delete existing file if you want to replace it."
    exit 1
fi
# shellcheck disable=SC1090
source "$CK8S_CONFIG_PATH/config.sh"

: "${CLOUD_PROVIDER:?Missing CLOUD_PROVIDER}"
: "${ENVIRONMENT_NAME:?Missing ENVIRONMENT_NAME}"
: "${TF_VAR_dns_prefix:?Missing TF_VAR_dns_prefix}"

: "${S3_REGION:?Missing S3_REGION}"
: "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"

# Inlfux backup variables.
: "${INFLUX_ADDR:?Missing INFLUX_ADDR}"
: "${S3_INFLUX_BUCKET_NAME:?Missing S3_INFLUX_BUCKET_NAME}"

# Fluentd aggregator S3 output variables.
: "${S3_SC_FLUENTD_BUCKET_NAME:?Missing S3_SC_FLUENTD_BUCKET_NAME}"

: "${ENABLE_PSP:?Missing ENABLE_PSP}"
: "${ENABLE_HARBOR:?Missing ENABLE_HARBOR}"
: "${ENABLE_CUSTOMER_GRAFANA:?Missing ENABLE_CUSTOMER_GRAFANA}"
: "${OAUTH_ALLOWED_DOMAINS:?Missing OAUTH_ALLOWED_DOMAINS}"
: "${ENABLE_CK8SDASH_SC:?Missing ENABLE_CK8SDASH_SC}"
: "${ENABLE_CK8SDASH_WC:?Missing ENABLE_CK8SDASH_WC}"

# Elasticsearch
: "${ES_MASTER_COUNT:?Missing ES_MASTER_COUNT}"
: "${ES_MASTER_STORAGE_SIZE:?Missing ES_MASTER_STORAGE_SIZE}"
: "${ES_MASTER_CPU_REQUEST:?Missing ES_MASTER_CPU_REQUEST}"
: "${ES_MASTER_MEM_REQUEST:?Missing ES_MASTER_MEM_REQUEST}"
: "${ES_MASTER_CPU_LIMIT:?Missing ES_MASTER_CPU_LIMIT}"
: "${ES_MASTER_MEM_LIMIT:?Missing ES_MASTER_MEM_LIMIT}"
: "${ES_MASTER_JAVA_OPTS:?Missing ES_MASTER_JAVA_OPTS}"
: "${ES_DATA_COUNT:?Missing ES_DATA_COUNT}"
: "${ES_DATA_STORAGE_SIZE:?Missing ES_DATA_STORAGE_SIZE}"
: "${ES_DATA_CPU_REQUEST:?Missing ES_DATA_CPU_REQUEST}"
: "${ES_DATA_MEM_REQUEST:?Missing ES_DATA_MEM_REQUEST}"
: "${ES_DATA_CPU_LIMIT:?Missing ES_DATA_CPU_LIMIT}"
: "${ES_DATA_MEM_LIMIT:?Missing ES_DATA_MEM_LIMIT}"
: "${ES_DATA_JAVA_OPTS:?Missing ES_DATA_JAVA_OPTS}"
: "${ES_CLIENT_COUNT:?Missing ES_CLIENT_COUNT}"
: "${ES_CLIENT_CPU_REQUEST:?Missing ES_CLIENT_CPU_REQUEST}"
: "${ES_CLIENT_MEM_REQUEST:?Missing ES_CLIENT_MEM_REQUEST}"
: "${ES_CLIENT_CPU_LIMIT:?Missing ES_CLIENT_CPU_LIMIT}"
: "${ES_CLIENT_MEM_LIMIT:?Missing ES_CLIENT_MEM_LIMIT}"
: "${ES_CLIENT_JAVA_OPTS:?Missing ES_CLIENT_JAVA_OPTS}"
: "${ES_KUBEAUDIT_RETENTION_SIZE:?Missing ES_KUBEAUDIT_RETENTION_SIZE}"
: "${ES_KUBEAUDIT_RETENTION_AGE:?Missing ES_KUBEAUDIT_RETENTION_AGE}"
: "${ES_KUBERNETES_RETENTION_SIZE:?Missing ES_KUBERNETES_RETENTION_SIZE}"
: "${ES_KUBERNETES_RETENTION_AGE:?Missing ES_KUBERNETES_RETENTION_AGE}"
: "${ES_OTHER_RETENTION_SIZE:?Missing ES_OTHER_RETENTION_SIZE}"
: "${ES_OTHER_RETENTION_AGE:?Missing ES_OTHER_RETENTION_AGE}"
: "${ES_ROLLOVER_SIZE:?Missing ES_ROLLOVER_SIZE}"
: "${ES_ROLLOVER_AGE:?Missing ES_ROLLOVER_AGE}"
: "${ES_SNAPSHOT_MIN:?Missing ES_SNAPSHOT_MIN}"
: "${ES_SNAPSHOT_MAX:?Missing ES_SNAPSHOT_MAX}"
: "${ES_SNAPSHOT_AGE_SECONDS:?Missing ES_SNAPSHOT_AGE_SECONDS}"
: "${ES_SNAPSHOT_RETENTION_SCHEDULE:?Missing ES_SNAPSHOT_RETENTION_SCHEDULE}"
: "${ES_SNAPSHOT_SCHEDULE:?Missing ES_SNAPSHOT_SCHEDULE}"

# Alerting
: "${ALERT_TO:?Missing ALERT_TO}"
: "${ENABLE_HEARTBEAT:?Missing ENABLE_HEARTBEAT}"

OPSGENIE_HEARTBEAT_NAME=${OPSGENIE_HEARTBEAT_NAME:-set-name-here}
ECK_RESTORE_CLUSTER=${ECK_RESTORE_CLUSTER:-false}
RESTORE_VELERO=${RESTORE_VELERO:-false}
VELERO_BACKUP_NAME=${VELERO_BACKUP_NAME:-latest}
OS_USERNAME=${OS_USERNAME:-username}

if [[ $CLOUD_PROVIDER == "citycloud" || $CLOUD_PROVIDER == "safespring"  ]]; then
    cat <<EOF > "$file_wc"
citycloud:
  username: $OS_USERNAME
  identityApiVersion: $OS_IDENTITY_API_VERSION
  authURL: $OS_AUTH_URL
  regionName: $OS_REGION_NAME
  projectDomainName: $OS_PROJECT_DOMAIN_NAME
  userDomainName: $OS_USER_DOMAIN_NAME
  projectName: $OS_PROJECT_NAME
  projectID: $OS_PROJECT_ID
  tenantName: $OS_TENANT_NAME
  authVersion: $OS_AUTH_VERSION

EOF
fi
cat <<EOF >> "$file_wc"
global:
  ck8sVersion: $CK8S_VERSION
  cloudProvider: $CLOUD_PROVIDER
  environmentName: $ENVIRONMENT_NAME
  dnsPrefix: $TF_VAR_dns_prefix
  baseDomain: $ECK_BASE_DOMAIN
  opsDomain: $ECK_OPS_DOMAIN
  certType: $CERT_TYPE
  storageClass: nfs-client
  clusterDns: $CLUSTER_DNS


s3:
  region: $S3_REGION
  regionAddress: $S3_REGION_ADDRESS
  regionEndpoint: $S3_REGION_ENDPOINT
  buckets:
    harbor: $S3_HARBOR_BUCKET_NAME
    velero: $S3_VELERO_BUCKET_NAME
    elasticSearch: $S3_ES_BACKUP_BUCKET_NAME
    influx: $S3_INFLUX_BUCKET_NAME
    scFluentd: $S3_SC_FLUENTD_BUCKET_NAME

customer:
  namespaces:
    - demo
  adminUsers:
    - admin@example.com
  alertmanager:
    enabled: $ENABLE_CUSTOMER_ALERTMANAGER
    ingress:
      enable: $ENABLE_CUSTOMER_ALERTMANAGER_INGRESS

falco:
  enabled: $ENABLE_FALCO
  resources:
    limits:
      cpu: 200m
      memory: 1024Mi
    requests:
      cpu: 100m
      memory: 512Mi
  tolerations:
    - key: "node-role.kubernetes.io/master"
      effect: "NoSchedule"
  affinity: {}
  nodeSelector: {}
  alerts:
    enabled: $ENABLE_FALCO_ALERTS
    # supported: alertmanager|slack
    type: $FALCO_ALERTS_TYPE
    priority: $FALCO_ALERTS_PRIORITY
    hostPort: $FALCO_ALERTS_ALERTMANAGER_HOSTPORT
    # if type=slack falco.alerts.slackWebhook must be set in the secrets yaml file

prometheus:
  storage:
    size: $PROMETHEUS_STORAGE_SIZE_WC
  retention:
    size: $PROMETHEUS_RETENTION_SIZE_WC
    age:  $PROMETHEUS_RETENTION_WC
    alertManager: $ALERTMANAGER_RETENTION
  resources:
    requests:
      memory: 1Gi
      cpu: 0.3
    limits:
      memory: 2Gi
      cpu: 1
  tolerations: []
  affinity: {}
  nodeSelector: {}

psp:
  enabled: $ENABLE_PSP

opa:
  enabled: $ENABLE_OPA
  imageRegistry:
    enabled: true
    enforcement: $OPA_ENFORCEMENT_IMAGE_REGISTRY
    URL: harbor.$ECK_BASE_DOMAIN
  networkPolicies:
    enabled: true
    enforcement: $OPA_ENFORCEMENT_NETWORKPOLICIES
  resourceRequests:
    enabled: true
    enforcement: $OPA_ENFORCEMENT_RESOURCE_REQUESTS

alerts:
  alertTo: $ALERT_TO
  opsGenieHeartbeat:
    enable: $ENABLE_HEARTBEAT
    name: $OPSGENIE_HEARTBEAT_NAME

elasticsearch:
  masterNode:
    count: $ES_MASTER_COUNT
  dataNode:
    count: $ES_DATA_COUNT
  clientNode:
    count: $ES_CLIENT_COUNT

fluentd:
  resources:
    limits:
      cpu: 200m
      memory: 500Mi
    requests:
      cpu: 200m
      memory: 500Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}
  extraConfigMaps: {}
  customer:
    resources:
      limits:
        cpu: 200m
        memory: 500Mi
      requests:
        cpu: 200m
        memory: 500Mi
    tolerations: []
    affinity: {}
    nodeSelector: {}

ck8sdash:
  enabled: $ENABLE_CK8SDASH_WC
  tolerations: []
  affinity: {}
  nodeSelector: {}
  nginx:
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 100m
  server:
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 100m

externalTrafficPolicy:
  local: $EXTERNAL_TRAFFIC_POLICY_LOCAL
  whitelistRange:
    global: "0.0.0.0/0"
    ck8sdash: false
    prometheus: false

nfsProvisioner:
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 128Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}

nginxIngress:
  controller:
    resources:
      limits:
        cpu: 100m
        memory: 64Mi
      requests:
        cpu: 100m
        memory: 64Mi
    tolerations:
      - key: "nodeType"
        operator: "Exists"
        effect: "NoSchedule"
    affinity: {}
    nodeSelector: {}
  defaultBackend:
    resources:
      limits:
        cpu: 10m
        memory: 20Mi
      requests:
        cpu: 10m
        memory: 20Mi
    tolerations:
      - key: "nodeType"
        operator: "Equal"
        value: "elastisys"
        effect: "NoSchedule"
    affinity: {}
    nodeSelector: {}


velero:
  resources:
    limits:
      cpu: 200m
      memory: 200Mi
    requests:
      cpu: 100m
      memory: 100Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}
EOF
if [[ $CLOUD_PROVIDER == "citycloud" || $CLOUD_PROVIDER == "safespring"  ]]; then
    cat <<EOF > "$file_sc"
citycloud:
  username: $OS_USERNAME
  identityApiVersion: $OS_IDENTITY_API_VERSION
  authURL: $OS_AUTH_URL
  regionName: $OS_REGION_NAME
  projectDomainName: $OS_PROJECT_DOMAIN_NAME
  userDomainName: $OS_USER_DOMAIN_NAME
  projectName: $OS_PROJECT_NAME
  projectID: $OS_PROJECT_ID
  tenantName: $OS_TENANT_NAME
  authVersion: $OS_AUTH_VERSION

EOF
fi
cat <<EOF >> "$file_sc"
global:
  ck8sVersion: $CK8S_VERSION
  cloudProvider: $CLOUD_PROVIDER
  environmentName: $ENVIRONMENT_NAME
  dnsPrefix: $TF_VAR_dns_prefix
  baseDomain: $ECK_BASE_DOMAIN
  opsDomain: $ECK_OPS_DOMAIN
  certType: $CERT_TYPE
  storageClass: nfs-client
  clusterDns: $CLUSTER_DNS

s3:
  region: $S3_REGION
  regionAddress: $S3_REGION_ADDRESS
  regionEndpoint: $S3_REGION_ENDPOINT
  buckets:
    harbor: $S3_HARBOR_BUCKET_NAME
    velero: $S3_VELERO_BUCKET_NAME
    elasticSearch: $S3_ES_BACKUP_BUCKET_NAME
    influx: $S3_INFLUX_BUCKET_NAME
    scFluentd: $S3_SC_FLUENTD_BUCKET_NAME

customer:
  grafana:
    enabled: $ENABLE_CUSTOMER_GRAFANA
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
    tolerations: []
    affinity: {}
    nodeSelector: {}
  alertmanager:
    enabled: $ENABLE_CUSTOMER_ALERTMANAGER
    ingress:
      enable: $ENABLE_CUSTOMER_ALERTMANAGER_INGRESS

harbor:
  enabled: $ENABLE_HARBOR
  tolerations: []
  affinity: {}
  nodeSelector: {}
  core:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m
  jobservice:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m
  registry:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m
  notary:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m

prometheus:
  storage:
    size: $PROMETHEUS_STORAGE_SIZE_SC
  retention:
    size: $PROMETHEUS_RETENTION_SIZE_SC
    age:  $PROMETHEUS_RETENTION_SC
    alertmanager: $ALERTMANAGER_RETENTION
  resources:
    requests:
      memory: 1Gi
      cpu: 0.3
    limits:
      memory: 2Gi
      cpu: 1
  tolerations: []
  affinity: {}
  nodeSelector: {}
  wcScraper:
    resources:
      requests:
        memory: 1Gi
        cpu: 0.3
      limits:
        memory: 2Gi
        cpu: 1
    tolerations: []
    affinity: {}
    nodeSelector: {}

dex:
  # supported: google|aaa
  oidcProvider: google
  allowedDomains:
    - example.com
    - elastisys.com
  enableStaticLogin: true
  resources:
    limits:
      cpu: 100m
      memory: 50Mi
    requests:
      cpu: 100m
      memory: 50Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}

psp:
  enabled: $ENABLE_PSP

elasticsearch:
  masterNode:
    count: $ES_MASTER_COUNT
    storageSize: $ES_MASTER_STORAGE_SIZE
    javaOpts: $ES_MASTER_JAVA_OPTS
    resources:
      requests:
        memory: $ES_MASTER_MEM_REQUEST
        cpu: $ES_MASTER_CPU_REQUEST
      limits:
        memory: $ES_MASTER_MEM_LIMIT
        cpu: $ES_MASTER_CPU_LIMIT
  dataNode:
    count: $ES_DATA_COUNT
    storageSize: $ES_DATA_STORAGE_SIZE
    javaOpts: $ES_DATA_JAVA_OPTS
    resources:
      requests:
        memory: $ES_DATA_MEM_REQUEST
        cpu: $ES_DATA_CPU_REQUEST
      limits:
        memory: $ES_DATA_MEM_LIMIT
        cpu: $ES_DATA_CPU_LIMIT
  clientNode:
    count: $ES_CLIENT_COUNT
    storageSize: $ES_CLIENT_STORAGE_SIZE
    javaOpts: $ES_CLIENT_JAVA_OPTS
    resources:
      requests:
        memory: $ES_CLIENT_MEM_REQUEST
        cpu: $ES_CLIENT_CPU_REQUEST
      limits:
        memory: $ES_CLIENT_MEM_LIMIT
        cpu: $ES_CLIENT_CPU_LIMIT

  storageClass: local-storage
  retention:
    kubeAuditSize: $ES_KUBEAUDIT_RETENTION_SIZE
    kubeAuditAge: $ES_KUBEAUDIT_RETENTION_AGE
    kubernetesSize: $ES_KUBERNETES_RETENTION_SIZE
    kubernetesAge: $ES_KUBERNETES_RETENTION_AGE
    otherSize: $ES_OTHER_RETENTION_SIZE
    otherAge: $ES_OTHER_RETENTION_AGE
    rolloverSize: $ES_ROLLOVER_SIZE
    rolloverAge: $ES_ROLLOVER_AGE
  snapshot:
    min: $ES_SNAPSHOT_MIN
    max: $ES_SNAPSHOT_MAX
    ageSeconds: $ES_SNAPSHOT_AGE_SECONDS
    retentionSchedule: $ES_SNAPSHOT_RETENTION_SCHEDULE
    backupSchedule: $ES_SNAPSHOT_SCHEDULE
  tolerations: []
  affinity: {}
  nodeSelector: {}

fluentd:
  resources:
    limits:
      cpu: 500m
      memory: 200Mi
    requests:
      cpu: 100m
      memory: 200Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}
  aggregator:
    resources:
      limits:
        cpu: 500m
        memory: 1000Mi
      requests:
        cpu: 300m
        memory: 300Mi
    tolerations: []
    affinity: {}
    nodeSelector: {}

influxDB:
  user: $INFLUXDB_USER
  address: $INFLUX_ADDR
  retention:
    ageWc: $INFLUXDB_RETENTION_WC
    ageSc: $INFLUXDB_RETENTION_SC
  resources:
    requests:
      memory: 4Gi
      cpu: 0.5
    limits:
      memory: 4Gi
      cpu: 2
  tolerations: []
  affinity: {}
  nodeSelector: {}

alerts:
  alertTo: $ALERT_TO
  opsGenieHeartbeat:
    enable: $ENABLE_HEARTBEAT
    url: "https://api.eu.opsgenie.com/v2/heartbeats"
    name: $OPSGENIE_HEARTBEAT_NAME
  slack:
    channel: "techteam"
  opsGenie:
    apiUrl: "https://api.eu.opsgenie.com"

ck8sdash:
  enabled: $ENABLE_CK8SDASH_SC
  tolerations: []
  affinity: {}
  nodeSelector: {}
  nginx:
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 100m
  server:
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 100m

externalTrafficPolicy:
  local: $EXTERNAL_TRAFFIC_POLICY_LOCAL
  whitelistRange:
    global: "0.0.0.0/0"
    ck8sdash: false
    dex: false
    kibana: false
    elasticsearch: false
    harbor: false
    customerGrafana: false
    opsGrafana: false
    prometheusWc: false

nfsProvisioner:
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 128Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}

nginxIngress:
  controller:
    resources:
      limits:
        cpu: 100m
        memory: 64Mi
      requests:
        cpu: 100m
        memory: 64Mi
    tolerations:
      - key: "nodeType"
        operator: "Exists"
        effect: "NoSchedule"
    affinity: {}
    nodeSelector: {}
  defaultBackend:
    resources:
      limits:
        cpu: 10m
        memory: 20Mi
      requests:
        cpu: 10m
        memory: 20Mi
    tolerations:
      - key: "nodeType"
        operator: "Equal"
        value: "elastisys"
        effect: "NoSchedule"
    affinity: {}
    nodeSelector: {}

velero:
  resources:
    limits:
      cpu: 200m
      memory: 200Mi
    requests:
      cpu: 100m
      memory: 100Mi
  tolerations: []
  affinity: {}
  nodeSelector: {}

restore:
  cluster: $ECK_RESTORE_CLUSTER
  velero: $RESTORE_VELERO
  veleroBackupName: $VELERO_BACKUP_NAME
EOF

echo "OBS! the lists containing customer namepsaces, admins and allowed oauth will not be migrated correctly. Please check these manually."
echo "OBS! Traffic whitelisting will not be migrated correctly please check this manually."
