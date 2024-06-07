#!/usr/bin/env make

dirs := unit regression integration end-to-end

# Skip looking up files when building
ifndef CK8S_TESTS_BUILD

# Cypress tests
cypress_suites = $(foreach dir,$(dirs),$(wildcard $(dir)/*.cy.js))
cypress_gen = $(cypress_suites:.cy.js=.gen.bats)

# Template tests
template_suites = $(foreach dir,$(dirs),$(shell find $(dir) -type f -name *.bats.gotmpl))
template_gen = $(template_suites:.bats.gotmpl=.gen.bats)

endif

uid := $(shell id -u)
gid := $(shell id -g)

found_docker := $(shell command -v docker 2>/dev/null)
found_podman := $(shell command -v podman 2>/dev/null)

ifdef found_docker
# Check if podman shadows docker
found_podman := $(shell docker version | grep Podman)
ifdef found_podman
undefine found_docker
else
endif
endif

container_image := compliantkubernetes-apps-tests

ifndef GNUPGHOME
GNUPGHOME := ${HOME}/.gnupg
endif

ifndef CI
container_args += --interactive --tty
endif

container_args += --rm --user $(uid):$(gid) --env=ROOT/apps

ifdef CK8S_CONFIG_PATH
container_args += --env=CK8S_CONFIG_PATH=${CK8S_CONFIG_PATH}
container_args += --mount type=bind,source=${CK8S_CONFIG_PATH},target=${CK8S_CONFIG_PATH}
endif

ifndef CK8S_TESTS_STATIC # Skip mount with static tests
container_args += --mount type=bind,source=${GNUPGHOME},target=/home/ubuntu/.gnupg,readonly
container_args += --mount type=bind,source=${HOME}/.kube/cache/oidc-login,target=/home/ubuntu/.kube/cache/oidc-login
container_args += --mount type=bind,source=/run/user/$(uid),target=/run/user/$(uid),readonly
endif

container_args += --network=host

found_apt := $(shell command -v apt 2>/dev/null)

found_bats := $(shell command -v bats 2>/dev/null)
found_npm := $(shell command -v npm 2>/dev/null)

all := $(cypress_gen) $(template_gen)

nproc := $(shell nproc)

all: $(all) | dep
	@echo --- bats all
	@bats -j $(nproc) -r unit regression integration end-to-end

run-unit: $(filter unit/%,$(all)) | dep-bats
	@echo --- bats unit
	@bats -j $(nproc) -r unit

run-regression: $(filter regression/%,$(all)) | dep
	@echo --- bats regression
	@bats -j $(nproc) -r regression

run-integration: $(filter integration/%,$(all)) | dep
	@echo --- bats integration
	@bats -j $(nproc) -r integration

run-end-to-end: $(filter end-to-end/%,$(all)) | dep
	@echo --- bats end-to-end
	@bats -r end-to-end

run-all-%: $(all) | dep
	@echo --- bats all $*
	@bats -j $(nproc) -r unit regression integration end-to-end --filter-tags $*

run-unit-%: $(filter unit/%,$(all)) | dep-bats
	@echo --- bats unit $*
	@bats -j $(nproc) -r unit --filter-tags $*

run-regression-%: $(filter regression/%,$(all)) | dep
	@echo --- bats unit $*
	@bats -j $(nproc) -r regression --filter-tags $*

run-integration-%: $(filter integration/%,$(all)) | dep
	@echo --- bats unit $*
	@bats -j $(nproc) -r integration --filter-tags $*

run-end-to-end-%: $(filter end-to-end/%,$(all)) | dep
	@echo --- bats unit $*
	@bats -r end-to-end --filter-tags $*

$(all:.bats=): %: %.bats
	@echo --- bats $*.bats
	@bats -j $(nproc) -r $*.bats

check-bats:
ifndef found_bats
ifdef found_apt
	@echo "missing dependency: bats - install it using 'sudo apt install bats'"
else
	@echo "missing dependency: bats - install it using your method of choice"
endif
	@exit 1
endif

check-npm:
ifndef found_npm
ifdef found_apt
	@echo "missing dependency: npm - install it using 'sudo apt install npm'"
else
	@echo "missing dependency: npm - install it using your method of choice"
endif
	@exit 1
endif

dep: dep-bats dep-docs dep-npm
dep-bats: check-bats common/bats/assert common/bats/detik common/bats/file common/bats/mock common/bats/support
dep-docs: common/docs
dep-npm: check-npm node_modules

common/bats/assert:
	@echo --- git clone github.com/bats-core/bats-assert
	@git clone --depth 1 https://github.com/bats-core/bats-assert.git common/bats/assert
	@echo

common/bats/detik:
	@echo --- git clone github.com/bats-core/bats-detik
	@git clone --depth 1 https://github.com/bats-core/bats-detik.git common/bats/detik
	@echo

common/bats/file:
	@echo --- git clone github.com/bats-core/bats-file
	@git clone --depth 1 https://github.com/bats-core/bats-file.git common/bats/file
	@echo

common/bats/mock:
	@echo --- git clone github.com/grayhemp/bats-mock
	@git clone --depth 1 https://github.com/grayhemp/bats-mock.git common/bats/mock
	@echo

common/bats/support:
	@echo --- git clone github.com/bats-core/bats-support
	@git clone --depth 1 https://github.com/bats-core/bats-support.git common/bats/support
	@echo

common/docs:
	@echo --- git clone github.com/elastisys/compliantkubernetes
	@git clone --depth 1 https://github.com/elastisys/compliantkubernetes.git common/docs
	@echo

node_modules:
	@echo --- npm install
	@npm install --save-dev
	@echo

gen: gen-template gen-cypress

gen-cypress: $(cypress_gen)

gen-template: $(template_gen)

$(cypress_gen): %.gen.bats: %.cy.js common/gen.bash
	@./common/gen.bash cypress tests/$<

$(template_gen): %.gen.bats: %.bats.gotmpl common/gen.bash
	@./common/gen.bash template tests/$<

clean: clean-dep clean-gen

clean-dep:
	@echo rm common/bats
	@rm -rf common/bats
	@echo rm common/docs
	@rm -rf common/docs
	@echo rm node_modules
	@rm -rf node_modules

clean-gen:
	@echo rm $(foreach dir, $(dirs), $(dir)/*.gen.bats)
	@rm $(foreach dir, $(dirs), $(shell find $(dir) -type f -name *.gen.bats))

build: build-main

build-main build-unit: build-%:
ifdef found_docker
	docker build --build-arg=UID=$(uid) --build-arg=GID=$(gid) --file Dockerfile --target $* --tag $(container_image):$* ../
else ifdef found_podman
	podman build --build-arg=UID=$(uid) --build-arg=GID=$(gid) --file Dockerfile --target $* --tag $(container_image):$* ../
else
	@echo "error: no container engine found to build the tests image!" >&2 && exit 1
endif

ctr-%:
ifdef found_docker
	docker run $(container_args) $(container_image):main make $*
else ifdef found_podman
	podman run --userns=keep-id $(container_args) $(container_image):main make $*
else
	@echo "error: no container engine found to run the tests image!" >&2 && exit 1
endif

ctr-run-unit-%:
ifdef found_docker
	docker run $(container_args) $(container_image):unit make run-unit-$*
else ifdef found_podman
	podman run --userns=keep-id $(container_args) $(container_image):unit make run-unit-$*
else
	@echo "error: no container engine found to run the tests image!" >&2 && exit 1
endif

print-%:
	@echo $($*)
