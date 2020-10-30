# Updating Opendistro for Elasticsearch

This document tells you what you have to do in order to update opendistro.

## Steps

- **OPTIONAL:** If you want to enable kibana sso
    - Update config with `ES_ENABLE_SSO=true` and `ES_CLIENT_SECRET=<something-of-your-choosing>`

    - Run helmfile to update the dex release

        ```bash
        ./bin/ck8s ops helmfile sc -e service_cluster -l app=dex -i apply
        ```

- Run helmfile to update the opendistro release

    ```bash
    ./bin/ck8s ops helmfile sc -e service_cluster -l app=opendistro -i apply
    ```

    This will trigger a restart of elasticsearch and kibana.
    Wait for everything to be back up and running.
    Curator may be crashing - this is fine for now.

- Update security config and roles mappings

    ```bash
    # Enter a master pod
    ./bin/ck8s ops kubectl sc -n elastic-system exec -it opendistro-es-master-0 -- bash

    # Make script executable
    chmod +x ./plugins/opendistro_security/tools/securityadmin.sh

    # Reload configuration
    ./plugins/opendistro_security/tools/securityadmin.sh \
        -cd plugins/opendistro_security/securityconfig/ \
        -icl -nhnv \
        -cacert config/admin-root-ca.pem \
        -cert config/admin-crt.pem \
        -key config/admin-key.pem
    ```

- Modify curator resource requests in `helmfile/values/opendistro-es.yaml.gotmpl`  to force a rerun of the configurer.
    Just set to whatever since we are just interested in making a change that will trigger an update of the helm release.

    ```bash
    ./bin/ck8s ops helmfile sc -e service_cluster -l app=opendistro -i apply
    ```

    With the update the configurer should run and reqreate the nessecary objects that were removed with the update of roles mappings in the previous step.

- Reset previous change in curator resources requests and run helmfile

    ```bash
    ./bin/ck8s ops helmfile sc -e service_cluster -l app=opendistro -i apply
    ```
