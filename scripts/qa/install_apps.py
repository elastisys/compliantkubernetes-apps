#!/usr/bin/env python3
"""
Configure and install Apps for QA.
"""
import argparse
import ipaddress
import json
import os
import sys
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, TypedDict, cast, Optional

SCRIPT_DIR: Path = Path(__file__).parent.absolute()
sys.path.insert(0, SCRIPT_DIR.as_posix())

from boilerplate import STEP_ARGS, AppsConfig, StepArgs, _get_json, _run, _set_secret_key, _step

BIN_DIR: Path = SCRIPT_DIR / ".." / ".." / "bin"

ADMIN_USERS: list[str] = ["admin@example.com", "dev@example.com"]
ADMIN_GROUP: str = "ck8sdevops@elastisys.com"
ALL_IPS: dict[str, list[str]] = {"ips": ["0.0.0.0/0"]}

DEV_DOMAIN: str = "dev-ck8s.com"
DEV_HOSTED_ZONE: str = "Z1001117397DAU71G3RN2"


@dataclass(frozen=True)
class Args:
    """Holds the parsed arguments"""

    secrets: "Secrets"

    cloud_provider: str
    environment_name: str
    sc_subnet: Optional[str] = None
    wc_subnet: Optional[str] = None

    @property
    def domain(self) -> str:
        return f"{self.environment_name}.{DEV_DOMAIN}"


S3Secrets = TypedDict(
    "S3Secrets",
    {"accessKey": str, "secretKey": str},
)

SwiftSecrets = TypedDict(
    "SwiftSecrets",
    {"applicationCredentialID": str, "applicationCredentialSecret": str},
)

StorageSecrets = TypedDict(
    "StorageSecrets",
    {"s3": S3Secrets, "swift": SwiftSecrets},
)


class Secrets(TypedDict):
    """Holds secrets"""

    kubeloginClientSecret: str
    awsAccessKey: str
    awsSecretKey: str
    gcpClientID: str
    gcpClientSecret: str
    objectStorage: StorageSecrets


def initialize_apps() -> None:
    """Initialize apps"""
    _run_ck8s("init", "both")


def set_objectstorage_secrets(secrets_path: Path, secrets: StorageSecrets) -> None:
    """Set objectstorage secrets"""
    _set_secret_key(secrets_path, '["objectStorage"]', dict(secrets))


def update_ips(cluster: str) -> None:
    """Update IPs"""
    _run_ck8s("update-ips", cluster, "apply")


