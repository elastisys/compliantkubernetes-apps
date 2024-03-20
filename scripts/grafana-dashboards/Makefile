#!/usr/bin/env make

ROOT_DIR := $(shell dirname $(dir $(realpath $(dir $(firstword $(MAKEFILE_LIST))))))

DASHBOARDS_PATH := $(ROOT_DIR)/helmfile.d/charts/grafana-dashboards/dashboards
TMP_BIN_DIR     := /tmp/bin
CONFIGS         := configs

JB_BIN      := $(TMP_BIN_DIR)/jb
JSONNET_BIN :=$(TMP_BIN_DIR)/jsonnet

define clone_mixin_repo
	echo "Cloning the $(1) repository"
	mkdir -p $(1) && \
	cd $(1) && \
	$(JB_BIN) init && \
	$(JB_BIN) install $(2) && \
	$(JB_BIN) update
endef

define create_dashboards
	echo "Create dashboards in $(DASHBOARDS_PATH)/$(1)"
	rm -rf $(DASHBOARDS_PATH)/$(1)/*.json
	$(JSONNET_BIN) -J $(1)/vendor -m $(DASHBOARDS_PATH)/$(1)/ $(CONFIGS)/$(1)/dashboards.jsonnet
endef

default: help

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

dep: # Download the jsonnet dependencies
	echo "Installing the necessary dependencies"
	mkdir -p $(TMP_BIN_DIR) && \
	export GOBIN=$(TMP_BIN_DIR) && \
	go install github.com/google/go-jsonnet/cmd/jsonnet@latest && \
	go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest && \
	go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

thanos-mixin: # Clone the thanos-mixin repo and build the dashboards
	@$(call clone_mixin_repo,$@,"github.com/thanos-io/thanos/mixin@main")
	@$(call create_dashboards,$@)

etcd-mixin: # Clone the etcd-mixin repo and build the dashboards
	@$(call clone_mixin_repo,$@,"github.com/etcd-io/etcd/contrib/mixin@main")
	@$(call create_dashboards,$@)

kubernetes-mixin: # Clone the kubernetes-mixin repo and build the dashboards
	@$(call clone_mixin_repo,$@,"github.com/kubernetes-monitoring/kubernetes-mixin@master")
	@$(call create_dashboards,$@)

prometheus-mixin: # Clone the prometheus-mixin repo and build the dashboards
	@$(call clone_mixin_repo,$@,"github.com/prometheus/prometheus/documentation/prometheus-mixin@main")
	@$(call create_dashboards,$@)

alertmanager-mixin: # Clone the alertmanager-mixin repo and build the dashboards
	@$(call clone_mixin_repo,$@,"github.com/prometheus/alertmanager/doc/alertmanager-mixin@main")
	@$(call create_dashboards,$@)

#node-mixin: # Clone the node-exporter-mixin and build the dashboards - not working
#	@$(call clone_mixin_repo,$@,"github.com/prometheus/node_exporter/docs/node-mixin@master")
#	@$(call create_dashboards,$@)

grafana-dashboards: # Get the Grafana dashboard from upstream
	curl -o $(DASHBOARDS_PATH)/grafana/grafana-overview-dashboard.json -L https://raw.githubusercontent.com/grafana/grafana/main/grafana-mixin/dashboards/grafana-overview.json

coredns-dashboards: # Get the CoreDNS dashboard from kube-prometheus-stack repo
	curl -o $(DASHBOARDS_PATH)/coredns/k8s-coredns-dashboard.json -L https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/files/dashboards/k8s-coredns.json

clean: # Clean the mixin folders
	@grep -Po '^[a-z]+[-].*(?=:)' Makefile | while read -r l; do if [ -d $$l ]; then rm -rf $$l; fi; done
