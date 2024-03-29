# Upgrade v0.11.x to v0.12.0

1. Checkout the new release: `git checkout v0.12.0`

1. Run init to get new defaults: `./bin/ck8s init`

1. Delete `issuers.letsencrypt.namespaces` and `objectStorage.s3.regionAddress` from both `sc-config.yaml` and `wc-config.yaml`.

1. Set `issuers.letsencrypt.enabled` to `false` in `wc-config.yml` and remove `issuers.letsencrypt.prod` and `issuers.letsencrypt.staging`, unless you want to use the ClusterIssuer in WC.

1. If you want to keep PVCs for prometheus (not recommended) edit:

    * `sc-config.yaml`
      * set `prometheus.storage.enabled`: `true`
      * set `prometheus.wcReader.storage.enabled`: `true`
    * `wc-config.yaml`
      * set `prometheus.storage.enabled`: `true`

1. If you had disabled OPA/gatekeeper because it could not be run on kubernetes v1.19+, then you can now enable it again in your config.
  Otherwise, if you have enabled OPA/gatekeeper, then delete the old gatekeeper chart (note this will temporarily disable any gatekeeper policy and create a possible security issue):

    ```bash
    ./bin/ck8s ops helmfile wc -l app=gatekeeper-operator destroy
    ```

1. Upgrade applications. Note that our config validation now also warns if you have left any config value equal to "set-me", so you might see more warnings than before.

    ```bash
    ./bin/ck8s apply {sc|wc}
    ```

1. If PVCs for prometheus are not enabled, then delete the PVCs that are now obsolete.

    ```ShellSession
    bin/ck8s ops kubectl sc delete pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
    bin/ck8s ops kubectl sc delete pvc -n monitoring prometheus-wc-reader-prometheus-instance-db-prometheus-wc-reader-prometheus-instance-0

    bin/ck8s ops kubectl wc delete pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
    ```
