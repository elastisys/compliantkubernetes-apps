# Migration steps

This directory contains the migration steps for each major and minor version, including the documentation with instructions and the snippets for automation of the upgrade process.

> [!note]
> Only the five latest major and minor releases are kept, if you want to see the migration guides for older versions then you need to check out that version of the repository.

## Migration template and script

> [!NOTE]
> Only major releases are supported by the script

There is a script that can help you create the initial migration folder and `upgrade-apps.md` document. You can use the following command to run it from the root of compliantkubernetes-apps directory:

```bash
./migration/create-migration-document.sh v0.66 v0.67
```
