# Apps Tests

The test suite is implemented using [`bats`](https://github.com/bats-core/bats-core) and [`cypress`](https://github.com/cypress-io/cypress), with unit, regression, integration, and end-to-end tests under their own respective directory.
Tests implemented with `cypress` can and will be integrated into the `bats` test suite using generators.

## Usage

> [!note]
> All instructions assume that you are standing in the `tests/` directory.

> [!warning]
> Known issue that tests requiring use of `docker` or `podman` cannot run within the test container.
>
> Additionally tests running in the test container might hang on interrupts, requiring the container to be killed.

The tests differentiate between static and dynamic tests, all static tests can be run without setting up an environment, and all dynamic tests requires an environment to test.
Static tests are tagged with `static`.

The `tests / unit-static` workflow on GitHub is invoked with the following commands:

```bash
make build-unit
make ctr-run-unit-static
```

### Usage with Makefile

> [!note]
> You can also use `make build`, then `make ctr-<command>` to run each command in a container, skip `make ctr-dep` as they are integrated into the image.
> You must rebuild the image for it to contain your changes.
>
> If you get errors from `bats` about tags then you `bats` version is to old, either update or run in the container.
>
> If you get warnings from `docker` about that the "legacy builder is deprecated" then you need to setup [`buildx`](https://docs.docker.com/go/buildx) on your system.
>
> The container might struggle to prompt for kube-login and gpg-agent, but if those are activated before by accessing the clusters and using gpg then the session can be reused.

You must have `bats`, `make` and `npm` installed

```bash
# For deb based distributions
sudo apt install bats make npm
```

Supporting libraries including `cypress` are fetched automatically as a dependency or with:

```bash
make dep
```

Certain test suites are generated automatically as a dependency or with:

```bash
make gen
```

Run all tests:

```bash
make
```

Run selected tests:

```bash
make run-<unit|regression|integration|end-to-end>
```

Additionally tests can be filtered via tags using the `-<tags,...>` suffix to the `run-<target>` command.

Run individual tests:

```bash
make <file/path> # without trailing .bats, for generated files use the .gen ending
```

Clean up:

```bash
# remove dependencies and generated files
make clean

# remove dependencies
make clean-dep

# remove generated files
make clean-gen
```

### Usage with `bats`

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

### Usage with `cypress`

The plain `cypress` test suite can be manually run as follows:

```bash
# all
npx cypress run
# dirs
npx cypress run --spec <unit|regression|integration|end-to-end>
# files
npx cypress run --spec <path/to/file.cy.js>
```

It can be useful to open `cypress` as it will give you a view of how the tests execute, helping in the development and review process:

```bash
npx cypress open
```

Then it will auto-reload and auto-execute as tests are updated, use `it.only` instead of `it` to run only selected tests.

## Writing

Currently it is possible to write three types of tests, bats tests, cypress tests, and template tests.

### Writing bats tests

Bats tests have a simple structure but requires a setup function to import its functions.
The following template should be used for each file:

```bash
#!/usr/bin/env bats

setup() {
  # $repo-root/tests/common/lib
  load "../common/lib"

  common_setup
}
```

One can define `setup_file` and `teardown_file` functions to run things before and after the file is executed, as well as `setup` and `teardown` functions to run things before and after each test is executed.

The following template can be used to define tests, except for the test definition itself all syntax is regular bash syntax:

```bash
@test "this is a template" {
  assert true
}
```

We currently import [`bats-assert`](https://github.com/bats-core/bats-assert), [`bats-detik`](https://github.com/bats-core/bats-detik), [`bats-support`](https://github.com/bats-core/bats-support), as well as our own [`common/lib.bash`](common/lib.bash).

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
