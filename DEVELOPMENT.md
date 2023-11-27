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

> [!important]
> Namespaces are not yet managed by `helmfile` so you must first run `./bin/ck8s bootstrap sc|wc`.

Manage apps by using `helmfile` directly and with needs it will pull in all required releases:

```sh
# for service cluster
helmfile -e service_cluster <operation> --selector app=<application> --include-transitive-needs
# for workload cluster
helmfile -e workload_cluster <operation> --selector app=<application> --include-transitive-needs
```

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
