# Upgrade and migration

This directory contains the upgrade and migration steps for each major and minor version, including the documentation with instructions and the snippets for automation of the upgrade process.

> [!note]
> Only the five latest major and minor releases are kept, if you want to see the migration guides for older versions then you need to check out that version of the repository.

## Writing migration steps for contributions

Notice to developers on writing migration steps:

- Migration steps:
  - are written per minor version and placed in a subdirectory of the migration directory with the name `vX.Y/`,
  - are written to be idempotent and usable no matter which patch version you are upgrading from and to,
  - are documented in this document to be able to run them manually,
  - are divided into prepare and apply steps:
    - Prepare steps:
      - are placed in the `prepare/` directory,
      - may **only** modify the configuration of the environment,
      - may **not** modify the state of the environment,
      - steps are run in order of their names use two digit prefixes.
    - Apply steps:
      - are placed in the `apply/` directory,
      - may **only** modify the state of the environment,
      - may **not** modify the configuration of the environment,
      - are run in order of their names use two digit prefixes,
      - are run with the argument `execute` on upgrade and should return 1 on failure and 2 on successful internal rollback,
      - are rerun with the argument `rollback` on execute failure and should return 1 on failure.

For prepare the init step is given.
For apply the bootstrap and the apply steps are given, it is expected that releases upgraded in custom steps are excluded from the apply step.

Upgrades of components that are dependent on each other should be done within the same snippet to easily manage the upgrade to a working state and to be able to rollback to a working state.

Steps should use the `scripts/migration/lib.sh` which will provide helper functions, see the file for available helper functions.
This script expects the `ROOT` environment variable to be set pointing to the root of the repository.
As with all scripts in this repository `CK8S_CONFIG_PATH` is expected to be set.

## Preparing migration steps for releases

When releasing new major or minor versions of Welkin Apps the current upgrade and migration directory should be promoted to the one for the release.
To do this run:

```bash
./migration/promote.sh vX.Y
```

This script will create a new directory for the `vX.Y` release series from the `main` directory, and prune old directories to only include the latest five releases.

Once the new directory is created you must manually remove snippets and steps that was specific for the new release.
General migration steps, such as snippets for upgrading OpenSearch, Prometheus, or Thanos, may be retained as long as they verify beforehand they run that they are needed, and fall back to a generic upgrade steps if not required.
