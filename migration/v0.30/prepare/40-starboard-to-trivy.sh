#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_move common '.starboard.vulnerabilityScanner.reportTTL' '.starboard.vulnerabilityScanner.scannerReportTTL'
yq_move common .starboard .trivy
yq_remove common .vulnerabilityExporter
yq_remove common .ciskubebenchExporter
yq_move sc '.starboard.vulnerabilityScanner.reportTTL' '.starboard.vulnerabilityScanner.scannerReportTTL'
yq_move sc .starboard .trivy
yq_remove sc .vulnerabilityExporter
yq_remove sc .ciskubebenchExporter
yq_move wc '.starboard.vulnerabilityScanner.reportTTL' '.starboard.vulnerabilityScanner.scannerReportTTL'
yq_move wc .starboard .trivy
yq_remove wc .vulnerabilityExporter
yq_remove sc .ciskubebenchExporter
