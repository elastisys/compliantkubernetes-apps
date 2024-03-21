# Development

## Requirements

* See [README.md](./README.md).

## Local clusters

When working on compliantkubernetes-apps it is possible to work with local clusters running on [kind](https://kind.sigs.k8s.io/).

This requires that `kind` is installed and that either `podman` or `docker` is available and setup to work with `kind`.

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

> [!note]
> In its current state the local cluster is created to be either SC or WC, and currently the scripts does not support setting up both a SC and WC.
> To setup two independent clusters the following must be changed manually:
> 1. the kind-config/local-cluster-profile must not bind the ingress controller to the same address, and
> 1. the node-local-dns config must be updated to point towards the correct clusters.

```sh
# with CK8S_CONFIG_PATH and CK8S_PGP_FP set
./scripts/local-cluster.sh config <name> <apps-flavor> <domain>
./scripts/local-cluster.sh create <name> <kind-config|local-cluster-profile> # use list profiles to see built-in configs
```

This will configure apps with `ck8sCloudProvider: none` and `ck8sFlavor: <apps-flavor>` and set some default values to run on local clusters.
By default it will use `calico` for networking, `local-path-provisioner` for block storage, and `minio` for object storage.

The configuration contains some `set-me`'s that must be configured manually.

### Deploy

> [!important]
> Setting up ingresses properly requires some additional steps documented later in this section.

Manage apps by using `helmfile` directly and with needs it will pull in all required releases:

```sh
# for service cluster
helmfile -e service_cluster <operation> --selector app=<application> --include-transitive-needs
# for workload cluster
helmfile -e workload_cluster <operation> --selector app=<application> --include-transitive-needs
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
> So one have to be explicit about which features to install.

Use `helmfile -e <service|workload>_cluster list` to list all releases and to view their labels.
By default all releases have `name=<release-name>` and `chart=<chart-name>` as predefined labels.

Enabling ingress and resolve requires a special setup for `ingress-nginx` and `node-local-dns` respectively.
Both will by default be port-mapped on the local address `127.0.64.43` and once both are running you need to change your computer's network settings to use this address as the DNS resolver, then you can access service endpoints using the configured domain.

Both are already pre-configured by `scripts/local-cluster.sh` and can be deployed by using:

```sh
helmfile -e <service|workload>_cluster -lapp=ingress-nginx -lapp=node-local-dns apply --include-transitive-needs
```

> [!important]
> To use `podman` with their `aardvark` DNS resolver you must edit the CoreDNS ConfigMap to prefer UDP:
> ```diff
> $ kubectl --namespace edit configmap coredns
>
>   forward . ./etc/resolv.conf {
>     max_concurrent 1000
> +   prefer_udp
>   }
>
> $ kubectl --namespace rollout restart deployment coredns
> ```

> [!important]
> To use certificates from Let's Encrypt you must enable [DNS-01 challenges in `cert-manager`](https://cert-manager.io/docs/configuration/acme/dns01/).
> Remember to add the correct network policies.
> For Amazon route53 the ip range is: `205.251.192.0/18`

Support matrix:

App            | SC | WC | Notes
-------------- | -- | -- | -----
calico         | 🟨️ | 🟨️ | Requires Cluster API settings to work.
cert-manager   | 🟩️ | 🟩️ |
dex            | 🟩️ | ⬜️ | Does not pull in cert-manager or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns`
falco          | 🟥️ | 🟥️ | Installs but cannot start due to lack of permissions inside Kind.
fluentd        | 🟩️ | 🟨️ | Installs but cannot start without creating initial resources on WC.
gatekeeper     | 🟩️ | 🟩️ |
grafana        | 🟩️ | ⬜️ | Does not pull in cert-manager, dex, ingress-nginx, monitors, rules, or thanos. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns -lapp=prometheus`
harbor         | 🟩️ | ⬜️ | Does not pull in dex or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=harbor -lapp=ingress-nginx -lapp=node-local-dns`
hnc            | ⬜️ | 🟩️ |
ingress-nginx  | 🟩️ | 🟩️ |
kured          | 🟩️ | 🟩️ |
node-local-dns | 🟩️ | 🟩️ |
opensearch     | 🟩️ | ⬜️ | Does not pull ingress-nginx. Prod flavour is heavy on resources. For full functionality use: <br/> `-lapp=cert-manager -lapp=dex -lapp=ingress-nginx -lapp=node-local-dns -lapp=opensearch`
prometheus     | 🟩️ | 🟩️ |
thanos         | 🟩️ | ⬜️ | Does not pull cert-manager, or ingress-nginx. For full functionality use: <br/> `-lapp=cert-manager -lapp=ingress-nginx-lapp=node-local-dns -lapp=opensearch -lapp=thanos`
trivy-operator | 🟩️ | 🟩️ |
velero         | 🟩️ | 🟩️ |

Key: 🟩️ Runs without issues, 🟨️ Runs with some issues, 🟥️ Does not run, ⬜️ Does not install by design.

### Teardown

```sh
# for service cluster
helmfile -e service_cluster destroy
# for workload cluster
helmfile -e workload_cluster destroy
# might need two tries if the first fails due to webhooks

kubectl delete pvc --all

./scripts/local-cluster.sh delete <name>
```

## Code styling guidelines

### Bash

* See [Googles style guide](https://google.github.io/styleguide/shellguide.html).

### Markdown

* Use Github flavored markdown.
* One sentence per line - do not line break long sentences.

### TODO

* Naming conventions?
* Line length limit (except for markdown)?

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

* `timonwong.shellcheck`
* `davidanson.vscode-markdownlint`
* `redhat.vscode-yaml`
* `editorconfig.editorconfig`
* `signageos.vscode-sops`

#### Other editors

Please add plugins that makes life easier :)
