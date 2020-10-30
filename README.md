# Elastisys Compliant Kubernetes Apps

## Build status

![ck8s-cluster](https://github.com/elastisys/ck8s-pipelines/workflows/ck8s-cluster/badge.svg)

compliantkubernetes-apps: TODO

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
A service-cluster (sc) or workload-cluster (wc) can be created seperately but all of the applications will not work correctly unless both are running.

All config files will be located under `CK8S_CONFIG_PATH`.
There will be three config files: `wc-config.yaml`, `sc-config.yaml` and `secrets.yaml`.
See [Quickstart](#Quickstart) for instructions on how to initialize the repo

### Cloud providers

Currently we support four cloud providers: Exoscale, Safespring, Citycloud and AWS.
This is controlled by the value `global.cloudProvider` in the config files.

## Setup

The apps are installed using a combination of helm charts and manifests with the help of helmfile and some bash scripts.

### Requirements

* A running cluster based on [ck8s-cluster](https://github.com/elastisys/ck8s-cluster)
* [kubectl](https://github.com/kubernetes/kubernetes/releases) (tested with 1.15.2)
* [helm](https://github.com/helm/helm/releases) (tested with 3.3.4)
* [helmfile](https://github.com/roboll/helmfile) (tested with v0.129.3)
* [helm-diff](https://github.com/databus23/helm-diff) (tested with 3.1.1)
* [helm-secrets](https://github.com/futuresimple/helm-secrets) (tested with 2.0.2)
* [jq](https://github.com/stedolan/jq) (tested with jq-1.6)
* [sops](https://github.com/mozilla/sops) (tested with 3.6.1)
* [s3cmd](https://s3tools.org/s3cmd) available directly in ubuntus repositories (tested with 2.0.1)
* [yq](https://github.com/mikefarah/yq) (tested with 3.3.2)

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
Assuming you already have everything needed to install the apps, this is what you need to do.

1. Decide on a name for this environment, the cloud provider to use and set them as environment variables:

   ```bash
   export CK8S_ENVIRONMENT_NAME=my-ck8s-cluster
   export CK8S_CLOUD_PROVIDER=[exoscale|safespring|citycloud|aws]
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

7. Check the [onboarding document](docs/onboarding.md) for any extra steps necessary.

### Accessing the clusters

The [`bin/ck8s`](bin/ck8s) script provides an entrypoint to the clusters.
It should be used instead of using for example `kubectl`or `helmfile` directly.
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
  ./bin/ck8s ops helmfile sc -l app=<release> diff
  ```

#### Autocompletion for ck8s in bash

Add this to `~/.bashrc`:

```bash
CK8S_APPS_PATH= # fill this in
source <($CK8S_APPS_PATH/bin/ck8s completion bash)
```

### User access

After the cluster setup has completed RBAC resources, namespaces and a kubeconfig file (`${CK8S_CONFIG_PATH}/user/kubeconfig.yaml`) will have been created for the user.
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

The user kubeconfig will be configured to use the first namespace by default.

For more details and a list of available services see [docs/user-access.md](docs/user-access.md).

### Operator access

See [docs/operator-access.md](docs/operator-access.md).

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

### OpenID Connect with kubectl

For using OpenID Connect with kubectl, see [kubelogin/README.md](kubelogin/README.md).

### OpenID Connect with Harbor

When using Harbor as a reqistry and authenticating with OIDC docker need to be logged in to that user.
For more information how to use it see [Using OIDC from the Docker or Helm CLI](https://github.com/goharbor/harbor/blob/master/docs/1.10/administration/configure-authentication/oidc-auth.md#using-oidc-from-the-docker-or-helm-cli)
