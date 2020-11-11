The `prometheus-operator` chart has been replaced with `kube-prometheus-stack`. When upgrading, you must remove your deployed `prometheus-operator` resources before applying the new chart.

```
# Workload cluster

# Delete old release and related resources
./bin/ck8s ops helm wc uninstall prometheus-operator -n monitoring
./bin/ck8s ops kubectl wc delete service/prometheus-operator-kubelet -n kube-system
./bin/ck8s ops kubectl wc delete pvc/prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0 -n monitoring

# Bootstrap new CRDs
./bin/ck8s bootstrap wc

#
# Update falco.alerts.hostPort to "http://kube-prometheus-stack-alertmanager.monitoring:9093" in ${CK8S_CONFIG_PATH}/wc-config.yaml
#

# Install new release
./bin/ck8s ops helmfile wc -l app=kube-prometheus-stack -i apply



# Service cluster

# Delete old release and related resources
./bin/ck8s ops helm sc uninstall prometheus-operator -n monitoring
./bin/ck8s ops kubectl sc delete service/prometheus-operator-kubelet -n kube-system
./bin/ck8s ops kubectl sc delete pvc/prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0 -n monitoring

# Bootstrap new CRDs
./bin/ck8s bootstrap sc

# Install new release
./bin/ck8s ops helmfile sc -l app=kube-prometheus-stack -i apply
```
