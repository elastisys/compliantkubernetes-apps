# Apps Tests

The test suite is implemented using [`bats`](https://github.com/bats-core/bats-core) and [`cypress`](https://github.com/cypress-io/cypress), with unit, regression, integration, and end-to-end tests under their own respective directory.
Tests implemented with `cypress` can and will be integrated into the `bats` test suite using generators.

## Usage

> [!note]
> All instructions assume that you are standing in the `tests/` directory.

### Usage with Makefile

> [!note]
> You can also use `make build`, then `make ctr-<command>` to run each command in a container, skip `make ctr-dep` as they are integrated into the image.
> You must rebuild the image for it to contain your changes.
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

Since bats lack a way to generate tests based on data we employ a generator to transform yaml specs into bats tests.

The base for the format is as follows:

```yaml
# required: name of the test suite
name: test suite name
# required: list of the tests
tests:
    # required: list of clusters the test applies to, renders down to use "with_kubeconfig <cluster>"
  - clusters: [ sc, wc ]
    # required: list of namespaces the test applies to, renders down to use "with_namespace <namespace>"
    namespaces: [ kube-public, kube-system ]
    # required: name of the test function to run
    function: test_function
    # optional: expression of test condition evaluated during runtime against the config
    condition: .feature.enabled
    # optional: name of the target to test, passed to the test function as the first parameter
    target: feature
    # optional: list of additional arguments passed to the test function
    args: [ argument ]
    # optional: list of additional tests
    tests: []
```

The format is recursive and keeps variables set for one test as it goes deeper into the spec.
Any `clusters`, `namespaces` and `function` fields overwrites the previously set variable, while `condition` fields are accumulative.
Any `target` field will case tests to be emitted for each cluster and namespace combo, skipping the `tests` fields in the same spec.
Arguments starting with a `.` are treated as an expression and evaluated during runtime against the config.

## Possible issues

1. If, when executing `make build`, you get `404  Not Found` at the `apt update` step, you may need to remove the local `ubuntu:rolling` image
