#!/usr/bin/env python3
"""
Configuration for the installer script.

- When executed prints the config sample.
- When executed with '--minimal' as the only argument prints the minimally viable config.
"""
import json
import sys
from contextlib import suppress
from typing import (
    Any,
    Literal,
    Optional,
    Type,
    TypedDict,
    Union,
    cast,
    get_args,
    get_origin,
    get_type_hints,
)

AwsSecrets = TypedDict(
    "AwsSecrets",
    {"accessKey": str, "secretKey": str},
)

GcpSecrets = TypedDict("GcpSecrets", {"clientID": str, "clientSecret": str})

DexSecrets = TypedDict("DexSecrets", {"gcp": GcpSecrets})

AwsDnsProvider = TypedDict("AwsDnsProvider", {"hostedZone": str, "secrets": AwsSecrets})

DnsProvider = TypedDict("DnsProvider", {"domain": str, "aws": AwsDnsProvider})

ExternalLoadbalancers = TypedDict(
    "ExternalLoadbalancers",
    {
        "scAddress": str,
        "scDomainName": str,
        "scProxyProtocol": bool,
        "wcAddress": str,
        "wcDomainName": str,
        "wcProxyProtocol": bool,
    },
    total=False,
)

SwiftSecrets = TypedDict(
    "SwiftSecrets",
    {"applicationCredentialID": str, "applicationCredentialSecret": str},
)

ObjectStorageSecrets = TypedDict(
    "ObjectStorageSecrets", {"s3": AwsSecrets, "swift": Optional[SwiftSecrets]}
)

S3Config = TypedDict("S3Config", {"region": str, "regionEndpoint": str})

ObjectStorageConfig = TypedDict("ObjectStorageConfig", {"s3": S3Config})

ObjectStorage = TypedDict(
    "ObjectStorage",
    {"config": Optional[ObjectStorageConfig], "secrets": ObjectStorageSecrets},
)

Subnets = TypedDict(
    "Subnets",
    {"apiServer": list[str], "nodes": list[str], "ingress": list[str]},
    total=False,
)

NetworkPlugin = Literal["calico", "cilium"]


class Config(TypedDict):
    """Holds the parsed configuration"""

    kubeloginClientSecret: str
    adminGroup: str
    dex: DexSecrets
    dnsProvider: DnsProvider

    externalLoadbalancers: Optional[ExternalLoadbalancers]
    objectStorage: ObjectStorage

    wcSubnets: Optional[Subnets]
    scSubnets: Optional[Subnets]

    networkPlugin: Optional[NetworkPlugin]


def dig(config: Config, path: str) -> str | int | float | bool | list | dict | None:
    """Dig a dotted expression out of the config"""
    cur = cast(dict, config)
    with suppress(KeyError):
        for sub_key in path.split("."):
            cur = cur[sub_key]
        return cur
    return None


def _instantiate_typeddict(
    typed_dict_class: Type, default_str: str = "set-me", maximal: bool = False
) -> dict:
    """
    Instantiate a TypedDict class, filling all str leaf values with default_str.
    """

    def get_non_none_types(f_type: Type) -> list[Type]:
        args = get_args(f_type)
        return [arg for arg in args if arg is not type(None)]

    def get_default_value(f_type: Type) -> Any:
        """Recursively determine the default value for a given type."""

        # Handle Union types (including Optional which is Union[T, None])
        origin = get_origin(f_type)
        if origin is Union:
            # For Optional types, use the non-None type
            non_none_types = get_non_none_types(f_type)
            return get_default_value(non_none_types[0]) if non_none_types else None

        # Handle basic types
        if f_type is str:
            return default_str
        if f_type is int:
            return 0
        if f_type is float:
            return 0.0
        if f_type is bool:
            return False
        if f_type is list or origin is list:
            non_none_types = get_non_none_types(f_type)
            return [get_default_value(non_none_types[0])] if non_none_types else []
        if f_type is dict or origin is dict:
            return {}

        # Handle TypedDict types
        if hasattr(f_type, "__annotations__") and hasattr(f_type, "__total__"):
            return (
                _instantiate_typeddict(f_type, default_str, maximal)
                if getattr(f_type, "__total__", True) or maximal
                else {}
            )

        # Handle generic types like List[str], Dict[str, int], etc.
        if origin is not None:
            if origin is list:
                return []
            if origin is dict:
                return {}
            if origin is set:
                return set()
            if origin is tuple:
                return ()
            if origin is Literal:
                non_none_types = get_non_none_types(f_type)
                return get_default_value(type(non_none_types[0])) if non_none_types else None

        # Default fallback
        return None

    # Get type hints for the TypedDict
    type_hints = get_type_hints(typed_dict_class)

    # Create instance with default values
    instance = {}
    for field_name, field_type in type_hints.items():
        if type(None) not in get_args(field_type) or maximal:
            instance[field_name] = get_default_value(field_type)

    return instance


if __name__ == "__main__":
    # Print maximal config unless "--minimal" is passed
    print(
        json.dumps(
            _instantiate_typeddict(Config, maximal="--minimal" not in " ".join(sys.argv[1:])),
            indent=2,
        )
    )
