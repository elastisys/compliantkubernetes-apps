#!/usr/bin/make

dirs := unit regression integration end-to-end

# Pure bats tests
bats_suites = $(filter-out %.gen.bats,$(foreach dir, $(dirs), $(wildcard $(dir)/*.bats)))

# Cypress tests
cypress_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.cy.js))
cypress_gen := $(cypress_suites:.cy.js=.gen.bats)

# Template tests
template_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.bats.yaml))
template_gen := $(template_suites:.bats.yaml=.gen.bats)

config_path := ${CK8S_CONFIG_PATH}

container_image := elastisys-ck8s-apps-tests:main

ifndef GNUPGHOME
GNUPGHOME := ${HOME}/.gnupg
endif

container_arg := -it --rm
container_arg := $(container_arg) --env=CK8S_CONFIG_PATH=${CK8S_CONFIG_PATH}
container_arg := $(container_arg) --env=ROOT=/apps
container_arg := $(container_arg) --mount type=bind,source=${CK8S_CONFIG_PATH},target=${CK8S_CONFIG_PATH}
container_arg := $(container_arg) --mount type=bind,source=${GNUPGHOME},target=/home/ubuntu/.gnupg,readonly
container_arg := $(container_arg) --mount type=bind,source=${HOME}/.kube/cache/oidc-login,target=/home/ubuntu/.kube/cache/oidc-login
container_arg := $(container_arg) --mount type=bind,source=/run/user/$(shell id -u),target=/run/user/$(shell id -u),readonly
container_arg := $(container_arg) --network=host
container_arg := $(container_arg) --user $(shell id -u):$(shell id -g)

found_apt := $(shell command -v apt 2>/dev/null)

found_bats := $(shell command -v bats 2>/dev/null)
found_npm := $(shell command -v npm 2>/dev/null)

found_podman := $(shell command -v podman 2>/dev/null)

all := $(bats_suites) $(cypress_gen) $(template_gen)

all: $(all) | dep
	@echo --- bats all
	@bats -r unit regression integration end-to-end

run-unit: $(filter unit/%, $(all)) | dep
	@echo --- bats unit
	@bats -r unit

run-regression: $(filter regression/%, $(all)) | dep
	@echo --- bats regression
	@bats -r regression

run-integration: $(filter integration/%, $(all)) | dep
	@echo --- bats integration
	@bats -r integration

run-end-to-end: $(filter end-to-end/%, $(all)) | dep
	@echo --- bats end-to-end
	@bats -r end-to-end

$(all:.bats=): %: %.bats
	@echo --- bats $*.bats
	@bats -r $*.bats

dep: dep-bats common/bats/assert common/bats/detik common/bats/support dep-npm node_modules

dep-bats:
ifndef found_bats
ifdef found_apt
	@echo "missing dependency: bats - install it using 'sudo apt install bats'"
else
	@echo "missing dependency: bats - install it using your method of choice"
endif
	@exit 1
endif

dep-npm:
ifndef found_npm
ifdef found_apt
	@echo "missing dependency: npm - install it using 'sudo apt install npm'"
else
	@echo "missing dependency: npm - install it using your method of choice"
endif
	@exit 1
endif

common/bats/assert:
	@echo --- git clone github.com/bats-core/bats-assert
	@git clone https://github.com/bats-core/bats-assert.git common/bats/assert
	@echo

common/bats/detik:
	@echo --- git clone github.com/bats-core/bats-detik
	@git clone https://github.com/bats-core/bats-detik.git common/bats/detik
	@echo

common/bats/support:
	@echo --- git clone github.com/bats-core/bats-support
	@git clone https://github.com/bats-core/bats-support.git common/bats/support
	@echo

node_modules:
	@echo --- npm install
	@npm install --save-dev
	@echo

gen: gen-template gen-cypress

gen-cypress: $(cypress_gen)

gen-template: $(template_gen)

$(cypress_gen): %.gen.bats: %.cy.js common/gen-cypress.bash
	@echo gen-cypress $< to $@
	@./common/gen-cypress.bash $< > $@

$(template_gen): %.gen.bats: %.bats.yaml common/gen-bats.bash
	@echo gen-bats $< to $@
	@./common/gen-bats.bash $< > $@

clean: clean-dep clean-gen

clean-dep:
	@echo rm common/bats
	@rm -rf common/bats
	@echo rm node_modules
	@rm -rf node_modules

clean-gen:
	@echo rm $(foreach dir, $(dirs), $(wildcard $(dir)/*.gen.bats))
	@rm -f $(foreach dir, $(dirs), $(wildcard $(dir)/*.gen.bats))

build:
ifdef found_podman
	podman build -t $(container_image) .
else
	docker build -t $(container_image) .
endif

ctr-%:
ifdef found_podman
	podman run --userns=keep-id $(container_arg) $(container_image) make $*
else
	docker run $(container_arg) $(container_image) make $*
endif

print-%:
	@echo $($*)