def configure_apps(
    common_config: AppsConfig, sc_config: AppsConfig, wc_config: AppsConfig, args: Args
) -> None:
    """Configure apps"""

    opensearch_cfg = cast(dict, sc_config.get("opensearch"))

    # Set domains
    common_config.set(
        "global",
        {"baseDomain": args.domain, "opsDomain": f"ops.{args.domain}"},
    )

    # Configure cluster issuers
    dns_solver = {
        "selector": {"dnsZones": [DEV_DOMAIN]},
        "dns01": {
            "route53": {
                "region": "eu-north-1",
                "hostedZoneID": DEV_HOSTED_ZONE,
                "accessKeyID": args.secrets["awsAccessKey"],
                "secretAccessKeySecretRef": {
                    "name": "route53-credentials-secret",
                    "key": "secretKey",
                },
            }
        },
    }
    common_config.set(
        "issuers",
        {
            "letsencrypt": {
                "enabled": True,
                "prod": {
                    "email": "letsencrypt@elastisys.com",
                    "solvers": [dns_solver],
                },
                "staging": {"email": "letsencrypt@elastisys.com"},
            }
        },
    )

    # Configure cluster admin
    common_config.set("clusterAdmin", {"users": [], "groups": [ADMIN_GROUP]})

    # Configure allowed OPA registries
    common_config.set(
        "opa.imageRegistry.URL",
        [
            f"harbor.{args.domain}",
            "quay.io/jetstack/cert-manager-acmesolver",
            "ghcr.io/elastisys/user-demo",
        ],
    )

    # Disable Felix metrics
    common_config.set("networkPlugin.calico.calicoFelixMetrics", {"enabled": False})

    # Open up Network Policies
    common_config.set(
        "networkPolicies",
        {
            "harbor": {"jobservice": ALL_IPS, "trivy": ALL_IPS, "registries": ALL_IPS},
            "opensearch": {"plugins": ALL_IPS},
            "dex": {"connectors": ALL_IPS},
            "coredns": {"externalDns": ALL_IPS},
            "kured": {"notificationSlack": ALL_IPS},
            "falco": {"plugins": ALL_IPS},
            "alertmanager": {"alertReceivers": ALL_IPS},
            "global": {"trivy": ALL_IPS, "wcIngress": ALL_IPS, "scIngress": ALL_IPS},
        },
    )

    if args.sc_subnet is not None:
        sc_config.set(
            "networkPolicies.global",
            {
                "scApiserver": {"ips": [args.sc_subnet]},
                "scNodes": {"ips": [args.sc_subnet]},
            },
        )

    if args.wc_subnet is not None:
        wc_config.set(
            "networkPolicies.global",
            {
                "wcApiserver": {"ips": [args.wc_subnet]},
                "wcNodes": {"ips": [args.wc_subnet]},
            },
        )

    sc_config.set(
        "networkPolicies",
        {"monitoring": {"grafana": {"externalDashboardProvider": ALL_IPS}}},
    )

    # Configure Harbor in SC
    sc_config.set("harbor.oidc", {"adminGroupName": ADMIN_GROUP})
    # sc_config.set("harbor.trivy.persistentVolumeClaim", {"size": "10Gi"})

    # Configure Dex in SC
    sc_config.set(
        "dex",
        {
            "enableStaticLogin": True,
            "google": {"groupSupport": True, "SASecretName": "google-sa"},
        },
    )

    # Configure Grafanas
    grafana_cfg = {
        "trailingDots": False,
        "oidc": {
            "skipRoleSync": True,
            "allowedDomains": ["elastisys.com", "example.com"],
        },
    }
    sc_config.set("grafana.ops", grafana_cfg)
    sc_config.set("grafana.user", grafana_cfg)

    # Configure opensearch user mappings
    all_access_found = False
    for mapping in opensearch_cfg["extraRoleMappings"]:
        if mapping["mapping_name"] == "all_access":
            all_access_found = True
        mapping["definition"]["users"] = ADMIN_USERS

    if not all_access_found:
        opensearch_cfg["extraRoleMappings"].append(
            {
                "mapping_name": "all_access",
                "definition": {"users": ADMIN_USERS},
            }
        )
    sc_config.set("opensearch", opensearch_cfg)

    # Disable OpsGenie heartbeat
    sc_config.set("alerts", {"opsGenieHeartbeat": {"enabled": False}})

    # Configure WC admin users
    wc_config.set(
        "user",
        {
            "namespaces": ["production", "staging"],
            "adminUsers": ADMIN_USERS,
            "adminGroups": [],
        },
    )


