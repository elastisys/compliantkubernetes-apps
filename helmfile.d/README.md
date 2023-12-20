# Helmfile

Compliant Kubernetes Apps is driven by [`helmfile`](https://github.com/helmfile/helmfile).

The structure is as follows:

- `bases/` - contains the environment definition and some common values
- `charts/` - contains internally developed charts grouped per stack
- `upstream/` - contains externally developed charts grouped per source
- `stacks/` - contains release templates for all applications grouped per stack
- `values/` - contains values templates for most applications grouped per stack
- `state.yaml` - the state file that pulls in everything and defines releases

## Usage

While `helmfile` can be invoked via `./bin/ck8s ops helmfile <sc|wc>` it can also be invoked directly from the root of the repository.
Note that you must then point `KUBECONFIG` to the correct cluster and invoke it as `helmfile -e service_cluster|workload_cluster`.

> [!warning]
> When using `helmfile` directly there is no config nor version validation done so be careful!

Selective operations can be done using the `---selector|-l` argument followed by `key=value` labels, additional `--selector|-l` performs _or_, additional labels delimited by comma performs _and_.
Use the `helmfile` operation `list` to view the labels.
Most stacks have the `app` label set, networkpolicies and podsecuritypolicies have the `policy` label set, and all releases have labels for `name` and `chart` set by default.

> [!important]
> When using selective operations use the flag `--include-transitive-needs` to include all dependencies of the selected releases.

All needs are written according to what is needed to get applications **running** not to get applications _usable_ to be able to run a deployment as minimal as possible for local clusters.

## Contributing

### Where to put charts

The workflow for managing helm charts is to add them under `charts/` if they are developed internally, and `upstream/` if they are developed externally.

> [!note]
> [Externally developed charts have some automation to how they are managed.](upstream/).

### Where to put releases

Releases are templated under `stacks/` where it defines name, namespace, labels, chart and version, dependencies, and finally values.

Releases are defined in `state.yaml` which imports the files under `stacks/`.

To differentiate between if a release should be installed on sc or wc set `condition: ck8sManagementCluster.enabled` or `condition: ck8sWorkloadCluster.enabled`.
These values are predefined in the environment and can be used in templating for conditions using `.Values | get "ck8sManagementCluster.enabled" false`.
To install it in both omit the condition.

To differentiate between if a release should be installed on a value set `installed: {{ .Values | get "key.to.enabled" false }}`.
Prefer to use this construct within state and stack files to ensure they can build even with configuration issues.

> [!important]
> Set proper dependencies using `needs` to ensure that everything one release needs is setup before it is attempted to be installed.
>
> Set `disableValidationOnInstall` for releases that install custom resources that is not predefined in the environment.

### Where to put values

Release values templates are stored under `values/` which uses a similar templating as `helm` however `helmfile` has stricter rules and will fail templating when values are missing.
Perform values validation within the values templates with descriptive error messages as the trace `helmfile` gives may not be easy to parse.

Values templates can be split up into multiple files that are merged during templating.
This allows common values to be in one file, while specifics are kept in separate files.
An example would be values common to both sc and wc, and then values specific to sc and wc.
