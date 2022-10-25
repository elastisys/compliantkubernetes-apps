# Upgrade v0.26.x to v0.27.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. *When using Harbor on Swift:* Migrate Swift configuration.

    ```bash
    ./migration/v0.26.x-v0.27.x/migrate-swift.sh
    ```

1. *IMPORTANT* If you are using any Dex connector of type `google` and you haven't added a service account then you'll need to change it to a type `oidc`

    This can be done by adding the following line to the `config` part in the connector
    ```
    issuer: https://accounts.google.com
    ```

    The diff should look like this for `secrets.yaml`

    ```diff
    dex:
      connectors:
        - name: Example
          id: example
    -     type: google
    +     type: oidc
          config:
    +       issuer: https://accounts.google.com
            clientID: exampleid
            clientSecret: examplesecret
    ```

1. Upgrade the `workload-cluster-np` with the new changes, before applying the common-np chart:

    ```bash
    ./bin/ck8s ops helmfile wc -f helmfile -l app=workload-cluster-np -i apply
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Check resource requests and limits

    Several default resource requests and limits have changed. When upgrading these might need to be changed in your environment. Check for pods that have high memory usage (or even goes OOM) or have heavily throttled CPU.
