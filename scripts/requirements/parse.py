#!/usr/bin/env python3

import json
from pathlib import Path

from packageurl import PackageURL

purls = {}

with (Path(__file__).parent / "../../REQUIREMENTS").open() as file:
  for line in file:
    purl = PackageURL.from_string(line)
    name = purl.name
    # Workaround for golang PURLs
    # See: https://github.com/package-url/purl-spec/issues/63
    if purl.type == "golang":
      name = f"{purl.namespace}/{purl.name}"
    purls[name] = purl.to_dict()

print(json.dumps(purls))
