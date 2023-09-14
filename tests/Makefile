#!/usr/bin/make

dirs := unit regression integration end-to-end

bats_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.bats))
bats_templates := $(foreach dir, $(dirs), $(wildcard $(dir)/*.bats.yaml))
bats_gen := $(bats_templates:.bats.yaml=.gen.bats)

cypress_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.cy.js))
cypress_gen := $(cypress_suites:.cy.js=.gen.bats)

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

found_podman := $(shell command -v podman 2>/dev/null)

run-all: $(bats_suites) $(bats_gen) $(cypress_gen) | dep
	@echo --- bats all
	@bats -r unit regression integration end-to-end

run-unit: $(filter unit/%, $(bats_suites)) $(filter unit/%, $(bats_gen)) $(filter unit/%, $(cypress_gen)) | dep
	@echo --- bats unit
	@bats -r unit
run-regression: $(filter regression/%, $(bats_suites)) $(filter regression/%, $(bats_gen)) $(filter regression/%, $(cypress_gen)) | dep
	@echo --- bats regression
	@bats -r regression
run-integration: $(filter integration/%, $(bats_suites)) $(filter integration/%, $(bats_gen)) $(filter integration/%, $(cypress_gen)) | dep
	@echo --- bats integration
	@bats -r integration
run-end-to-end: $(filter end-to-end/%, $(bats_suites)) $(filter end-to-end/%, $(bats_gen)) $(filter end-to-end/%, $(cypress_gen)) | dep
	@echo --- bats end-to-end
	@bats -r end-to-end

@PHONY: clean-dep clean-gen

dep: common/bats/assert common/bats/detik common/bats/support common/cypress/node_modules

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

common/cypress/node_modules:
	@echo --- npm install cypress
	@npm install --prefix common/cypress --save-dev
	@echo

gen: gen-bats gen-cypress

gen-bats: $(bats_gen)

gen-cypress: $(cypress_gen)

$(bats_gen): %.gen.bats: %.bats.yaml common/gen-bats.bash
	@echo gen-bats $< to $@
	@./common/gen-bats.bash $< > $@

$(cypress_gen): %.gen.bats: %.cy.js common/gen-cypress.bash
	@echo gen-cypress $< to $@
	@./common/gen-cypress.bash $< > $@

clean-all: clean-dep clean-gen

clean-dep:
	@echo rm common/bats
	@rm -rf common/bats
	@echo rm common/cypress/node_modules
	@rm -rf common/cypress/node_modules

clean-gen:
	rm -f $(bats_gen)
	rm -f $(cypress_gen)

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
