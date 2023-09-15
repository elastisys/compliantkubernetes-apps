# Apps Tests

The test suite is implemented using `bats` and `cypress`, with unit, regression, integration, and end-to-end tests under their own respective directory.
Tests implemented with `cypress` can and will be integrated into the `bats` test suite using generators.

> [!note]
> All instructions assume that you are standing in the `tests/` directory.

## Usage with Makefile

> [!note]
> You can also use `make build`, then `make ctr-<command>` to run each command in a container, skip `make ctr-dep` as they are integrated into the image.
> You must rebuild the image for it to contain your changes.

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

## Usage with `bats`

The plain `bats` test suite can be manually run by simply running `bats` and listing the target directories or files.

```bash
# all
bats -r .
# dirs
bats -r <unit|regression|integration|end-to-end>
# files
bats <path/to/file.bats>
```

## Usage with `cypress`

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
