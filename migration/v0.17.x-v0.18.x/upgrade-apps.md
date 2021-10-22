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

1. When upgrading the chart and setting `useHostPort: false` we noticed that the daemonset doesn't get the hostPort removed from the metrics and webhook ports.
   Run the following script to check and remove them manually on each cluster:

   ```bash
   bin/ck8s ops kubectl sc get ds -n ingress-nginx ingress-nginx-controller -o json  | jq -r '.spec.template.spec.containers[].ports[].hostPort | select( . != null )' > ports.txt
   while read i
   do
     echo "Removing the hostPort for: $i"
     INDEX=$(bin/ck8s ops kubectl sc get ds -n ingress-nginx ingress-nginx-controller -o json | jq --arg i $i '.spec.template.spec.containers[].ports | map(.hostPort == '$i') | index(true)')
     bin/ck8s ops kubectl sc patch ds -n ingress-nginx ingress-nginx-controller --type='json' -p="[{'op': 'remove', 'path': '/spec/template/spec/containers/0/ports/$INDEX/hostPort'}]"
   done < ports.txt
   ```

1. Remove the `existingPsp: ingress-nginx-tmp` from the ingress-nginx.yaml.gotmpl and re-run the ingress-nginx chart:

   ```bash
   vim ./helmfile/values/ingress-nginx.yaml.gotmpl

   # remove existingPsp: ingress-nginx-tmp
   ```

   ```bash
   bin/ck8s ops helmfile sc -f helmfile -l app=ingress-nginx -i sync

   bin/ck8s ops helmfile wc -f helmfile -l app=ingress-nginx -i sync
   ```

1. Remove the temporary psp:

   ```bash
   bin/ck8s ops kubectl sc delete psp ingress-nginx-tmp

   bin/ck8s ops kubectl wc delete psp ingress-nginx-tmp
   ```
