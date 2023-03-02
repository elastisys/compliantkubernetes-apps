#!/usr/bin/env python3
"""
Helper script to generate Software Bill of Materials (BOM).

Usage:
    git clone -b $RELEASE git@github.com:elastisys/compliantkubernetes-apps
    cd compliantkubernetes-apps
    ./scripts/bom/get-bom.py

Input:
    Helm Charts in ./helmfile/upstream

Output:
    CSV-like file

Limitations:
    - Does not look at Ansible `get-requirements.yaml`
    - Does not extract licenses
    - Does not extract copyright owner
    - Does not extract CNCF status
"""

import csv
import logging
import os
import re

import requests
import yaml

def parse_chart_yaml(file):
    with open(file) as f:
        try:
            chart = yaml.safe_load(f)

            name = chart["name"]
            version = chart["version"]
            appVersion = chart["appVersion"]
            sources = chart.get("sources")
            home = chart.get("home")

            if chart == 'opensearch' and not sources:
                sources = ['https://github.com/opensearch-project/OpenSearch']

            return name, appVersion, version
        except Exception as e:
            logging.error(f'Cannot parse {file}: {e}')

components = [ ]
for root, dirs, filenames in os.walk('./helmfile/upstream'):
    for filename in filenames:
        file = os.path.join(root, filename)
        if filename == 'Chart.yaml':
            components.append(parse_chart_yaml(file))

print('name', 'appVersion', 'version', sep=',')
for component in sorted(components):
    print(*component, sep=',')
