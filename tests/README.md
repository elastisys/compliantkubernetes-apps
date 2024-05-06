# Apps Tests

The test harness is implemented using [`bats`](https://github.com/bats-core/bats-core) and [`cypress`](https://github.com/cypress-io/cypress), with unit, regression, integration, and end-to-end _test targets_ each under their own respective directory.
Furthermore each test target is composed of one or more _test suites_ each under their own directory container one or more _test files_.

Plain `bats` tests are generated from `cypress` tests to integrate them into the rest of the test harness, additionally plain `bats` tests are generated from `gotmpl` tests to provide parametric tests.

The test harness is implemented to be run in a container using either rootful `docker` or rootless `podman`.

## Usage

> [!note]
> All instructions assume that you are standing in the `tests/` directory.

> [!warning]
> Do not use `docker` or `podman` directly from tests, as they take differing arguments and may depend on variables present on the host not available within the tests container.
> Instead use tools like `buildah` for building and pushing or `skopeo` for syncing and pulling.
>
> Additionally tests running in the test container might hang when interrupted, this might be due to long running teardown tasks, however should it hang for more then a few minutes the container needs to be killed manually.

The `tests / unit` workflow on GitHub is invoked with the following commands:

```bash
# build and run
make build-unit
make run-unit
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
> This is applicable for regression, integration, and end-to-end tests.

You must have `make` and either rootful `docker` or rootless `podman` installed!
Check the [DEVELOPMENT](../DEVELOPMENT.md) docs additional requirements to run local-clusters for integration and regression tests.

Run all tests:

```bash
make run-all
```

Run selected tests:

```bash
make run-<target>                # list targets with make list
make run-<target>/<suite>        # list targets with make list-<target>
make run-<target>/<suite>/<file> # list targets with make list-<target>/<suite>
```

Normally plain bats tests are generated for cypress and template tests as a prerequisite before running them.
If cypress and template tests are not being updated and run via bats as expected then you can force a clean up and regeneration of them:

```bash
make clean
make gen
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
# to filter on tags add the argument --filter-tags <tags,...>
```

> [!important]
> When running `cypress` tests as described below there will be no automatic setup or teardown done if defined by the test suite.
>
> This can be manually done and will generate environment variables that must be sourced before running any tests:
>
> ```bash
> make setup-<target>/<suite>
>
> set -a; source suite.env; set +a
>
> # commands running cypress tests...
>
> make teardown-<target>/<suite>
> ```

The `cypress` tests can also be manually run directly through `cypress`:

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

It will auto-reload and auto-execute as tests are updated, use `it.only` instead of `it` to run only selected tests.

## Writing

Currently it is possible to write three types of tests, bats tests, cypress tests, and template tests.

### Writing bats tests

Bats tests have a simple structure but requires a setup function to import its functions.
The following template should be used for each file:

```bash
#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"

  # additional loads for helpers
  # check the bats.lib.bash for load functions, and common/bats/ for helpers
}
```

One can define setup / teardown functions for each test suite, each test file, and each test.
For each test suite create a `setup_suite.bash` file in that suite and implement the functions `setup_suite` / `teardown_suite`.
For each test file implement the functions `setup_file` / `teardown_suite`.
For each test implement the functions `setup` / `teardown`.

Exported environment variables will have the following scope:

- ( `setup_suite` ( `setup_file` ( `setup` ( `@test` ) `teardown` ) `teardown_file` ) `teardown_suite` ).

Sourced functions will have the following scope:

- ( `setup_suite`, `teardown_suite` ), ( `setup_file`, `teardown_file` ), ( `setup` ( `@test` ) `teardown` ).

The following template can be used to define tests, except for the test definition itself all syntax is regular bash syntax:

```bash
@test "this is a template" {
  assert true
}
```

### Writing cypress tests

Cypress have an extensive [documentation](https://docs.cypress.io) for writing tests.
We currently import our own [`cypress.support.js`](cypress.support.js) support file that provide helper functions available using the `cy` object from within tests.

The makefile will generate bats files to run the cypress to integrate both into the same test harness.

### Writing template tests

Since bats lacks parametric tests we employ a generator to work with go-templates using [gomplate](https://github.com/hairyhenderson/gomplate) check their documentation for the functions it provides.

The templates themselves are evaluated without any external values and are discovered using the file ending `.bats.gotmpl` and generated to the file ending `.gen.bats`.

It is possible to template one test suite into multiple files, see the `unit/templates/` for reference.

### Writing resource tests

Some tests need pregenerated resources that are used as the assertion during tests.

To regenerate these resources export `CK8S_TESTS_REGENERATE_RESOURCES="true"` and run tests with the `resources` tag.

```bash
export CK8S_TESTS_REGENERATE_RESOURCES="true"
make enter-<target>
bats <file> --filter-tags resources
```

When writing tests that uses resources that may change ensure that the tests can regenerate their resources when this variable is set.

## Regression tests

Whenever a bug is fixed there should be an associated regression test written to ensure that the bug will not resurface.

Add them into `tests/regression` with the name format `<issue-or-pr-number>-<short-description>`.
Use issue number if it exists in this repository, else use PR number.
