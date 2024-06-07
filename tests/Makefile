#!/usr/bin/env make

dirs := unit regression integration end-to-end

container_image := compliantkubernetes-apps-tests

all := $(cypress_gen) $(template_gen)

nproc := $(shell nproc)

# Run without parallelisation
internal-all: $(all)
	@echo --- bats all
	@bats -r unit regression integration end-to-end
internal-all-%: $(all)
	@echo --- bats all $*
	@bats -r unit regression integration end-to-end --filter-tags $*

# Run with parallelisation both across and within files
internal-unit: $(filter unit/%,$(all))
	@echo --- bats unit
	@bats -j $(nproc) -r unit
internal-unit-%: $(filter unit/%,$(all))
	@echo --- bats unit $*
	@bats -j $(nproc) -r unit --filter-tags $*

# Run with parallelisation within files
internal-regression: $(filter regression/%,$(all))
	@echo --- bats regression
	@bats -j $(nproc) --no-parallelize-across-files -r regression
internal-regression-%: $(filter regression/%,$(all))
	@echo --- bats regression $*
	@bats -j $(nproc) --no-parallelize-across-files -r regression --filter-tags $*

# Run with parallelisation within files
internal-integration: $(filter integration/%,$(all))
	@echo --- bats integration
	@bats -j $(nproc) --no-parallelize-across-files -r integration
internal-integration-%: $(filter integration/%,$(all))
	@echo --- bats integration $*
	@bats -j $(nproc) --no-parallelize-across-files -r integration --filter-tags $*

# Run without parallelisation
internal-end-to-end: $(filter end-to-end/%,$(all))
	@echo --- bats end-to-end
	@bats -r end-to-end
internal-end-to-end-%: $(filter end-to-end/%,$(all))
	@echo --- bats end-to-end $*
	@bats -r end-to-end --filter-tags $*

$(all:.bats=): %: %.bats
	@echo --- bats $*.bats
	@bats -r $*.bats

gen: gen-template gen-cypress
gen-cypress: $(cypress_gen)
gen-template: $(template_gen)

$(cypress_gen): %.gen.bats: %.cy.js common/gen.bash
	@./common/gen.bash cypress tests/$<
$(template_gen): %.gen.bats: %.bats.gotmpl common/gen.bash
	@./common/gen.bash template tests/$<

clean: clean-gen
clean-gen:
	@echo rm $(foreach dir, $(dirs), $(dir)/*.gen.bats)
	@rm $(foreach dir, $(dirs), $(shell find $(dir) -type f -name *.gen.bats))

build: build-main
build-main build-unit: build-%:
	docker build --file Dockerfile --target $* --tag $(container_image):$* ../

all:
	FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-all
run-all-%:
	FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-$*
run-end-to-end-%:
	FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-end-to-end-$*
run-end-to-end:
	FORWARD_ENVIRONMENT=true FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-end-to-end
run-integration-%:
	FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-integration-$*
run-integration:
	FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-integration
run-regression-%:
	FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-regression-$*
run-regression:
	FORWARD_RUNTIME=true ../scripts/run-from-container.sh $(container_image):main make -C tests internal-regression
run-unit-%:
	../scripts/run-from-container.sh $(container_image):unit make -C tests internal-unit-$*
run-unit:
	../scripts/run-from-container.sh $(container_image):unit cypress open --project tests/

run-cypress-open:
	../scripts/run-from-container.sh $(container_image):unit

print-%:
	@echo $($*)