def configure_secrets(secrets_path: Path, args: Args) -> None:
    """Configure secrets"""
    _set_secret_key(
        secrets_path,
        '["dex"]["kubeloginClientSecret"]',
        args.secrets["kubeloginClientSecret"],
    )

    _set_secret_key(
        secrets_path,
        '["issuers"]',
        {"secrets": {"route53-credentials-secret": {"secretKey": args.secrets["awsSecretKey"]}}},
    )
    _set_secret_key(
        secrets_path,
        '["externalDns"]',
        {
            "awsRoute53": {
                "accessKey": args.secrets["awsAccessKey"],
                "secretKey": args.secrets["awsSecretKey"],
            }
        },
    )
    _set_secret_key(
        secrets_path,
        '["dex"]["connectors"][0]',
        {
            "name": "Elastisys",
            "id": "elastisys-google",
            "type": "google",
            "config": {
                "clientID": args.secrets["gcpClientID"],
                "clientSecret": args.secrets["gcpClientSecret"],
                "redirectURI": f"https://dex.{args.domain}/callback",
                "serviceAccountFilePath": "/etc/dex/google/sa.json",
                "adminEmail": "dex-admin-account@elastisys.com",
                "groups": [ADMIN_GROUP],
                "hostedDomains": ["elastisys.com"],
            },
        },
    )

    # Configure the 'dev@example.com' static user
    _set_secret_key(
        secrets_path,
        '["dex"]["extraStaticLogins"][0]',
        {
            "email": "dev@example.com",
            "userID": "08a8684b-db88-4b73-90a9-3cd1661f5467",
            "username": "dev",
            "password": "password",
            "hash": "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W",
        },
    )


def install_ingress(cluster: str) -> str:
    """Install Ingress"""
    # fmt: off
    _run_ck8s(
        "ops", "helmfile", cluster,
        "-l", "app=admin-namespaces",
        "-l", "app=dev-namespaces",
        "-l", "bootstrap=prometheus",
        "-l", "bootstrap=ingress-nginx",
        "sync",
    )
    # fmt: on
    _run_ck8s(
        *f"ops kubectl {cluster} wait -n ingress-nginx "
        r"--for=jsonpath={.metadata.annotations.loadbalancer\.openstack\.org/load-balancer-address}"
        " service/ingress-nginx-controller --timeout=300s".split()
    )
    return _get_ingress_ip(cluster)


def configure_external_dns(
    cluster_config: AppsConfig,
    dns_names: list[str],
    ingress_ip: str,
    args: Args,
) -> None:
    """Configure External DNS"""
    record_common = {"recordTTL": 180, "recordType": "A", "targets": [ingress_ip]}

    dns_config = {
        "enabled": True,
        "txtOwnerId": args.environment_name,
        "txtPrefix": args.environment_name,
        "domains": [DEV_DOMAIN],
        "sources": {"crd": True, "ingress": False, "service": False},
        "endpoints": [{**record_common, "dnsName": dns_name} for dns_name in dns_names],
    }
    cluster_config.set("externalDns", dns_config)


def install_dex() -> None:
    """Install Dex"""
    _run_ck8s("ops", "helmfile", "sc", "-l", "app=admin-namespaces", "sync")
    _run(
        "bash",
        "-c",
        "sops -d ${CK8S_CONFIG_PATH}/dex-google-group-claim/secret/google-sa-secret.yml "
        "| kubectl --kubeconfig ${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml apply -f -",
    )
    # fmt: off
    _run_ck8s(
        "ops", "helmfile", "sc",
        "-l", "app=external-dns",
        "-l", "app=cert-manager",
        "-l", "app=dex",
        "sync",
    )
    _run(
        "timeout", "300",
        "bash", "-c",
        f"while ! {BIN_DIR}/ck8s ops kubectl sc get cert -n dex dex-tls -o name 2>/dev/null;"
        f"do sleep 5; done",
    )
    # fmt: on
    _run_ck8s(
        *"ops kubectl sc wait cert -n dex dex-tls --for condition=Ready=True --timeout 15m".split()
    )


def sync_apps(cluster: str) -> None:
    """Sync apps"""
    _run_ck8s("apply", cluster, "--sync", f"--concurrency={os.cpu_count() or 8}")


