**What this PR does / why we need it**:

**Which issue this PR fixes** *(use the format `fixes #<issue number>(, fixes #<issue_number>, ...)` to automatically close the issue when PR gets merged)*: fixes #

**Public facing documentation PR** *(if applicable)*
<!-- https://github.com/elastisys/compliantkubernetes/pull/ -->

**Special notes for reviewer**:

**Checklist:**

- [ ] Added relevant notes to [WIP-CHANGELOG.md](https://github.com/elastisys/compliantkubernetes-apps/blob/main/WIP-CHANGELOG.md)
- [ ] Proper commit message prefix on all commits
- [ ] Updated the [public facing documentation](https://github.com/elastisys/compliantkubernetes)
- Is this changeset backwards compatible for existing clusters? Applying:
    - [ ] is completely transparent, will not impact the workload in any way.
    - [ ] requires running a migration script.
    - [ ] will create noticeable cluster degradation.
          E.g. logs or metrics are not being collected or Kubernetes API server
          will not be responding while upgrading.
    - [ ] requires draining and/or replacing nodes.
    - [ ] will change any APIs.
          E.g. removes or changes any CK8S config options or Kubernetes APIs.
    - [ ] will break the cluster.
          I.e. full cluster migration is required.
- Chart checklist (pick exactly one):
    - [ ] I upgraded no Chart.
    - [ ] I upgraded a Chart and determined that no migration steps are needed.
    - [ ] I upgraded a Chart and added migration steps to [WIP-CHANGELOG.md](https://github.com/elastisys/compliantkubernetes-apps/blob/main/WIP-CHANGELOG.md).

**Pipeline config** *(if applicable)*
If you change some config options (e.g. add/rename variable or change the default value) you may need to update the config used by the pipeline in `pipeline/config`.

<!--
Here are the commit prefixes and comments on when to use them:
all: (things that touch on more than one of the areas below, or don't fit any of them)
apps: (changes to the applications running in both/all clusters)
apps sc: (changes to applications in the service cluster)
apps wc: (changes to applications in the workload cluster)
docs: (documentation)
tests: (test related changes)
pipeline: (the pipeline)
config: (configuration, e.g. add/remove/rename a parameter, this is not for changes to the default values for an application that would go into `apps [sc/wc]`)
bin: (changes to binaries or scripts used manage ck8s)
release: (anything release related)

Example commit prefix usage:

git commit -m "docs: Add instructions for how to do x"
-->
