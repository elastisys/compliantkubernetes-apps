# Development

## Requirements

- See [README.md](./README.md).

## Local clusters

When working on compliantkubernetes-apps it is possible to work with local clusters running on [kind](https://kind.sigs.k8s.io/).

This requires that `kind` is installed and that either `podman` or `docker` is available and setup to work with `kind`.

### Terminology

- `apps-flavor` - one of `prod`, `dev` or `air-gapped` is a global switch for configuring the clusters and deployed applications in different ways. The recommended value when working with local clusters is `dev`.
- `local-cluster-profile` - a reference to a preconfigured `Cluster` config passed to `kind` when creating or updating local clusters. We use profiles to differentiate between single-/multi-node clusters and/or to enable special features such as container image caching. Use `./bin/local-clusters.sh list profiles` to see a list of built-in profiles.
- `domain` - a local domain name. This can be arbitrary, but using a real domain (or subdomain) for which we have authority allows for setting up DNS based challenges for certificates issued by `cert-manager`.

### Setup

> [!warning]
> Ensure your `KUBECONFIG` variable is not pointing to a config that you don't want to get edited by `kind`.

> [!important]
> Ensure your `inotify` limits are high enough else [pods might fail with the "too many open files" or similar](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)
>
> ```sh
> sysctl fs.inotify.max_user_instances # at least 1024 recommended
> sysctl fs.inotify.max_user_watches   # at least 102400 recommended
> ```

> [!important]
> With rootless `podman` or `docker` ensure your unprivileged port limit starts at `53`.
>
> ```sh
> sysctl net.ipv4.ip_unprivileged_port_start # expected at 53
> ```

> [!tip]
> Since local clusters are effectively ephemeral they can pull a lot of images and `kind` has no built-in system to manage images.
> So, for the local clusters script there are commands to create and delete local pull through registry caches for a few upstream registries.
> The command to do so is `./scripts/local-cluster.sh cache <create|delete>`, then one can make use of the local cluster profiles `<single|multi>-node-cache` that are prepared to use it by default.

As a first step, configure the clusters:

```sh
# with CK8S_CONFIG_PATH and CK8S_PGP_FP set
./scripts/local-cluster.sh config <name> <apps-flavor> <domain>
```

Apps will be configured with `ck8sCloudProvider: none` and `ck8sFlavor: <apps-flavor>` and set some default values to run on local clusters.
By default, local clusters will use `calico` for networking, `local-path-provisioner` for block storage, and `minio` for object storage.

The local listen address will be set to `127.0.64.43` for the SC worker node, and `127.0.64.143` for the WC worker node.

We'll also be passing the `--skip-minio` options for the WC, to deploy object storage only to the SC cluster.

```sh
./scripts/local-cluster.sh create <name>-sc <kind-config-file|local-cluster-profile>
./scripts/local-cluster.sh create <name>-wc <kind-config-file|local-cluster-profile> --skip-minio
```

> [!important]
> To support the integrated SC <--> WC scenario we require that the cluster names be suffixed with either `-sc` or `-wc`

#### In-cluster DNS setup

Making the clusters "aware" of each other will require custom DNS configuration snippets to both the SC and WC that ensure:

- From within the WC:
    - resolve`(dex|grafana|harbor|opensearch|ops).<domain>` queries to an SC worker node IP.
    - resolve all other `.<domain>` queries to the service IP of `ingress-nginx` in the WC.
- From within the SC:
    - resolve `(dex|grafana|harbor|opensearch|ops).<domain>` queries to the service IP of the `ingress-nginx` in the SC.
    - resolve all other `.<domain>` queries to a WC worker node IP.

> [!note]
> Even though the subdomains used for the various applications residing in the SC cluster _are_ configurable,
> the above setup is designed to work with the default values and does not support custom values at the moment.

Since these snippets depend on the IP addresses of running containers, they must be setup _after_ the initial `create` commands.

The following command will configure node-local DNS and (re)deploy the `node-local-dns` stack:

```sh
./scripts/local-cluster-sh setup node-local-dns
```

#### Self-signed certificate setup

If you cannot configure cert-manager to use DNS-01 challenges for various reasons (e.g. you picked an arbitrary `<domain>` which you don't have authority over), you have the option of using self-signed certificates.

Add the following block to `$CK8S_CONFIG_PATH/common-config.yaml` (you might need to merge the keys in `global` map manually):

```yaml
global:
  issuer: selfsigned
  verifyTls: false
issuers:
    letsencrypt:
      enabled: false
    extraIssuers:
    - apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: selfsigned
      spec:
        selfSigned: {}
```

### Deploy

> [!important]
> Setting up ingresses properly requires some additional steps documented later in this section.

> [!warning]
> If you are using Docker and deploying the `allow-coredns` network policy in the `networkpolicy/common` chart DNS resolution will stop working.
> This seems to be because Kind uses a user-defined Docker network which in turn uses an embedded DNS server that isn't actually listening on port 53.
> To solve this remove the port 53 restriction from the `allow-coredns` egress network policy and things should start working again.

Manage apps by using `helmfile` directly and with needs it will pull in all required releases:

```sh
# for service cluster
./bin/ck8s ops helmfile sc -lapp=<application> -lapp=<application_dependency> <operation> --include-transitive-needs
# for workload cluster
./bin/ck8s ops helmfile wc -lapp=<application> -lapp=<application_dependency> <operation> --include-transitive-needs
```

> [!note]
> As written in [the `helmfile` README](helmfile.d/README.md): "All needs are written according to what is needed to get applications **running** not to get applications _usable_ ...", this means that with `--include-transitive-needs` the dependencies that are pulled in are not complete themselves.
>
> Example with Grafana:
> When `app=grafana` is installed we also get prometheus through needs, but we do not get other monitoring ServiceMonitors or PrometheusRules, as they are separate releases within `app=prometheus`.
>
> Example with OpenSearch:
> When `app=opensearch` is installed we also get cert-manager through needs, but we do not get ClusterIssuers or Issuers, as they are separate releases within `app=cert-manager`.
>
> So one has to be explicit about which features to install.

Use `helmfile -e <service|workload>_cluster list` to list all releases and to view their labels.
By default, all releases have `name=<release-name>` and `chart=<chart-name>` as predefined labels.

Enabling ingress and resolve requires a special setup.
The ingress will by default be port-mapped on the local address `127.0.64.43`.

The `local-clusters.sh` script provides commands to create and delete a local DNS server to resolve local domain queries. By default, the local resolve CoreDNS configuration will resolve the `dex`, `grafana`, `harbor`, `opensearch` and `ops` subdomains to the SC listen address of `127.0.64.43`, while all other subdomains of `<domain>` will resolve to the WC listen address of `127.0.64.143`.

To create the resolver, run `./scripts/local-cluster.sh resolve <create|delete> <domain>`, matching the base domain of the cluster.
Note that this will make a temporary override of your current DNS server, and you may need to rerun it if you network settings are reset.

> [!note]
> To use `podman` with their `aardvark` DNS resolver the CoreDNS ConfigMap must be patched to prefer UDP, this is done automatically, but should DNS resolution fail you may need to check its config.

> [!important]
> To use certificates from Let's Encrypt you must enable [DNS-01 challenges in `cert-manager`](https://cert-manager.io/docs/configuration/acme/dns01/).
> Remember to add the correct network policies, for Amazon Route 53 the IP range is: `205.251.192.0/18`.

Support matrix:

| App            | SC | WC | Notes |
| -------------- | -- | -- | ----- |
| calico         | 🟨️ | 🟨️ | Requires Cluster API settings to work. |
| cert-manager   | 🟩️ | 🟩️ | |
| dex            | 🟩️ | ⬜️ | Does not pull in cert-manager or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns` |
| external-dns   | 🟩️ | 🟩️ | |
| falco          | 🟥️ | 🟥️ | Installs but cannot start due to lack of permissions inside Kind. |
| fluentd        | 🟩️ | 🟩️ | |
| gatekeeper     | 🟩️ | 🟩️ | |
| grafana        | 🟩️ | ⬜️ | Does not pull in cert-manager, dex, ingress-nginx, monitors, rules, or thanos. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns -lapp=prometheus` |
| harbor         | 🟩️ | ⬜️ | Does not pull in dex or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=harbor -lapp=ingress-nginx -lapp=node-local-dns` |
| hnc            | ⬜️ | 🟩️ | |
| ingress-nginx  | 🟩️ | 🟩️ | |
| kured          | 🟩️ | 🟩️ | |
| node-local-dns | 🟩️ | 🟩️ | |
| opensearch     | 🟩️ | ⬜️ | Does not pull ingress-nginx. Prod flavour is heavy on resources. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns -lapp=opensearch` |
| prometheus     | 🟩️ | 🟩️ | |
| thanos         | 🟩️ | ⬜️ | Does not pull cert-manager, or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=ingress-nginx -lapp=node-local-dns -lapp=opensearch -lapp=thanos` |
| trivy-operator | 🟩️ | 🟩️ | |
| velero         | 🟩️ | 🟩️ | |

Key: 🟩️ Runs without issues, 🟨️ Runs with some issues, 🟥️ Does not run, ⬜️ Does not install by design.

### Teardown

```sh
# for service cluster
helmfile -e service_cluster destroy
# for workload cluster
helmfile -e workload_cluster destroy
# might need two tries if the first fails due to webhooks

helmfile -e local_cluster destroy

kubectl delete pvc --all -A

./scripts/local-cluster.sh delete <name>
```

## Code styling guidelines

### Bash

- See [Googles style guide](https://google.github.io/styleguide/shellguide.html).

### Markdown

- Use Github flavored markdown.
- One sentence per line - do not line break long sentences.

### TODO

- Naming conventions?
- Line length limit (except for markdown)?

## Tooling

Tools for making development easier for everyone!

### Set up git pre-commit hooks

Install pre-commit using pip:

```bash
# From the project root
sudo apt install python3-pip git rbenv
wget -qO- https://github.com/koalaman/shellcheck/releases/download/v0.7.1/shellcheck-v0.7.1.linux.x86_64.tar.xz | sudo tar -J -xf - --strip-components=1 -C /usr/local/bin/ --no-anchored shellcheck
pip3 install pre-commit
pre-commit install
```

**Note**: `pre-commit` is usually installed at `$HOME/.local/bin`.
Make sure it is on your `PATH`.

Some tests will now be performed on the staged files each commit.

To uninstall the pre-commit checks, remove the file at `.git/hooks/pre-commit`.

### Setting up editorconfig

To use common editor settings in this repository, please install and enable the [Editorconfig](https://editorconfig.org/) plugin in your editor, if available.
The plugin will set up project-specific editor configuration based on the values in the [`.editorconfig`](./.editorconfig) file.

### Editor plugins

#### VS Code

Some recommended plugins:

- `timonwong.shellcheck`
- `davidanson.vscode-markdownlint`
- `redhat.vscode-yaml`
- `editorconfig.editorconfig`
- `signageos.vscode-sops`

#### Other editors

Please add plugins that makes life easier :)
