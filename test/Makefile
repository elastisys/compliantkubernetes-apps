dirs := unit regression integration end-to-end

bats_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.bats))

cypress_suites := $(foreach dir, $(dirs), $(wildcard $(dir)/*.cy.js))
cypress_gen := $(cypress_suites:.cy.js=.gen.bats)

run-all: $(bats_suites) $(cypress_gen) | dep
	@echo --- bats all
	@bats -r unit regression integration end-to-end

run-unit: $(filter unit/%, $(bats_suites)) $(filter unit/%, $(cypress_gen)) | dep
	@echo --- bats unit
	@bats -r unit
run-regression: $(filter regression/%, $(bats_suites)) $(filter regression/%, $(cypress_gen)) | dep
	@echo --- bats regression
	@bats -r regression
run-integration: $(filter integration/%, $(bats_suites)) $(filter integration/%, $(cypress_gen)) | dep
	@echo --- bats integration
	@bats -r integration
run-end-to-end: $(filter end-to-end/%, $(bats_suites)) $(filter end-to-end/%, $(cypress_gen)) | dep
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

gen: gen-cypress

gen-cypress: $(cypress_gen)

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
	rm -f $(cypress_gen)
