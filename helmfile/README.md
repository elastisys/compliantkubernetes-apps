# Helmfile

Project site: https://github.com/roboll/helmfile

* Helm 3 is used to deploy all charts so helm 3 needs to be installed

* We use multiple helm state files, located in `/helmfile` directory, containing the states for the helm releases for both the workload and service clusters.
`Environments` are used to differentiate between these two clusters.
**Note:** It should be investigated what the best practices are, like use sub-helmfiles etc.

* The values that the charts are using are found in the `values` directory.

## Getting started

1. Get `helmfile`.

    ``` bash
    wget https://github.com/roboll/helmfile/releases/download/v0.119.1/helmfile_linux_amd64 -O helmfile
    chmod +x helmfile
    ```

2. Get `helm-diff` plugin if not already installed.

    ``` bash
    helm plugin install https://github.com/databus23/helm-diff --version 3.1.1
    ```

## Environment variables

Environment variables are used to configure selected values in helm charts and need to be set in order to successfully install the respective helm chart.
They are imported using `{{ requiredEnv VARIABLE_NAME }}` command.

**Note:** They are required for the direct use of `helmfile` command. All might not be required to run the deploy scripts!

If any of the required environment variable is not set, `helmfile` will throw an error and the release will not be installed.

## Helmfile environments

There is one environment for each cluster type: `service_cluster` and `workload_cluster`.
Environments are specififed by using the flag `-e <environment_name>`.

## Usage

* to install in the service cluster (`sc`) all releases specified in a helm state file `helmfile/helmfile.yaml`

    ``` bash
    ./bin/ck8s ops helmfile sc -f helmfile/helmfile.yaml apply
    ```

* to install in the service cluster (`sc`) all releases specified in all helm state files located in the `helmfile` directory

    ``` bash
    ./bin/ck8s ops helmfile sc -f helmfile apply
    ```

* labels can be used to install only a specific release, e.g. `app=cert-manager`

    ``` bash
    ./bin/ck8s ops helmfile sc -f helmfile -l app=cert-manager apply
    ```

* or to remove a specific release

    ``` bash
    ./bin/ck8s ops helmfile sc -f helmfile -l app=cert-manager destroy
    ```

* to use a specific environment (`service_cluster` in `sc` or `workload_cluster` in `wc`)

    ``` bash
    ./bin/ck8s ops helmfile sc -f helmfile -e service_cluster apply
    ./bin/ck8s ops helmfile wc -f helmfile -e workload_cluster apply
    ```

* to check status of releases in the respective cluster (`sc` or `wc`)

    ``` bash
    ./bin/ck8s ops helmfile sc status
    ./bin/ck8s ops helmfile wc status
    ```
