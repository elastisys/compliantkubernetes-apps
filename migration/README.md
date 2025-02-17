# Upgrade and migration

This directory contains the upgrade and migration steps for each major and minor version, including the documentation with instructions and the snippets for automation of the upgrade process.

> [!note]
> Only the five latest major and minor releases are kept, if you want to see the migration guides for older versions then you need to check out that version of the repository.

## Writing migration steps for contributions

Notice to developers on writing migration steps:

- Migration steps:
    - are written for every major and minor version and placed in a subdirectory of the migration directory with the name `main/`,
        - during release this is promoted to the next release series `vX.Y/`,
    - are written to be idempotent and usable no matter which patch version you are upgrading from and to,
    - are documented in `main/README.md` to be able to run them manually,
    - are divided into prepare and apply steps:
        - Prepare steps:
            - are placed in the `prepare/` directory,
            - may **only** modify the configuration of an environment,
            - may **not** modify the state of an environment,
            - steps are run in order of their names using two digit prefixes.
        - Apply steps:
            - are placed in the `apply/` directory,
            - may **only** modify the state of an environment,
            - may **not** modify the configuration of an environment,
            - are run in order of their names using two digit prefixes,
            - are run with the argument `execute` on upgrade and should return 1 on failure and 2 on successful internal rollback,
            - are rerun with the argument `rollback` on execute failure and should return 1 on failure.

[Prepare snippets](main/prepare) are supposed to update the environment's configuration to the target version, an example snippet is the init step which runs the `ck8s init` command.
[Apply snippets](main/apply) are supposed to update the environment's applications to the target versions, and example snippet is the apply step which run `helmfile upgrade` on all releases that have changed.
It is expected that releases upgraded in other snippets are excluded from the apply snippet.

> [!tip]
> This can be done by adding label expression of releases into the `skipped*` arrays of the `80-apply.sh` snippet:
>
> ```diff
> --- a/migration/main/apply/80-apply.sh
> +++ b/migration/main/apply/80-apply.sh
> @@ -9,12 +9,15 @@ source "${ROOT}/scripts/migration/lib.sh"
>  # Example: "app!=something"
>  declare -a skipped
>  skipped=(
> +  "app!=something"
>  )
>  declare -a skipped_sc
>  skipped_sc=(
> +  "app!=something"
>  )
>  declare -a skipped_wc
>  skipped_wc=(
> +  "app!=something"
>  )
>
>  run() {
> ```
>
> During runtime these are `AND`:ed together.

Upgrades of components that are dependent on each other should be done within the same snippet to easily manage the upgrade to a working state and to be able to rollback to a working state.

Steps should use the `scripts/migration/lib.sh` which will provide helper functions, see the file for available helper functions.
This script expects the `ROOT` environment variable to be set pointing to the root of the repository.
As with all scripts in this repository `CK8S_CONFIG_PATH` is expected to be set.

> [!important]
> Since the migration snippets should be idempotent and usable from and to any patch version, it is important that they only perform actions when needed, especially in the case of destructive actions!
>
> Example: if a major upgrade of a component requires that another component is temporarily removed, then it should **only** remove the component if there is a major upgrade in the first place, if there is a minor upgrade then it should be applied without removing the component.

We also need them to be idempotent to be able to reuse them between release series, for example to update Grafana, OpenSearch, Prometheus, or Thanos, if not covered by the general apply snippet.
Some snippets will still be specific to a specific version and those snippets should be named with the suffix `-version-specific.sh` to easily identify them.

## Preparing migration steps for releases

When releasing new major or minor versions of Welkin Apps the current upgrade and migration directory should be promoted to the one for the release.
To do this run:

```bash
./migration/promote.sh vX.Y
```

This script will create a new directory for the `vX.Y` release series from the `main` directory, and prune old directories to only include the latest five releases.

Once the new directory is created you must manually remove snippets and steps that was specific for the new release named with the suffix `-version-specific.sh`, be sure to remove any exclusions from them set in the `80-apply.sh` snippet based on the tip in the previous section.
General migration steps, such as snippets for upgrading Grafana, OpenSearch, Prometheus, or Thanos, may be retained as long as they verify beforehand they run that they are needed, and fall back to a generic upgrade steps if not required.
