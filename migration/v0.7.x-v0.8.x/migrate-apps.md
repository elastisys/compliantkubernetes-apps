# Migrate v0.7.x-v0.8.0

You will need to follow these steps in order to upgrade each Compliant Kubernetes environment from v0.7.x to v0.8.0.
The instructions assume that you work from the root of the `compliantkubernetes-apps` repository, has the latest changes already pulled and configured `CK8S_CONFIG_PATH` correctly.

1. Checkout the new release: `git checkout v0.8.0`.

1. Update helm to v3.4.1.

1. The Helm repository `stable` has changed URL and has to be changed manually:
    `helm repo add "stable" "https://charts.helm.sh/stable" --force-update`

1. The blackbox chart has a changed dependency URL and has to be updated manually:
    `cd helmfile/charts/blackbox && helm dependency update && cd -`

1. Run init to get new defaults: `./bin/ck8s init`.

1. Run the migration script to update the object storage configuration: `./migration/v0.7.x-v0.8.x/migrate-object-storage.sh`

1. The following configuration options must be manually updated (in both `sc-config.yaml` and `wc-config.yaml` if applicable unless otherwise mentioned):

    - Move `nginxIngress.controller.daemonset.useHostPort` to `ingressNginx.controller.useHostPort`.
    - Move `useRegionEndpoint` from `elasticsearch` to `fluentd` in `sc-config.yaml`.
    - Remove `prometheus.retention.alertManager` from `wc-config.yaml`.
    - Update `falco.alerts.hostPort` to `"http://kube-prometheus-stack-alertmanager.monitoring:9093"` in `wc-config.yaml`
    - Please update the InfluxDB values, and make sure any new values match your old values when applicable.
      - `influxDB.address` removed
      - `influxDB.metrics.sizeWc` replaced by `influxDB.retention.sizeWC`
      - `influxDB.metrics.sizeSc` replaced by `influxDB.retention.sizeSC`
      - `influxDB.retention.ageWc` replaced by `influxDB.retention.durationWC`
      - `influxDB.retention.ageSc` replaced by `influxDB.retention.durationSC`
    - The config for opendistro has been changed.
      Please update the new defaults to match your old values.
      - `elasticsearch.tolerations` removed
      - `elasticsearch.nodeSelector` removed
      - `elasticsearch.affinity` removed
      - `elasticsearch.storageClass` replaced by `elasticsearch.dataNode.storageClass`
      - `elasticsearch.retention.kubeAuditSize` replaced by `elasticsearch.curator.retention.kubeAuditSizeGB`
      - `elasticsearch.retention.kubeAuditAge` replaced by `elasticsearch.curator.retention.kubeAuditAgeDays`
      - `elasticsearch.retention.kubernetesSize` replaced by `elasticsearch.curator.retention.kubernetesSizeGB`
      - `elasticsearch.retention.kubernetesAge` replaced by `elasticsearch.curator.retention.kubernetesAgeDays`
      - `elasticsearch.retention.otherSize` replaced by `elasticsearch.curator.retention.otherSizeGB`
      - `elasticsearch.retention.otherAge` replaced by `elasticsearch.curator.retention.otherAgeDays`
    - Make sure fluentd has a toleration to run on control plane nodes in `wc-config.yaml` under `fluentd.tolerations`:

      ```yaml
      - effect: NoSchedule
        key: "node-role.kubernetes.io/master"
        value: ""
      ```

1. Upgrade Workload cluster applications

    ```bash
    # Delete old prometheus-operator release and related resources
    ./bin/ck8s ops helm wc uninstall prometheus-operator -n monitoring
    ./bin/ck8s ops kubectl wc delete service/prometheus-operator-kubelet -n kube-system
    ./bin/ck8s ops kubectl wc delete pvc/prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0 -n monitoring

    # Delete old nginx release and namespace
    ./bin/ck8s ops helm wc -n nginx-ingress uninstall nginx-ingress && ./bin/ck8s ops kubectl wc delete namespace nginx-ingress

    # Bootstrap to get new CRDs and new namespace
    ./bin/ck8s bootstrap wc

    # Install new release of nginx
    ./bin/ck8s ops helmfile wc -l app=ingress-nginx -i apply

    # Install new release of prometheus
    ./bin/ck8s ops helmfile wc -l app=kube-prometheus-stack -i apply

    # Update everything else
    ./bin/ck8s apply wc
    ```

1. Upgrade Service cluster applications

    ```bash
    # Delete old prometheus-operator release and related resources
    ./bin/ck8s ops helm sc uninstall prometheus-operator -n monitoring
    ./bin/ck8s ops kubectl sc delete service/prometheus-operator-kubelet -n kube-system
    ./bin/ck8s ops kubectl sc delete pvc/prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0 -n monitoring

    # Delete old nginx release and namespace
    ./bin/ck8s ops helm sc -n nginx-ingress uninstall nginx-ingress && ./bin/ck8s ops kubectl sc delete namespace nginx-ingress

    # Bootstrap to get new CRDs and new namespace
    ./bin/ck8s bootstrap sc

    # Install new release of nginx
    ./bin/ck8s ops helmfile sc -l app=ingress-nginx -i apply

    # Install new release of prometheus
    ./bin/ck8s ops helmfile sc -l app=kube-prometheus-stack -i apply

    # Upgrade Elasticsearch
    ./bin/ck8s ops helmfile sc -l app=opendistro apply
    # Wait for master pod 0 to be up and for elasticsearch to have started
    # Reload security config
    ./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- chmod +x ./plugins/opendistro_security/tools/securityadmin.sh
    ./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- ./plugins/opendistro_security/tools/securityadmin.sh \
      -cd plugins/opendistro_security/securityconfig/ \
      -icl -nhnv \
      -cacert config/admin-root-ca.pem \
      -cert config/admin-crt.pem \
      -key config/admin-key.pem

    # Wait for release to finish

    ## Clean up old legacy index templates

    # Get elasticsearch admin password
    es_admin_pwd=$(pushd "${CK8S_CONFIG_PATH}" > /dev/null && sops exec-file secrets.yaml 'yq r {} elasticsearch.adminPassword' && popd > /dev/null)

    # Get url to elasticsearch
    es_url="https://elastic.$(yq r ${CK8S_CONFIG_PATH}/sc-config.yaml global.opsDomain)"

    # Remove old legacy index templates
    curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/kubernetes"
    curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/other"
    curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/kubeaudit"

    # Update everything else
    ./bin/ck8s apply sc
    ```
