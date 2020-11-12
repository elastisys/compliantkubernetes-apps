# Elastisys Compliant Kubernetes Apps

## Build status

![compliantkubernetes-apps](https://github.com/elastisys/ck8s-pipelines/workflows/ck8s-apps/badge.svg)

## Overview

This repository is part of the [Compliant Kubernetes][compliantkubernetes] (compliantkubernetes) platform.
The platform consists of the following repositories:

* [ck8s-cluster][ck8s-cluster] - Code for managing Kubernetes clusters and the infrastructure around them.
* [compliantkubernetes-apps][compliantkubernetes-apps] - Code, configuration and tools for running various services and applications on top of service and workload ck8s-cluster.
* [ck8s-base-vm][ck8s-base-vm] - A virtual machine template with relevant Kubernetes packages pre-installed.

The Elastisys Compliant Kubernetes (compliantkubernetes) platform runs two Kubernetes clusters.
One called "service" and one called "workload".

The _service cluster_ provides observability, log aggregation, private container registry with vulnerability scanning and authentication using the following services:

* Prometheus and Grafana
* Elasticsearch and Kibana
* Harbor
* Dex

The _workload cluster_ manages the user applications as well as providing intrusion detection, security policies, log forwarding and monitoring using the following services:

* Falco
* Open Policy Agent
* Fluentd
* Prometheus

[compliantkubernetes]: https://compliantkubernetes.com/
[ck8s-cluster]: https://github.com/elastisys/ck8s-cluster
[compliantkubernetes-apps]: https://github.com/elastisys/compliantkubernetes-apps
[ck8s-base-vm]: https://github.com/elastisys/ck8s-base-vm

This repository installs all the applications of ck8s on top of already created clusters.
To setup the clusters see [ck8s-cluster](https://github.com/elastisys/ck8s-cluster).
A service-cluster (sc) or workload-cluster (wc) can be created separately but all of the applications will not work correctly unless both are running.

All config files will be located under `CK8S_CONFIG_PATH`.
There will be three config files: `wc-config.yaml`, `sc-config.yaml` and `secrets.yaml`.
See [Quickstart](#Quickstart) for instructions on how to initialize the repo

### Cloud providers

Currently we support four cloud providers: Exoscale, Safespring, Citycloud and AWS (beta).
This is controlled by the value `global.cloudProvider` in the config files.

## Setup

The apps are installed using a combination of helm charts and manifests with the help of helmfile and some bash scripts.

### Requirements

* A running cluster based on [ck8s-cluster](https://github.com/elastisys/ck8s-cluster)
* [kubectl](https://github.com/kubernetes/kubernetes/releases) (tested with 1.15.2)
* [helm](https://github.com/helm/helm/releases) (tested with 3.4.1)
* [helmfile](https://github.com/roboll/helmfile) (tested with v0.129.3)
* [helm-diff](https://github.com/databus23/helm-diff) (tested with 3.1.1)
* [helm-secrets](https://github.com/futuresimple/helm-secrets) (tested with 2.0.2)
* [jq](https://github.com/stedolan/jq) (tested with jq-1.6)
* [sops](https://github.com/mozilla/sops) (tested with 3.6.1)
* [s3cmd](https://s3tools.org/s3cmd) available directly in ubuntus repositories (tested with 2.0.1)
* [yq](https://github.com/mikefarah/yq) (tested with 3.4.1)

Installs requirements using the ansible playbook get-requirements.yaml

```bash
ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --connection local --inventory 127.0.0.1, get-requirements.yaml
```

Note that you will need a service and workload ck8s-cluster.

#### Developer requirements and guidelines

See [DEVELOPMENT.md](DEVELOPMENT.md).

### PGP

Configuration secrets in ck8s are encrypted using [SOPS](https://github.com/mozilla/sops).
We currently only support using PGP when encrypting secrets.
Because of this, before you can start using ck8s, you need to generate your own PGP key:

```bash
gpg --full-generate-key
```

Note that it's generally preferable that you generate and store your primary key and revocation certificate offline.
That way you can make sure you're able to revoke keys in the case of them getting lost, or worse yet, accessed by someone that's not you.

Instead create subkeys for specific devices such as your laptop that you use for encryption and/or signing.

If this is all new to you, here's a [link](https://riseup.net/en/security/message-security/openpgp/best-practices) worth reading!

## Usage

### Quickstart

**You probably want to check the [ck8s-cluster][ck8s-cluster] repository first, since compliantkubernetes-apps depends on having two clusters already set up.**
In addition to this, you will need to set up the following DNS entries (replace `example.com` with your domain).
- Point these domains to the workload cluster ingress controller:
  - `*.example.com`
  - `prometheus.ops.example.com`
- Point these domains to the service cluster ingress controller:
  - `*.ops.example.com`
  - `grafana.example.com`
  - `harbor.example.com`
  - `kibana.example.com`
  - `dex.example.com`
  - `notary.harbor.example.com`

Assuming you already have everything needed to install the apps, this is what you need to do.

1. Decide on a name for this environment, the cloud provider to use as well as the flavor and set them as environment variables:

   ```bash
   export CK8S_ENVIRONMENT_NAME=my-ck8s-cluster
   export CK8S_CLOUD_PROVIDER=[exoscale|safespring|citycloud|aws]
   export CK8S_FLAVOR=[dev|prod] # defaults to dev
   ```

2. Then set the path to where the ck8s configuration should be stored and the PGP fingerprint of the key(s) to use for encryption:

   ```bash
   export CK8S_CONFIG_PATH=${HOME}/.ck8s/my-ck8s-cluster
   export CK8S_PGP_FP=<PGP-fingerprint1,PGP-fingerprint2,...>
   ```

3. Initialize your environment and configuration:
   Note that this will *not* overwrite existing values, but it will append to existing files.
   See the [ck8s][ck8s] repository if you are uncertain about in what order you should do things.

   ```bash
   ./bin/ck8s init
   ```

4. Edit the configuration files that have been initialized in the configuration path.

5. OBS! for this step each cluster need to be up and running already.
   Deploy the apps:

   ```bash
   ./bin/ck8s apply sc
   ./bin/ck8s apply wc
   ```

6. Test that the cluster is running correctly with:

   ```bash
   ./bin/ck8s test sc
   ./bin/ck8s test wc
   ```

7. You should now have a fully working environment.
   Check the next section for some additional steps to finalize it and set up user access.

### On-boarding and final touches

If you followed the steps in the quickstart above, you should now have deployed the applications and have a fully functioning environment.
However, there are a few steps remaining to make all applications ready for the user.

#### User access

After the cluster setup has completed RBAC resources and namespaces will have been created for the user.
You can configure what namespaces should be created and which users that should get access using the following configuration options:

```yaml
user:
  namespaces:
    - demo1
    - demo2
  adminUsers:
    - admin1@example.com
    - admin2@example.com"
```

A **kubeconfig file for the user** (`${CK8S_CONFIG_PATH}/user/kubeconfig.yaml`) can be created by running the script `bin/user-kubeconfig.bash`.
The user kubeconfig will be configured to use the first namespace by default.

**Kibana** access for the user can be provided either by setting up OIDC or using the internal user database in Elasticsearch:
- OIDC:
  - Set `elasticsearch.sso.enabled=true` in `sc-config.yaml`.
  - Configure extra role mappings under `elasticsearch.extraRoleMappings` to give the users the necessary roles.
    ```yaml
    extraRoleMappings:
      - mapping_name: kibana_user
        definition:
          users:
            - "configurer"
            - "User Name"
      - mapping_name: kubernetes_log_reader
        definition:
          users:
            - "User Name"
    ```
- Internal user database:
  - Log in to Kibana using the admin account.
  - Create an account for the user.
  - Give the `kibana_user` and `kubernetes_log_reader` roles to the user.

Users will be able to log in to **Grafana** using dex, but they will have read only access by default.
To give them more privileges, you need to first ask them to log in (so that they show up in the users list) and then change their roles.

**Harbor** works in a multi-tenant way so that each logged in user will be able to create their own projects and manage them as admins (including adding more users as members).
However, users will not be able to see each others (private) projects (unless explicitly invited) and won't have global admin access in Harbor.
This also naturally means that container images uploaded to these private registries cannot automatically be pulled in to the Kubernetes cluster.
The user will first need to add pull secrets that gives some ServiceAccount access to them before they can be used.

For more details and a list of available services see the [user guide](https://compliantkubernetes.io/user-guide/).

### Management of the clusters

The [`bin/ck8s`](bin/ck8s) script provides an entrypoint to the clusters.
It should be used instead of using for example `kubectl`or `helmfile` directly as an operator.
To use the script, set the `CK8S_CONFIG_PATH` to the environment you want to access:

```bash
export CK8S_CONFIG_PATH=${HOME}/.ck8s/my-ck8s-cluster
```

Run the script to see what options are available.

#### Examples

* Bootstrap and deploy apps to the workload cluster:

  ```bash
  ./bin/ck8s apply wc
  ```

* Run tests on the service cluster:

  ```bash
  ./bin/ck8s test sc
  ```

* Port-forward to a Service in the workload cluster:

  ```bash
  ./bin/ck8s ops kubectl wc port-forward svc/<service> --namespace <namespace> <port>
  ```

* Run `helmfile diff` on a helm release:

  ```bash
  ./bin/ck8s ops helmfile sc -l <label=selector> diff
  ```

#### Autocompletion for ck8s in bash

Add this to `~/.bashrc`:

```bash
CK8S_APPS_PATH= # fill this in
source <($CK8S_APPS_PATH/bin/ck8s completion bash)
```

### Operator manual

See <https://compliantkubernetes.io/operator-manual/>.

### Setting up Google as identity provider for dex

1. Go to the [Google console](https://console.cloud.google.com/) and create a project.

2. Go to the [Oauth consent screen](https://console.cloud.google.com/apis/credentials/consent) and name the application with the same name as the project of your google cloud project add the top level domain e.g. `elastisys.se` to Authorized domains.

3. Go to [Credentials](https://console.cloud.google.com/apis/credentials) and press `Create credentials` and select `OAuth client ID`.
   Select `web application` and give it a name and add the URL to dex in the `Authorized Javascript origins` field, e.g. `dex.demo.elastisys.se`.
   Add `<dex url>/callback` to Authorized redirect URIs field, e.g. `dex.demo.elastisys.se/callback`.

4. Configure the following options in `CK8S_CONFIG_PATH/secrets.yaml`

   ```yaml
     dex:
       googleClientID:
       googleClientSecret:
   ```

## Known issues

- Elasticsearch SSO is currently hard coded to use the users real name as identifier, as opposed to a username or email address.
  This will be addressed in the future.
- Users must explicitly be given privileges in Grafana, Elasticsearch and Kubernetes instead of automatically getting assigned roles based on group membership when logging in using OIDC.
- The OPA policies are not enforced by default.
  Unfortunately the policies breaks cert-manager so they have been set to "dry-run" by default.

For more, please the the public GitHub issues: <https://github.com/elastisys/compliantkubernetes-apps/issues>.
