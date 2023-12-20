SHELL=/bin/bash -o pipefail

BIN_DIR ?= $(shell pwd)/tmp/bin

JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
THANOS_MIXIN       ?= thanos-mixin
THANOS_VENDOR_DIR  ?= thanos-mixin/vendor

.PHONY: tools_install
tools_install: $(BIN_DIR)
	echo Installing tools from scripts/tools.go
	mkdir -p $(BIN_DIR)
	cd scripts && go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %

JSONNETFMT_CMD := $(JSONNETFMT_BIN) -n 2 --max-blank-lines 2 --string-style s --comment-style s

.PHONY: jsonnet-format
jsonnet-format: $(JSONNETFMT_BIN)
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_CMD) -i

.PHONY: thanos_install
thanos_install: $(JB_BIN)
	cd ${THANOS_MIXIN} && \
	$(JB_BIN) init && \
	$(JB_BIN) install github.com/thanos-io/thanos/mixin@main && \
	$(JB_BIN) update

.PHONY: thanos_dashboards
thanos_dashboards: $(JSONNET_BIN) ${THANOS_VENDOR_DIR}/mixin/mixin.libsonnet ${THANOS_VENDOR_DIR}/mixin/config.libsonnet ${THANOS_VENDOR_DIR}/mixin/dashboards/*
	rm -rf thanos/*.json
	cp ${THANOS_MIXIN}/config.libsonnet ${THANOS_MIXIN}/dashboards.jsonnet ${THANOS_VENDOR_DIR}/mixin
	$(JSONNET_BIN) -J ${THANOS_VENDOR_DIR} -m thanos/ ${THANOS_VENDOR_DIR}/mixin/dashboards.jsonnet

.PHONY: clean
clean:
	find ${THANOS_MIXIN} -depth -mindepth 1 -name "*" ! -name "config.libsonnet" ! -name "dashboards.jsonnet" -exec rm -rf {} \;
	rm -rf ./tmp

# non-phony targets
$(BIN_DIR):
	mkdir -p $(BIN_DIR)
