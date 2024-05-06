#!/usr/bin/env make

# If more complexity is to be added, write a script instead.

# name of container image
image := compliantkubernetes-apps-tests

# paths
tests := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
roots := $(patsubst %/,%,$(dir $(tests)))

# launcher
launcher := $(roots)/scripts/run-from-container.sh

# test types
types := unit regression integration end-to-end

# test targets
targets = $(patsubst %/,%,$(foreach type,$(types),$(tests)/$(type)/))

# test suites
suites = $(patsubst %/,%,$(foreach target,$(targets),$(wildcard $(target)/*/)))

# test files
files = $(foreach suite,$(suites),$(wildcard $(suite)/*.bats))

cypress_files = $(foreach suite,$(suites),$(wildcard $(suite)/*.cy.js))
template_files = $(foreach suite,$(suites),$(wildcard $(suite)/*.bats.gotmpl))

generated_files = $(cypress_files:.cy.js=.gen.bats) $(template_files:.bats.gotmpl=.gen.bats)

nproc = $(shell nproc)

list:
	@echo $(patsubst $(tests)/%,%,$(targets)) | tr ' ' '\n'
$(patsubst $(tests)/%,list-%,$(targets)): list-%:
	@echo $(patsubst $(tests)/%,%,$(filter $(tests)/$*/%,$(suites))) | tr ' ' '\n'
$(patsubst $(tests)/%,list-%,$(suites)): list-%:
	@echo $(patsubst $(tests)/%,%,$(filter $(tests)/$*/%,$(files))) | tr ' ' '\n'

build: build-main
build-main build-unit: build-%:
	docker build --file Dockerfile --target $* --tag $(image):$* ../

clean:
	@echo "--- clean"
	@echo $(foreach target,$(targets),$(target)/*.gen.bats) | tr ' ' '\n'
	@rm $(foreach target,$(targets),$(shell find $(target) -type f -name *.gen.bats))

gen: gen-cypress gen-template
gen-cypress: $(cypress_files:.cy.js=.gen.bats)
gen-template: $(template_files:.bats.gotmpl=.gen.bats)

$(cypress_files:.cy.js=.gen.bats): %.gen.bats: %.cy.js common/gen.bash
	@$(tests)/common/gen.bash cypress
$(template_files:.bats.gotmpl=.gen.bats): %.gen.bats: %.bats.gotmpl common/gen.bash
	@$(tests)/common/gen.bash template

$(foreach type,$(types),preflight-$(type)): preflight-%:
	@$(tests)/common/exec.bash preflight $*

run-all:
	@FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true $(launcher) $(image):main make --no-print-directory -C tests container-all
# run-<target/suite/file> wild card
run-unit $(patsubst $(tests)/%,run-%,$(filter $(tests)/unit/%,$(suites) $(files))): run-%: preflight-unit
	@$(launcher) $(image):unit make --no-print-directory -C tests container-$*
run-regression $(patsubst $(tests)/%,run-%,$(filter $(tests)/regression/%,$(suites) $(files))): run-%: preflight-regression
	@FORWARD_RUNTIME=true $(launcher) $(image):main make --no-print-directory -C tests container-$*
run-integration $(patsubst $(tests)/%,run-%,$(filter $(tests)/integration/%,$(suites) $(files))): run-%: preflight-integration
	@FORWARD_RUNTIME=true $(launcher) $(image):main make --no-print-directory -C tests container-$*
run-end-to-end $(patsubst $(tests)/%,run-%,$(filter $(tests)/end-to-end/%,$(suites) $(files))): run-%: preflight-end-to-end
	@FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true $(launcher) $(image):main make --no-print-directory -C tests container-$*

container-all: container-unit container-regression container-integration container-end-to-end
container-unit: $(patsubst $(tests)/%,container-%,$(filter $(tests)/unit/%,$(suites)))
container-regression: $(patsubst $(tests)/%,container-%,$(filter $(tests)/regression/%,$(suites)))
container-integration: $(patsubst $(tests)/%,container-%,$(filter $(tests)/integration/%,$(suites)))
container-end-to-end: $(patsubst $(tests)/%,container-%,$(filter $(tests)/end-to-end/%,$(suites)))

# container-<target/suite/file> wild card
$(patsubst $(tests)/%,container-%,$(filter $(tests)/unit/%,$(suites) $(files))): container-%: $(filter $(tests)/unit/$(%)%,$(generated_files))
	@echo "--- run $*"
	@bats --tap -j $(nproc) -r "$(tests)/$*"
$(patsubst $(tests)/%,container-%,$(filter $(tests)/regression/%,$(suites) $(files))): container-%: $(filter $(tests)/regression/$(%)%,$(generated_files))
	@echo "--- run $*"
	@bats  --tap --no-parallelize-across-files -j $(nproc) -r "$(tests)/$*"
$(patsubst $(tests)/%,container-%,$(filter $(tests)/integration/%,$(suites) $(files))): container-%: $(filter $(tests)/integration/$(%)%,$(generated_files))
	@echo "--- run $*"
	@bats  --tap --no-parallelize-across-files -j $(nproc) -r "$(tests)/$*"
$(patsubst $(tests)/%,container-%,$(filter $(tests)/end-to-end/%,$(suites) $(files))): container-%: $(filter $(tests)/end-to-end/$(%)%,$(generated_files))
	@echo "--- run $*"
	@bats  --tap -r "$(tests)/$*"

enter-unit: preflight-unit
	@$(launcher) $(image):unit bash
enter-regression: preflight-regression
	@FORWARD_RUNTIME=true $(launcher) $(image):main bash
enter-integration: preflight-integration
	@FORWARD_RUNTIME=true $(launcher) $(image):main bash
enter-end-to-end: preflight-end-to-end
	@FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true $(launcher) $(image):main bash

$(patsubst $(tests)/%,setup-%,$(suites)): setup-%:
	@$(tests)/common/exec.bash suite setup $*
$(patsubst $(tests)/%,teardown-%,$(suites)): teardown-%:
	@$(tests)/common/exec.bash suite teardown $*
