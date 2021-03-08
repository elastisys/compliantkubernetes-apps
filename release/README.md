# Release process

The releases will follow semantic versioning and be handled with git tags.
https://semver.org/

## Major and minor releases

1. To release a major or minor version create a release branch `release-X.Y` from the last minor release tag.

    ```bash
    git checkout main
    git checkout -b release-X.Y
    git push -u origin release-X.Y
    ```

1. Reset changelog

    ```bash
    git checkout -b reset-changelog-X.Y
    release/reset-changelog.sh X.Y.0
    ```

    The release script will:
    * Append what is in `WIP-CHANGELOG.md` to `CHANGELOG.md`
    * Clear `WIP-CHANGELOG.md`
    * Create a git commit with message `Reset changelog for release vX.Y.Z`

    Make sure that the changes only include changes mentioned above, and then push.

    ```
    git diff HEAD~1
    git push
    ```

1. Merge `reset-changelog-X.Y` into `release-X.Y` then, into `main` as soon as possible to minimize risk of conflicts

    **NOTE**: The release action will fail since we haven't tagged the release commit.
    We will do that after QA.

1. Run QA checks on `branch_name` and commit any fixes found during QA into `release-X.Y`.

    **NOTE**: All changes made in QA should be added to `CHANGELOG.md` and **NOT** `WIP-CHANGELOG.md`.

1. Run the release script.

    ```bash
    ./release/release.sh X.Y.0
    ```

    The release script will:
    * Amend last commit and prepend message `Release vX.Y.Z`
    * Create a tag named `vX.Y.Z`

1. Push the tagged commit, create a PR against the release branch and request a review.

    ```bash
    git push --atomic origin branch_name vX.Y.Z
    ```

1. Merge it to finalize the release.
    A [GitHub actions workflow pipeline](.github/workflows/release.yml) will create a GitHub release from the tag.

    *GitHub currently does not support merging with fast-forward only.
    Merge the release PR locally and push it instead.*

    ```bash
    git checkout release-X.Y
    git merge --ff-only branch_name
    git push

    # If 'git merge --ff-only' isn't possible, 'git rebase' can be used.
    git checkout release-X.Y
    git rebase --onto branch_name
    git push --force-with-lease
    ```

1. Merge any fixes from the release branch back to the `main` branch
    `git cherry-pick` can be used, e.g.

    ```bash
    git checkout main
    git checkout -b release-X.Y-fixes
    git cherry-pick <fix 1 hash> [<fix 2 hash>..]
    ```

## Patch releases

1. Create a new branch based on a release branch and commit the patch commits to it.

    ```bash
    git checkout release-X.Y
    git pull
    git checkout -b branch_name
    git cherry-pick [some fix in main]
    git add -p file-with-some-new-fixes
    git commit
    ```

2. Continue from step 3 in the major/minor release flow.

## While developing

When a feature or change is developed on a branch fill out some human readable
bullet points in the `WIP-CHANGELOG.md` this will make it easier to track the changes.
Once the release is done this will be appended to the main changelog.

## Structure

The structure follow the guidelines of [keepachangelog](https://keepachangelog.com/en/1.0.0/).

Changelogs are for humans, not machines. Keep messages in human readable form rather
than commits or code. Commits or pull requests can off course be linked. Add messages
as bullet points under one of theese categories:

* Breaking changes
* Release notes
* Added
* Changed
* Deprecated
* Removed
* Fixed
* Security

When creating a major release a section of `Release highlights` should be added
on top of the WIP-changelog with a summary of the most important changes.

You can link comments to related pull requests with `PR#pr-number`. Commit ids can be linked
by just writing that commits short hash or full hash.

# Example changelog

## v0.1.2 - 2020-01-14  (OBS! this line is automatically added by script)

### Breaking changes

* The API endpoint xxxx has been removed.

### Release notes

* To migrate the resources depending on yyyy you have to run [this script](..).

### Added

* Option to add prometheus scrape endpoints
* Retetion for elasticsearch

### Changed

* Updated grafana version to 6.7.0
* Changed manifests for deploying ck8sdash into a helm chart PR#120

### Deprecated

* Option to disable OPA with `ENABLE_OPA` variable. Now always true

### Removed

* Curator has been removed. Now retention is configured with ILM.

### Fixed

* bugfix deploying elasticsearch operator 2310e74
