#!/usr/bin/env python

from collections import defaultdict
import jsonschema
import yaml

#
# Various constants. Could become configuration parameters in the future.
#

INPUT_FILE = 'docs/sbom.yaml'
OUTPUT_FILE = 'docs/sbom.md'
VERSION = 'v0.37.0'


PREAMBLE = f"""
<!--
    !!! DO NOT EDIT !!!

    This file is generated from {INPUT_FILE}.
-->

# Software Bill of Materials @ {VERSION}
"""

SCHEMA = yaml.load("""
type: array
items:
    type: object
    additionalProperties: false
    properties:
        domain:
            enum:
            - Custom Helm Charts
            - Requirements
            - Upstream Helm Charts
            - Container images
        name:
            type: string
        tag:
            type: string
        app_version:
            type: string
        copyright_owner:
            type: string
        cncf_status:
            type: string
        license:
            type: string
        comment:
            type: string
        chart_version:
            type: string
        images:
            type: array
        helm_chart_ref:
            type: array
    requiredProperties:
    - domain
""", Loader=yaml.Loader)

def print_markdown_row(*args, file=None):
    print('| ', end='', file=file)
    print(*args, sep=' | ', end=' |\n', file=file)

def to_markdown_chart_ref(chart_ref):
    """
    Convert a list of helm chart references into a Markdown list.
    """

    return '<br/>'.join(chart_ref)

def main():
    with open(INPUT_FILE, 'r') as file:
        data = yaml.load(file, Loader=yaml.Loader)

    jsonschema.validate(data, SCHEMA)

    entry_by_domain = defaultdict(list)
    for entry in data:
        domain = entry['domain']
        entry_by_domain[domain].append(entry)

    COLUMNS = []

    with open(OUTPUT_FILE, 'w') as file:
        print(PREAMBLE, file=file)
        for domain, entries in entry_by_domain.items():
            print(f'\n## {domain}', end='\n\n', file=file)

            match domain:
                case "Upstream Helm Charts" | "Custom Helm Charts":
                    COLUMNS = [
                        'Name',
                        'App Version',
                        'Chart version',
                        'CNCF Status',
                        'License',
                        'Copyright owner',
                        'Comment',
                    ]
                case "Requirements":
                    COLUMNS = [
                        'Name',
                        'App Version',
                        'CNCF Status',
                        'License',
                        'Copyright owner',
                        'Comment',
                    ]
                case "Container images":
                    COLUMNS = [
                        'Name',
                        'Tag',
                        'Helm Chart',
                        'License',
                        'Copyright Owner',
                        'Comment',
                    ]

            print_markdown_row(*COLUMNS, file=file)
            print_markdown_row(* ['---']*len(COLUMNS), file=file)

            for entry in entries:
                match domain:
                    case "Upstream Helm Charts" | "Custom Helm Charts":
                        print_markdown_row(
                            entry['name'],
                            entry.get('app_version', ''),
                            entry.get('chart_version', ''),
                            entry.get('cncf_status', ''),
                            entry.get('license', ''),
                            entry.get('copyright_owner', ''),
                            entry.get('comment', ''),
                            file=file,
                        )
                    case "Requirements":
                        print_markdown_row(
                            entry['name'],
                            entry.get('app_version', ''),
                            entry.get('cncf_status', ''),
                            entry.get('license', ''),
                            entry.get('copyright_owner', ''),
                            entry.get('comment', ''),
                            file=file,
                        )
                    case "Container images":
                        print_markdown_row(
                            entry['name'],
                            entry.get('tag', ''),
                            to_markdown_chart_ref(entry['helm_chart_ref'] if 'helm_chart_ref' in entry.keys() else ''),
                            entry.get('copyright_owner', ''),
                            entry.get('cncf_status', ''),
                            entry.get('license', ''),
                            entry.get('comment', ''),
                            file=file,
                        )

if __name__ == '__main__':
    main()
