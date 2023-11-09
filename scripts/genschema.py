#!/usr/bin/python3
import io
import yaml

py2jsontype = {
    dict: "object",
    list: "array",
    str: "string",
    int: "integer",
    float: "number",
    bool: "boolean",
}


def convert(o):
    s = {"type": py2jsontype[type(o)]}

    if type(o) is dict:
        s["properties"] = {}
        s["additionalProperties"] = False
        for k in o:
            s["properties"][k] = convert(o[k])
    elif type(o) is list:
        s["prefixItems"] = [convert(v) for v in o]
        s["items"] = {}
        # This requires some postprocessing. If the items are all the same then
        # recursively merge all prefixItems into items. Otherwise they could be
        # turned into items.oneOf[]
    elif type(o) is str:
        s["examples"] = [o]

    return s


def derive_schema(exampleyaml):
    """
    Takes one yaml file and produces a matching schema on stdout
    """
    with io.open(exampleyaml, "r") as f:
        print("# Generated from " + exampleyaml)
        print(yaml.dump(convert(yaml.load(f, yaml.SafeLoader))))


if __name__ == "__main__":
    from sys import argv

    if len(argv) != 2:
        print(derive_schema.__doc__)
        exit(2)

    derive_schema(*argv[1:])
