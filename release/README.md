# Release process

The releases will follow [semantic versioning](https://semver.org/) and be handled with git tags.

## Constraints

The following constraints apply on releases:

1. Major releases (v**X**.Y.Z and v0.**Y**.Z):

    > _Updates that bring new features and improvements that require coordination with the user._

    - May perform major additions, modifications, or deletions to the application and command line interfaces.

        Example of major change would be to change the way commands are processed.

    - May perform major additions, modifications, or deletions to the configuration structure.

        Example of major change would be to change the way configuration is processed.

    - May perform major upgrades and updates to the deployed services and third party tools.

        Example of major change would be to upgrade or replace major services or stacks.

1. Minor releases (vX.**Y**.Z):

    > _Updates that bring new features and improvements that does not require coordination with the user._

    - May **only** perform minor additions, modifications, or deletions to the application and command line interfaces.

          The interfaces _should_ keep similar behaviour between different minor releases to ensure that they work with similar sets of features and tools on the same major version.

          Example of minor change would be to change the way commands are processed in a backwards compatible way.

    - May **only** perform minor additions, modifications, or deletions to the configuration structure.

          The configuration _should_ keep similar management and structure between different minor releases to ensure that they work with similar sets of features and tools on the same major version.

          Example of minor change would be to change parts of the configuration for services and components in a backwards compatible way.

    - May **only** perform minor upgrades or updates to the deployed services and third party tools.

          The deployed services _should_ be the same between different minor releases to ensure that they work with similar sets of features and tools on the same major version.

          Example of minor change would be to upgrade or change minor services or components.

1. Patch releases (vX.Y.**Z**):

    > _Patches to fix known vulnerabilities threatening user data assessed as an immediate risk._

    - May **only** perform patch additions or modifications to the application and command line interfaces.

          The interfaces **must** keep similar behaviour between different patch releases to ensure that they work with the same sets of features and tools, and can be applied over any patch version on the same minor version.

          Example of allowed patches would be to correct faulty behaviour.

    - May **only** perform patch additions or modifications to the configuration structure.

          The configuration **must** keep similar management and structure between different patch releases to ensure that they work with the same sets of features and tools, and can be applied over any patch version on the same minor version.

          Example of allowed patches would be for missing or invalid configurations.

    - May **only** perform patch or security updates to the deployed services or third party tools.

          The deployed services **must** be the same between different patch releases to ensure that they work with the same sets of features and tools, and can be applied over any patch version on the same minor version.

          Example of allowed patches would be for upgrading patch versions of services and third party tools due to security vulnerabilities.

## Feature freeze

> [!warning]
> This step is only done for major or minor releases.
> For patch releases switch to the existing release branch.

Create a release branch `release-X.Y` from the main branch:

```bash
git switch main
git switch -c release-X.Y
git push -u origin release-X.Y
```

## Staging

For patch releases, configure the list of commits that you want to backport:

```bash
export CK8S_GIT_CHERRY_PICK="COMMIT-SHA [COMMIT-SHA ...]"
```

Stage the release:

```bash
release/stage-release.sh X.Y.Z
```

Running the script above will:

- Create a staging branch from the release branch.
- Cherry pick commits in `${CK8S_GIT_CHERRY_PICK}`, if there are any.
- Generate and commit the changelog.

Push the staging branch and open a draft pull request to the release branch:

```bash
git push -u origin staging-X.Y.Z
```

If there is no migration document, create one as described [here](../migration/README.md).
If a migration document already exists, make sure that it follows [this template](../migration/template/README.md).

Perform QA on the staging branch.
If any fixes are necessary, add a manual changelog entry and push them to the staging branch.

## Code freeze

When the QA process is finished the code should be in a state where it's ready to be released.

Mark the staging pull request ready for review.

## Release

Update the SBOM, ensure it gets validated and carefully look at the diff and address any manual overrides needed:

```sh
./bin/ck8s sbom generate
./bin/ck8s sbom get-unset   # update any components listed
```

When the staging branch has been merged, finalize the release by tagging the HEAD of the release branch and push the tag.

```bash
git switch release-X.Y
git pull
git tag vX.Y.Z
git push --tags
```

A [GitHub actions workflow pipeline](/.github/workflows/release.yml) will create a GitHub release from the tag.

## Update public release notes

When a release is published [the public application developer facing release notes](https://github.com/elastisys/welkin/blob/main/docs/release-notes/welkin.md) needs to be updated.
The new release needs to be added and the list can be trimmed down to only include the supported versions.

```bash
release/generate-release-notes.sh X.Y.Z
```

The public release notes are aimed towards application developers.
Remove irrelevant entries and/or reword entries so that they are easy to understand for the application developers.

### For major and minor releases

This will be done in two steps, first to add it to the main branch, second to create a new release branch.

1. In the [elastisys/welkin](https://github.com/elastisys/welkin) repository, create a new branch `<personal-tag>/release-vX.Y.Z` from the `main` branch.
    Then add the release notes to the `<personal-tag>/release-vX.Y.Z` and create a pull request to the `main` branch.

1. When the pull-request is merged create a new branch `release-vX.Y` from the `main` branch and push it to create it.

### For patch releases

This will be done in two steps, first to add it to the release branch, second to add it to the main branch.

1. In the [elastisys/welkin](https://github.com/elastisys/welkin) repository, create a new branch `<personal-tag>/release-vX.Y.Z` from the `release-vX.Y` branch.
    Then add the release notes to the `<personal-tag>/release-vX.Y.Z` and create a pull request to the `release-vX.Y` branch.

1. When the first pull-request is merged create a new branch `<personal-tag>/release-vX.Y.Z-main` from the `main` branch.
    Then cherry-pick the commit you did on the other branch and create pull request to the `main` branch.

## Update the main branch

Port the changelog and all applicable fixes done in the QA process to the main branch:

```bash
git switch main
git pull
git switch -c port-X.Y.Z
git cherry-pick [changelog commit SHA]
git cherry-pick [fix 1 commit SHA]
git cherry-pick [fix 2 commit SHA]
git cherry-pick [fix N commit SHA]
git push -u origin port-X.Y.Z
```

Open a pull request to the main branch.
