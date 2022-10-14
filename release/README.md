# Release process

The releases will follow semantic versioning and be handled with git tags.
https://semver.org/

## Major and minor releases

1. To release a major or minor version, switch to the branch you want to create the release from (probably main) and run:

    ```bash
    git switch main
    release/feature-freeze-for-major-minor-release.sh vX.Y.0
    ```

1. Now you should be on the QA branch, so now is the time to do QA and add all fixes on this branch.

    **NOTE**: All changes made in QA should be added to `CHANGELOG.md` and **NOT** `WIP-CHANGELOG.md`.

1. Update the Welcoming Dashboards "What's New" section

    Write about some new feature or change that is relevant for the user, e.g. for `v0.25` "- As an admin user, you can now create namespaces yourself using HNC ..."

    Also remove the items in this section from two+ older minor versions, meaning if you release apps `v0.28` you can keep previous items that were added to the list in `v0.27` but remove the stuff that are from `v0.26`.

    - Edit the [Grafana dashboard](../helmfile/charts/grafana-ops/files/welcome.md)
    - Edit the [Opensearch dashboard](../helmfile/charts/opensearch/configurer/files/dashboards-resources/welcome.md)

1. When you're done with QA, create a PR to the release branch and merge it.

1. When the PR is merged switch to that branch and run:

    ```bash
    release/create-major-minor-release.sh
    ```

    *When the script is done a [GitHub actions workflow pipeline](/.github/workflows/release.yml) should've created a GitHub release from that tag.*

1. If there were any changes in the QA branch the script should've prompted you with some cherry-pick commands that you should run.
    When you've run those commands you should create a PR from this branch to main so all QA fixes is merged back to main.

1. Update public release notes.

    When a released is published the public [user-facing release notes](https://github.com/elastisys/compliantkubernetes/blob/main/docs/release-notes/ck8s.md) needs to be updated. The new release needs to be added and the list can be trimmed down to only include the supported versions.

    Add bullet points of major changes within the cluster that affects the user as defined [here](https://compliantkubernetes.io/user-guide/). This includes any change within the cluster that may impact the user experience, for example new or updated feature, or the deprecation of features.

## Patch releases

1. Check out the release branch you want to create a release for:

    ```bash
    git switch release-X.Y
    ```

1. Run the prepare patch command:

    ```bash
    release/prepare-patch-release.sh vX.Y.Z
    ```

1. You should now be on the patch branch.
    Cherry-pick or manually add all fixes that you want to include in the patch.

1. Run reset-changelog:

    ```bash
    release/reset-changelog.sh vX.Y.Z
    ```

1. Create a PR into the release branch and merge it.

1. When the PR is merged, switch to that branch and run:

    ```bash
    git switch release-X.Y
    release/create-patch-release.sh vX.Y.Z
    ```

    *When the script is done a [GitHub actions workflow pipeline](/.github/workflows/release.yml) should've created a GitHub release from that tag.*

1. Follow the major/minor release from step 6 to update the public release notes.

> **_WARNING:_** At the end in the github main page you will see a message like `release-X.Y had recent pushes * minutes ago` and the option to `Compare & pull request` --> Ignore this! Do not create a PR to push back to main!
