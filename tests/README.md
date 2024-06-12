# Apps Tests

The test suite is implemented using [`bats`](https://github.com/bats-core/bats-core) and [`cypress`](https://github.com/cypress-io/cypress), with unit, regression, integration, and end-to-end tests under their own respective directory.

Generators are employed to generate `bats` tests from `cypress` and `gotmpl` tests to integrate it into the rest of test suites.

The test harness is implemented to be run in a container using either rootful `docker` or rootless `podman`.

## Usage

> [!note]
> All instructions assume that you are standing in the `tests/` directory.

> [!warning]
> Do not use `docker` or `podman` directly from tests, as they take differing arguments and may depend on variables present on the host not available within the tests container.
> Instead use tools like `buildah` for building and pushing or `skopeo` for syncing and pulling.
>
> Additionally tests running in the test container might hang on interrupts, requiring the container to be killed.

The tests differentiate between static and dynamic tests, all static tests can be run without setting up an environment, and all dynamic tests requires an environment to test.
Static tests are tagged with `static`.

> [!danger]
> This type of distinction will be phased out and all unit, regression, and integration tests will be required to be static!

The `tests / unit-static` workflow on GitHub is invoked with the following commands:

```bash
# build and run
make build-unit
make run-unit-static
```

The `tests / integration` workflow on GitHub is invoked with the following commands:

```bash
# prepare local cache and local resolve:
../scripts/local-cluster.sh cache create
../scripts/local-cluster.sh resolve create integration.dev-ck8s.com
# build and run
make build-main
make run-integration
```

### Usage with Makefile

> [!note]
> The container might struggle to prompt for kube-login and gpg-agent, but if those are activated before by accessing the clusters and using gpg then the session can be reused.

You must have `make` installed and either rootful `docker` or rootless `podman`!
Check the [DEVELOPMENT](../DEVELOPMENT.md) docs additional requirements to run local-clusters for integration and regression tests.

Certain test suites are generated automatically as a dependency or with:

```bash
make gen
```

Run all tests:

```bash
make all
```

Run selected tests:

```bash
make run-<unit|regression|integration|end-to-end>
```

Additionally tests can be filtered via tags using the `-<tags,...>` suffix to the `run-<target>` command.

Clean up:

```bash
# remove dependencies and generated files
make clean

# remove generated files
make clean-gen
```

### Direct usage with `bats` or `cypress`

Direct usage is possible by entering the tests container:

```bash
make enter-<unit|regression|integration|end-to-end>
cd tests/
```

The plain `bats` test suite can be manually run by simply running `bats` and listing the target directories or files.

```bash
# all
bats -r .
# dirs
bats -r <unit|regression|integration|end-to-end>
# files
bats <path/to/file.bats>
```

Additionally tests can be filtered via tags using the `--filter-tags <tags,...>` argument.

```bash
# all
cypress run
# dirs
cypress run --spec <unit|regression|integration|end-to-end>
# files
cypress run --spec <path/to/file.cy.js>
```

It can be useful to open `cypress` as it will give you a view of how the tests execute, helping in the development and review process:

```bash
cypress open
```

Then it will auto-reload and auto-execute as tests are updated, use `it.only` instead of `it` to run only selected tests.

This is also possible to do from outside of the container with:

```bash
make run-cypress-open
```

## Writing

Currently it is possible to write three types of tests, bats tests, cypress tests, and template tests.

### Writing bats tests

Bats tests have a simple structure but requires a setup function to import its functions.
The following template should be used for each file:

```bash
#!/usr/bin/env bats

setup() {
  load "../bats.lib.bash"

  # additional loads for helpers
  # check the bats.lib.bash for load functions, and common/bats/ for helpers
}
```

One can define `setup_file` and `teardown_file` functions to run things before and after the file is executed, as well as `setup` and `teardown` functions to run things before and after each test is executed.

The following template can be used to define tests, except for the test definition itself all syntax is regular bash syntax:

```bash
@test "this is a template" {
  assert true
}
```

### Writing cypress tests

Cypress have an extensive [documentation](https://docs.cypress.io) for writing tests.
We currently import our own [`cypress.support.js`](cypress.support.js) support file that provide helper functions available using the `cy` object from within tests.

The makefile will generate bats files to run the cypress to integrate it into the same test suite.

### Writing template tests

Since bats lacks parametric tests we employ a generator to work with go-templates using [gomplate](https://github.com/hairyhenderson/gomplate) check their documentation for the functions it provides.

The templates themselves are evaluated without any external values and are discovered using the file ending `.bats.gotmpl` and generated to the file ending `.gen.bats`.

It is possible to template one test suite into multiple files, see the `unit/bin/init/` or `unit/validate/` for reference.

### Writing resource tests

Some tests need pregenerated resources that are used as the assertion during tests.

To regenerate these resources export `CK8S_TESTS_REGENERATE_RESOURCES="true"` and run tests with the `resources` tag.

```bash
export CK8S_TESTS_REGENERATE_RESOURCES="true"
make run-unit-static,resources
```

When writing tests that uses resources that may change ensure that the tests can regenerate their resources when this variable is set.

## Regression tests

Whenever a bug is fixed there should be an associated regression test written to ensure that the bug will not resurface.

Add them into `tests/regression` with the name format `<issue-or-pr-number>-<short-description>`.
Use issue number if it exists in this repository, else use PR number.
