# Upgrade v0.17.x to v0.18.0

## Prerequisite
- ingress-nginx: in v0.17.0 hostNetwork was enabled by default even for LoadBalancer type service. During this upgrade we will disable hostNetwork for this service type, but we noticed that the upgrade will fail due to the PSP being deleted before the new pods get scheduled. We mitigate this by creating a temporary PSP, using it for the upgrade, apply the chart PSP and at the end delete the temporary PSP.
  > **_NOTE:_** This steps will apply only where LoadBalancer type service is available and `useHostPort: false` in the sc and wc configs

  Apply the temporary psp:
    ```bash
    bin/ck8s ops kubectl sc apply -f ./migration/v0.17.x-v0.18.x/psp_ingress_nginx_tmp.yaml

    bin/ck8s ops kubectl wc apply -f ./migration/v0.17.x-v0.18.x/psp_ingress_nginx_tmp.yaml
    ```
  Use the existing temporary psp in the helm chart:
    ```bash
    vim ./helmfile/values/ingress-nginx.yaml.gotmpl

    # under controller add:
    existingPsp: ingress-nginx-tmp
    ```

## Steps
1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Run migration script: `./migration/v0.17.x-v0.18.x/remove-velero-backupstoragelocation.sh`

    This script removes the unused `backupstoragelocation` "aws/gcs". It has been switched to "defualt"

1. Remove the `existingPsp: ingress-nginx-tmp` from the ingress-nginx.yaml.gotmpl and re-run the ingress-nginx chart:

   ```bash
   bin/ck8s ops helmfile sc -f helmfile -l app=ingress-nginx -i apply

   bin/ck8s ops helmfile wc -f helmfile -l app=ingress-nginx -i apply
   ```

1. Remove the temporary psp:

   ```bash
   bin/ck8s ops kubectl sc delete psp ingress-nginx-tmp

   bin/ck8s ops kubectl wc delete psp ingress-nginx-tmp
   ```
