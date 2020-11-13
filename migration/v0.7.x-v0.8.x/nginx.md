# Upgrade to new ingress nginx release

Due to our current nginx ingress setup we can only have one deployment running at a time which means that this upgrade will introduce some downtime.
The following snippet shows the commands nessecary to remove the old `nginx-ingress` release and namespace, and how to install the new `ingress-nginx` namespace and release.

```
# Workload cluster

# Delete old release and namespace
./bin/ck8s ops helm wc -n nginx-ingress uninstall nginx-ingress && ./bin/ck8s ops kubectl wc delete namespace nginx-ingress

# Bootstrap new namespace
./bin/ck8s bootstrap wc

#
# Update your 'nginxIngress' configuration to 'ingressNginx' in ${CK8S_CONFIG_PATH}/wc-config.yaml
#

# Install new release
./bin/ck8s ops helmfile wc -l app=ingress-nginx -i apply


# Service cluster

# Delete old release and namespace
./bin/ck8s ops helm sc -n nginx-ingress uninstall nginx-ingress && ./bin/ck8s ops kubectl sc delete namespace nginx-ingress

# Bootstrap new namespace
./bin/ck8s bootstrap sc

#
# Update your 'nginxIngress' configuration to 'ingressNginx' in ${CK8S_CONFIG_PATH}/sc-config.yaml
#

# Install new release
./bin/ck8s ops helmfile sc -l app=ingress-nginx -i apply
```
