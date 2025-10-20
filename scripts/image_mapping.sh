#!/bin/bash
#
# This file defines the IMAGE_MAPPING associative array used to check for image drift.
#
# Format: ["<./helmfile.d/lists/images.yaml_group>.<image_name>"] = "<chart_name>;<upstream_values_path>;<flag>"
#
# <flag>:
#       0 = Compare tag from upstream values.yaml
#       1 = Compare tag from upstream values.yaml AND assume local is mirror (tag only matters)
#       2 = Use Chart.yaml AppVersion as tag (for charts with tag: "")
#       3 = Use Chart.yaml AppVersion as tag AND assume local is mirror (compare tag only)

declare -A IMAGE_MAPPING
IMAGE_MAPPING=(
  # --- Dex ---
  ["dex.image"]="dexidp/dex;.image.tag;3"

  # --- ExternalDNS ---
  ["externalDns.image"]="kubernetes-external-dns/external-dns;.image.tag;3"

  # --- Falco & Sidekick ---
  ["falco.image"]="falcosecurity/falco;.image.tag;3"
  ["falco.falcoctl"]="falcosecurity/falco;.falcoctl.image.tag;1"
  ["falco.driverLoaderInit"]="falcosecurity/falco;.driver.loader.initContainer.image.tag;3"
  ["falco.sidekick"]="falcosecurity/falco/charts/falcosidekick;.image.tag;1"

  # --- Gatekeeper ---
  ["gatekeeper.image"]="open-policy-agent-gatekeeper/gatekeeper;.image.tag;3"
  ["gatekeeper.preInstallCRDs"]="open-policy-agent-gatekeeper/gatekeeper;.postUpgrade.labelNamespace.image.tag;1"
  ["gatekeeper.postInstallLabelNamespace"]="open-policy-agent-gatekeeper/gatekeeper;.postUpgrade.labelNamespace.image.tag;1"

  # --- Harbor (goharbor/harbor) ---
  ["harbor.core"]="goharbor/harbor;.core.image.tag;1"
  ["harbor.database"]="goharbor/harbor;.database.internal.image.tag;1"
  ["harbor.exporter"]="goharbor/harbor;.exporter.image.tag;1"
  ["harbor.jobservice"]="goharbor/harbor;.jobservice.image.tag;1"
  ["harbor.notaryServer"]="goharbor/harbor;.notary.server.image.tag;1"
  ["harbor.notarySigner"]="goharbor/harbor;.notary.signer.image.tag;1"
  ["harbor.portal"]="goharbor/harbor;.portal.image.tag;1"
  ["harbor.redis"]="goharbor/harbor;.redis.image.tag;1"
  ["harbor.registry"]="goharbor/harbor;.registry.registry.image.tag;1"
  ["harbor.registryController"]="goharbor/harbor;.registry.controller.image.tag;1"
  ["harbor.trivyAdapter"]="goharbor/harbor;.trivy.image.tag;1"

  # --- Ingress-NGINX ---
  ["ingressNginx.controller"]="kubernetes-ingress-nginx/ingress-nginx;.controller.image.tag;1"
  ["ingressNginx.admissionWebhooksPatch"]="kubernetes-ingress-nginx/ingress-nginx;.controller.admissionWebhooks.patch.image.tag;1"
  ["ingressNginx.controllerChroot"]="kubernetes-ingress-nginx/ingress-nginx;.controller.image.tag;1"
  ["ingressNginx.defaultBackend"]="kubernetes-ingress-nginx/ingress-nginx;.defaultBackend.image.tag;1"

  # --- Monitoring Stack ---
  ["monitoring.prometheusOperator"]="prometheus-community/kube-prometheus-stack;.prometheusOperator.image.tag;3"
  ["monitoring.configReloader"]="prometheus-community/kube-prometheus-stack;.prometheusOperator.prometheusConfigReloader.image.tag;3"
  ["monitoring.prometheus"]="prometheus-community/kube-prometheus-stack;.prometheus.prometheusSpec.image.tag;1"
  ["monitoring.nodeExporter"]="prometheus-community/kube-prometheus-stack/charts/prometheus-node-exporter;.image.tag;3"
  ["monitoring.kubeStateMetrics"]="prometheus-community/kube-prometheus-stack/charts/kube-state-metrics;.image.tag;3"
  ["monitoring.grafana"]="grafana/grafana;.image.tag;3"
  ["monitoring.grafanaSidecar"]="grafana/grafana;.sidecar.image.tag;1"
  ["monitoring.blackboxExporter"]="prometheus-community/prometheus-blackbox-exporter;.image.tag;3"
  ["monitoring.metricsServer"]="kubernetes-metrics-server/metrics-server;.image.tag;3"
  ["monitoring.alertmanager"]="prometheus-community/kube-prometheus-stack;.alertmanager.alertmanagerSpec.image.tag;1"
  ["monitoring.trivyOperator"]="aquasecurity/trivy-operator;.image.tag;3"

  # --- OpenSearch ---
  ["opensearch.image"]="opensearch-project/opensearch;.image.tag;3"
  ["opensearch.dashboards"]="opensearch-project/opensearch-dashboards;.image.tag;3"
  ["opensearch.exporter"]="prometheus-community/prometheus-elasticsearch-exporter;.image.tag;3"

  # --- Velero ---
  ["velero.image"]="vmware-tanzu/velero;.image.tag;1"

  # --- Cert-Manager---
  ["certManager.controller"]="jetstack/cert-manager;.image.tag;3"
  ["certManager.cainjector"]="jetstack/cert-manager;.cainjector.image.tag;3"
  ["certManager.webhook"]="jetstack/cert-manager;.webhook.image.tag;3"
  ["certManager.startupApiCheck"]="jetstack/cert-manager;.startupapicheck.image.tag;3"

  # --- Kured ---
  ["kured.image"]="kubereboot/kured;.image.tag;3"

  # --- Kyverno ---
  ["kyverno.main"]="kyverno/kyverno;.image.tag;3"
  ["kyverno.init"]="kyverno/kyverno;.initContainer.image.tag;3"
)
