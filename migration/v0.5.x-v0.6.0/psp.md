# Enabling PSPs

These are steps required to update a cluster from v0.5.x to v0.6.0:

1. Remove `ENABLE_PSP` from `config.sh`.
2. Update ck8s-cluster to v0.6.0 to get PSPs for apps that does not bring their own.
3. Update ck8s-apps to v0.6.0 to get the PSPs that apps bring in their helm charts.
4. Edit the manifest for the static apiserver pods to enable the `PodSecurityPolicy` admission plugin.
   The manifest should be edited on all control plane nodes at `/etc/kubernetes/manifests/kube-apiserver.yaml`.
