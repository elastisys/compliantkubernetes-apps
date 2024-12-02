# Chart registry

As part of our effort to make our Helm charts available for public and internal consumption we have decided to publish some of them on Github Container Registry.

1. Go to https://github.com/orgs/elastisys/packages to see our available packages.

1. Pull and verify packages e.g:

    ```terminal
    cd helmfile.d/charts
    helm pull --verify oci://ghcr.io/elastisys/opensearch-configurer --version 0.1.0 --keyring public.gpg
    ```

1. Pull and install charts e.g:

    ```terminal
    helm install opensearch-configurer oci://ghcr.io/elastisys/opensearch-configurer --version 0.1.0 --namespace <NAMESPACE>
    ```