def main() -> None:
    """Entrypoint"""
    _check_ck8s_env("CONFIG_PATH", "CLOUD_PROVIDER", "ENVIRONMENT_NAME", "FLAVOR", "K8S_INSTALLER")

    step_args, args = _parse_arguments(
        cloud_provider=os.environ["CK8S_CLOUD_PROVIDER"],
        environment_name=os.environ["CK8S_ENVIRONMENT_NAME"],
    )
    STEP_ARGS.set(step_args)

    config_path = Path(os.environ["CK8S_CONFIG_PATH"])
    common_config = AppsConfig(path=config_path / "common-config.yaml")
    sc_config = AppsConfig(path=config_path / "sc-config.yaml")
    wc_config = AppsConfig(path=config_path / "wc-config.yaml")
    secrets_path = config_path / "secrets.yaml"

    _step(initialize_apps)()
    _step(set_objectstorage_secrets)(secrets_path, args.secrets["objectStorage"])
    _step(configure_apps)(common_config, sc_config, wc_config, args)
    _step(configure_secrets)(secrets_path, args)
    _step(update_ips, doc_suffix="for SC")("sc")
    sc_ingress_ip = _step(install_ingress, doc_suffix="in SC")("sc") or ""
    _step(configure_external_dns, doc_suffix="for SC")(
        sc_config,
        ["*.ops", "dex", "grafana", "harbor", "opensearch"],
        sc_ingress_ip,
        args,
    )
    _step(install_dex)()
    _step(update_ips, doc_suffix="for WC")("wc")
    wc_ingress_ip = _step(install_ingress, doc_suffix="in WC")("wc") or ""
    _step(configure_external_dns, doc_suffix="for WC")(wc_config, ["*"], wc_ingress_ip, args)
    _step(sync_apps, doc_suffix="in SC")("sc")
    _step(sync_apps, doc_suffix="in WC")("wc")


def _check_ck8s_env(*var_names: str) -> None:
    missing_vars = [
        f"CK8S_{var_name}" for var_name in var_names if f"CK8S_{var_name}" not in os.environ
    ]

    if missing_vars:
        print(f"Fatal: {', '.join(missing_vars)} not set.", file=sys.stderr)
        sys.exit(1)


def _parse_arguments(**environment: str) -> tuple[StepArgs, Args]:
    parser = argparse.ArgumentParser(description="Configure and install Apps for QA.")

    parser.add_argument(
        "-c",
        "--config",
        type=argparse.FileType("r"),
        required=True,
        help="secrets configuration file.",
    )
    if environment["cloud_provider"] == "elastx":
        parser.add_argument(
            "--sc-subnet",
            type=_validate_subnet,
            required=False,
            help="subnet for SC nodes.",
        )
        parser.add_argument(
            "--wc-subnet",
            type=_validate_subnet,
            required=False,
            help="subnet for WC nodes.",
        )

    StepArgs.add_parser_args(parser)

    parsed_args = parser.parse_args()

    # we're using pathlib for reading
    parsed_args.config.close()

    args = Args(
        secrets=json.loads(Path(parsed_args.config.name).read_text(encoding="utf-8")),
        **environment,
    )
    if environment["cloud_provider"] == "elastx":
        args = replace(args, sc_subnet=parsed_args.sc_subnet, wc_subnet=parsed_args.wc_subnet)

    return StepArgs.from_parsed_args(parsed_args), args


def _get_ingress_ip(cluster: str) -> str:
    ingress = cast(
        dict,
        _get_ck8s_json(
            *f"ops kubectl {cluster} get -n ingress-nginx"
            " service/ingress-nginx-controller -ojson".split()
        ),
    )
    return ingress["metadata"]["annotations"]["loadbalancer.openstack.org/load-balancer-address"]


def _validate_subnet(subnet: str) -> str:
    try:
        ipaddress.ip_network(subnet)
        return subnet
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"Invalid IP address: {subnet} ({e})")


def _run_ck8s(*args: str, **kwargs: Any) -> None:
    env_arg = os.environ | ({} if STEP_ARGS.get().interactive else {"CK8S_AUTO_APPROVE": "true"})
    _run(str(BIN_DIR / "ck8s"), *args, **kwargs, env=env_arg)


def _get_ck8s_json(*args: str, **kwargs: Any) -> list | dict:
    return _get_json(str(BIN_DIR / "ck8s"), *args, **kwargs) or {}


if __name__ == "__main__":
    main()
