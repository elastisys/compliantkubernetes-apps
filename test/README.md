# Apps Tests

The test suite is implemented using `bats` and `cypress`, with unit, regression, integration, and end-to-end tests under their own respective directory.
Tests implemented with `cypress` can and will be integrated into the `bats` test suite using generators.

## Usage with Makefile

You must have `bats`, `make` and `npm` installed, supporting libraries including `cypress` are fetched automatically as a dependency or with:

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

Run unit tests:

```bash
make run-unit
```

Run regression tests:

```bash
make run-regression
```

Run integration tests:

```bash
make run-integration
```

Run end-to-end tests:

```bash
make run-end-to-end
```

Clean up:

```bash
# remove dependencies and generated files
make clean-all

# remove dependencies
make clean-dep

# remove generated files
make clean-gen
```

## Usage with `bats`

The plain `bats` test suite can be manually run by simply running `bats` and listing the target directories or files.

## Usage with `cypress`

The plain `cypress` test suite can be manually run as follows for all:

```bash
npx --prefix common/cypress cypress run --config-file "$PWD/common/cypress/cypress.config.js" --project <.|unit|regression|integration|end-to-end>
```

And for specific files:

```bash
npx --prefix common/cypress cypress run --config-file "$PWD/common/cypress/cypress.config.js" --project <.|unit|regression|integration|end-to-end> --spec <path/to/file>
```
