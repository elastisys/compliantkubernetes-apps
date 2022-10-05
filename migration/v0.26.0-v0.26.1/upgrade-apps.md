# Upgrade v0.26.0 to v0.26.1

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. *IMPORTANT* If you are using the any connector of type `google` and you haven't added a service account you'll need to change it to a type `oidc`

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

1. Upgrade applications:

    ```bash
    bin/ck8s apply sc
    ```
