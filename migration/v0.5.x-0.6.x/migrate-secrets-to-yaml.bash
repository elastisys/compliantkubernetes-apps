#!/bin/bash
#Obs! should only be run from migrate-secrets-entrypoint
set -euo pipefail
SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
file=${CK8S_CONFIG_PATH}/secrets.yaml
if [[ -f "$file" ]]; then
    echo "file: $file already exists. Delete existing file if you want to replace it."
    exit 1
fi
# shellcheck disable=SC1090
source "${CK8S_CONFIG_PATH}/config.sh"
# shellcheck disable=SC1090
source "${SCRIPTS_PATH}/../../bin/common.bash"

: "${CLOUD_PROVIDER:?Missing CLOUD_PROVIDER}"
: "${S3_ACCESS_KEY:?Missing S3_ACCESS_KEY}"
: "${S3_SECRET_KEY:?Missing S3_SECRET_KEY}"
: "${GRAFANA_PWD:?Missing GRAFANA_PWD}"
: "${GRAFANA_CLIENT_SECRET:?Missing GRAFANA_CLIENT_SECRET}"
: "${S3_ACCESS_KEY:?Missing S3_ACCESS_KEY}"
: "${CUSTOMER_PROMETHEUS_PWD:?Missing CUSTOMER_PROMETHEUS_PWD}"
: "${CUSTOMER_ALERTMANAGER_PWD:?Missing CUSTOMER_ALERTMANAGER_PWD}"
: "${HARBOR_PWD:?Missing HARBOR_PWD}"
: "${HARBOR_DB_PWD:?Missing HARBOR_DB_PWD}"
: "${HARBOR_CLIENT_SECRET:?Missing HARBOR_CLIENT_SECRET}"
: "${HARBOR_XSRF:?Missing HARBOR_XSRF}"
: "${HARBOR_JOBSERVICE_SECRET:?Missing HARBOR_JOBSERVICE_SECRET}"
: "${HARBOR_CORE_SECRET:?Missing HARBOR_CORE_SECRET}"
: "${HARBOR_REGISTRY_SECRET:?Missing HARBOR_REGISTRY_SECRET}"
: "${INFLUXDB_PWD:?Missing INFLUXDB_PWD}"
: "${KUBELOGIN_CLIENT_SECRET:?Missing KUBELOGIN_CLIENT_SECRET}"
: "${CUSTOMER_GRAFANA_PWD:?Missing CUSTOMER_GRAFANA_PWD}"
# Elasticsearch secrets
: "${ES_ADMIN_PWD:?Missing ES_ADMIN_PWD}"
: "${ES_CONFIGURER_PWD:?Missing ES_CONFIGURER_PWD}"
: "${ES_KIBANASERVER_PWD:?Missing ES_KIBANASERVER_PWD}"
: "${ES_ADMIN_PWD_HASH:?Missing ES_ADMIN_PWD_HASH}"
: "${ES_CONFIGURER_PWD_HASH:?Missing ES_CONFIGURER_PWD_HASH}"
: "${ES_KIBANASERVER_PWD_HASH:?Missing ES_KIBANASERVER_PWD_HASH}"
: "${ES_FLUENTD_PWD:?Missing ES_FLUENTD_PWD}"
: "${ES_CURATOR_PWD:?Missing ES_CURATOR_PWD}"
: "${ES_SNAPSHOTTER_PWD:?Missing ES_SNAPSHOTTER_PWD}"
: "${ES_METRICS_EXPORTER_PWD:?Missing ES_METRICS_EXPORTER_PWD}"
: "${ES_KIBANA_COOKIE_ENC_KEY:?Missing ES_KIBANA_COOKIE_ENC_KEY}"

OS_PASSWORD=${OS_PASSWORD:-somelongsecret}

if [[ $CLOUD_PROVIDER == "exoscale" ]]; then
    cat <<EOF > "$file"
exoscale:
  apiKey: ${TF_VAR_exoscale_api_key:?Missing exoscale api key}
  secretKey: ${TF_VAR_exoscale_secret_key:?Missing exoscale secret key}
EOF
elif [[ $CLOUD_PROVIDER == "citycloud" || $CLOUD_PROVIDER == "safespring"  ]]; then
    cat <<EOF > "$file"
citycloud:
  password: $OS_PASSWORD
  awsAccessKey: $AWS_ACCESS_KEY_ID
  awsSecretKey: $AWS_SECRET_ACCESS_KEY
EOF
elif [[ $CLOUD_PROVIDER == "safespring" ]]; then
    cat <<EOF > "$file"
safespring:
  password: $OS_PASSWORD
  awsAccessKey: $AWS_ACCESS_KEY_ID
  awsSecretKey: $AWS_SECRET_ACCESS_KEY
EOF
elif [[ $CLOUD_PROVIDER == "aws" ]]; then
    cat <<EOF > "$file"
aws:
  accessKey: ${TF_VAR_aws_access_key:?Missing AWS access key}
  secretKey: ${TF_VAR_aws_secret_key:?Missing AWS secret key}
  dnsAccessKey: ${TF_VAR_dns_access_key:?Missing AWS DNS access key}
  dnsSecretKey: ${TF_VAR_dns_secret_key:?Missing AWS DNS secret key}
EOF
fi
cat <<EOF >> "$file"
s3:
  accessKey: $S3_ACCESS_KEY
  secretKey: $S3_SECRET_KEY
grafana:
  password: $GRAFANA_PWD
  clientSecret: $GRAFANA_CLIENT_SECRET
customer:
  grafanaPassword: $CUSTOMER_GRAFANA_PWD
  prometheusPassword: $CUSTOMER_PROMETHEUS_PWD
  alertmanagerPassword: $CUSTOMER_ALERTMANAGER_PWD
harbor:
  password: $HARBOR_PWD
  databasePassword: $HARBOR_DB_PWD
  clientSecret: $HARBOR_CLIENT_SECRET
  xsrf: $HARBOR_XSRF
  coreSecret: $HARBOR_CORE_SECRET
  jobserviceSecret: $HARBOR_JOBSERVICE_SECRET
  registrySecret: $HARBOR_REGISTRY_SECRET
influxDB:
  password: $INFLUXDB_PWD
elasticsearch:
  adminPassword: $ES_ADMIN_PWD
  adminHash: $ES_ADMIN_PWD_HASH
  configurerPassword: $ES_CONFIGURER_PWD
  configurerHash: $ES_CONFIGURER_PWD_HASH
  kibanaPassword: $ES_KIBANASERVER_PWD
  kibanaHash: $ES_KIBANASERVER_PWD_HASH
  fluentdPassword: $ES_FLUENTD_PWD
  curatorPassword: $ES_CURATOR_PWD
  snapshotterPassword: $ES_SNAPSHOTTER_PWD
  metricsExporterPassword: $ES_METRICS_EXPORTER_PWD
  kibanaCookieEncKey: $ES_KIBANA_COOKIE_ENC_KEY
alerts:
  slack:
    apiUrl: ${SLACK_API_URL:-"unused"}
  opsGenie:
    apiKey: ${OPSGENIE_API_KEY:-"unused"}
dex:
  staticPassword: ${DEX_STATIC_PWD:-"unused"}
  googleClientID: ${GOOGLE_CLIENT_ID:-"unused"}
  googleClientSecret: ${GOOGLE_CLIENT_SECRET:-"unused"}
  kubeloginClientSecret: ${KUBELOGIN_CLIENT_SECRET:-"unused"}
EOF

sops_encrypt "$file"
echo "OBS! you might get some valies in $file with the value unused"
echo "These were unset variables and can be removed"
