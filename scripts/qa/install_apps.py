#!/usr/bin/env python3
"""
Configure and install Apps for QA.
"""
import argparse
import json
import os
import sys
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path
from typing import Any, cast

SCRIPT_DIR: Path = Path(__file__).parent.absolute()
sys.path.insert(0, SCRIPT_DIR.as_posix())

from boilerplate import STEP_ARGS, AppsConfig, StepArgs, _get_json, _run, _set_secret_key, _step

from config import Config, dig

BIN_DIR: Path = SCRIPT_DIR / ".." / ".." / "bin"
TESTS_DIR: Path = SCRIPT_DIR / ".." / ".." / "tests"

ADMIN_USER: str = "admin@example.com"
APP_DEV_USER: str = "dev@example.com"

ALL_USERS: list[str] = [ADMIN_USER, APP_DEV_USER]
ALL_IPS: dict[str, list[str]] = {"ips": ["0.0.0.0/0"]}


@dataclass(frozen=True)
class Args:
    """Holds the parsed arguments"""

    config: Config

    cloud_provider: str
    environment_name: str

    use_sync: bool

    @property
    def domain(self) -> str:
        return f"{self.environment_name}.{self.config['dnsProvider']['domain']}"


def configure_apps(
    common_config: AppsConfig, sc_config: AppsConfig, wc_config: AppsConfig, args: Args
) -> None:
    """Configure apps"""

    # Configure network plugin
    if (network_plugin := args.config.get("networkPlugin")) is not None:
        common_config.set("networkPlugin.type", network_plugin, merge=False)

    # Configure platform administrators
    common_config.set("clusterAdmin", {"users": [], "groups": [args.config["adminGroup"]]})

    # Configure application developers
    wc_config.set(
        "user",
        {
            "namespaces": ["production", "staging"],
            "adminUsers": ALL_USERS,
            "adminGroups": [],
        },
    )

    # Configure domains
    common_config.set(
        "global",
        {"baseDomain": args.domain, "opsDomain": f"ops.{args.domain}"},
    )

    # Configure external loadbalancer
    if (cond := dig(args.config, "externalLoadBalancers.scProxyProtocol")) is not None:
        sc_config.set("ingressNginx.controller.config", {"useProxyProtocol": cond})

    if (cond := dig(args.config, "externalLoadBalancers.wcProxyProtocol")) is not None:
        wc_config.set("ingressNginx.controller.config", {"useProxyProtocol": cond})

    # Configure object storage
    if (object_storage_config := dig(args.config, "objectStorage.config")) is not None:
        common_config.set("objectStorage", cast(dict, object_storage_config))

    # Configure cluster issuers
    dns_solver = {
        "selector": {"dnsZones": [args.config["dnsProvider"]["domain"]]},
        "dns01": {
            "route53": {
                "region": "eu-north-1",
                "hostedZoneID": args.config["dnsProvider"]["aws"]["hostedZone"],
                "accessKeyID": args.config["dnsProvider"]["aws"]["secrets"]["accessKey"],
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

    # Configure OPA allowed registries
    common_config.set(
        "opa.imageRegistry.URL",
        [
            f"harbor.{args.domain}",
            "quay.io/jetstack/cert-manager-acmesolver",
            "ghcr.io/elastisys/user-demo",
        ],
    )

    # Configure Dex Google group support and static login
    sc_config.set(
        "dex",
        {
            "enableStaticLogin": True,
            "google": {"groupSupport": True, "SASecretName": "google-sa"},
        },
    )

    # Configure Falco BPF driver
    common_config.set("falco.driver", {"kind": "modern_ebpf"})

    # Configure Grafana with test requirements
    grafana_cfg = {
        "trailingDots": False,
        "oidc": {
            "skipRoleSync": True,
            "allowedDomains": ["elastisys.com", "example.com"],
            "jwtEnabled": True,
        },
    }
    sc_config.set("grafana.ops", grafana_cfg)
    sc_config.set("grafana.user", grafana_cfg)

    # Configure Harbor administrator group
    sc_config.set("harbor.oidc", {"adminGroupName": args.config["adminGroup"]})
    # sc_config.set("harbor.trivy.persistentVolumeClaim", {"size": "10Gi"})

    # Configure OpenSearch role mappings
    opensearch_cfg = cast(dict, sc_config.get("opensearch"))
    all_access_found = False
    for mapping in opensearch_cfg["extraRoleMappings"]:
        if mapping["mapping_name"] == "all_access":
            all_access_found = True
        mapping["definition"]["users"] = ALL_USERS

    if not all_access_found:
        opensearch_cfg["extraRoleMappings"].append(
            {
                "mapping_name": "all_access",
                "definition": {"users": ALL_USERS},
            }
        )
    sc_config.set("opensearch", opensearch_cfg)

    # Disable OpsGenie heartbeat
    sc_config.set("alerts", {"opsGenieHeartbeat": {"enabled": False}})

    # Disable Calico Felix metrics
    common_config.set("networkPlugin.calico.calicoFelixMetrics", {"enabled": False})

    # Open up Network Policies
    common_network_policies = {
        "global": {
            "scIngress": ALL_IPS,
            "wcIngress": ALL_IPS,
            "trivy": ALL_IPS,
            "objectStorage": {**ALL_IPS, "ports": [443]},
            "objectStorageSwift": ALL_IPS,
        },
        "alertmanager": {"alertReceivers": ALL_IPS},
        "coredns": {"externalDns": ALL_IPS},
        "dex": {"connectors": ALL_IPS},
        "falco": {"plugins": ALL_IPS},
        "harbor": {"jobservice": ALL_IPS, "registries": ALL_IPS, "trivy": ALL_IPS},
        "kured": {"notificationSlack": ALL_IPS},
        "opensearch": {"plugins": ALL_IPS},
    }
    if args.cloud_provider in ["openstack", "upcloud"]:
        common_network_policies["kubeSystem"] = {args.cloud_provider: ALL_IPS}

    common_config.set("networkPolicies", common_network_policies)

    sc_config.set("networkPolicies.global", {"scApiserver": ALL_IPS, "scNodes": ALL_IPS})
    wc_config.set("networkPolicies.global", {"wcApiserver": ALL_IPS, "wcNodes": ALL_IPS})

    sc_config.set(
        "networkPolicies",
        {"monitoring": {"grafana": {"externalDashboardProvider": ALL_IPS}}},
    )


def configure_secrets(secrets_path: Path, args: Args) -> None:
    """Configure secrets"""

    # Configure Dex client secret for Kubernetes API
    _set_secret_key(
        secrets_path,
        '["dex"]["kubeloginClientSecret"]',
        args.config["kubeloginClientSecret"],
    )

    # Configure Dex connector to Google
    _set_secret_key(
        secrets_path,
        '["dex"]["connectors"][0]',
        {
            "name": "Elastisys",
            "id": "elastisys-google",
            "type": "google",
            "config": {
                "clientID": args.config["dex"]["gcp"]["clientID"],
                "clientSecret": args.config["dex"]["gcp"]["clientSecret"],
                "redirectURI": f"https://dex.{args.domain}/callback",
                "serviceAccountFilePath": "/etc/dex/google/sa.json",
                "adminEmail": "dex-admin-account@elastisys.com",
                "groups": [args.config["adminGroup"]],
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

    # Configure cert-manager AWS secrets
    _set_secret_key(
        secrets_path,
        '["issuers"]',
        {
            "secrets": {
                "route53-credentials-secret": {
                    "secretKey": args.config["dnsProvider"]["aws"]["secrets"]["secretKey"]
                }
            }
        },
    )

    # Configure ExternalDNS AWS secrets
    _set_secret_key(
        secrets_path,
        '["externalDns"]',
        {"awsRoute53": args.config["dnsProvider"]["aws"]["secrets"]},
    )

    # Configure object storage secrets
    if (object_storage_secrets := dig(args.config, "objectStorage.secrets")) is not None:
        _set_secret_key(secrets_path, '["objectStorage"]', cast(dict, object_storage_secrets))


def install_ingress(cluster: str, args: Args) -> None:
    """Install Ingress"""
    # fmt: off
    _run_ck8s(
        "ops", "helmfile", cluster,
        "-l", "app=ingress-nginx",
        "sync" if args.use_sync else "apply",
        "--include-transitive-needs",
    )
    # fmt: on


def install_external_dns(
    cluster_config: AppsConfig,
    cluster: str,
    dns_names: list[str],
    args: Args,
) -> None:
    """Install External DNS"""

    if (domain_name := dig(args.config, f"externalLoadbalancers.{cluster}DomainName")) is not None:
        record_common = {"recordTTL": 180, "recordType": "CNAME", "targets": [domain_name]}
    else:
        record_common = {
            "recordTTL": 180,
            "recordType": "A",
            "targets": [_get_ingress_ip(args, cluster)],
        }

    dns_config = {
        "enabled": True,
        "txtOwnerId": args.environment_name,
        "txtPrefix": args.environment_name,
        "domains": [args.config["dnsProvider"]["domain"]],
        "sources": {"crd": True, "ingress": False, "service": False},
        "endpoints": [{**record_common, "dnsName": dns_name} for dns_name in dns_names],
    }
    cluster_config.set("externalDns", dns_config)

    # fmt: off
    _run_ck8s(
        "ops", "helmfile", cluster,
        "-l", "app=external-dns",
        "sync" if args.use_sync else "apply", "--include-transitive-needs"
    )


def install_dex(args: Args) -> None:
    """Install Dex"""
    _run_ck8s(
        "ops", "helmfile", "sc", "-l", "app=admin-namespaces", "sync" if args.use_sync else "apply"
    )
    _run(
        "bash",
        "-c",
        "sops -d ${CK8S_CONFIG_PATH}/dex-google-group-claim/secret/google-sa-secret.yml "
        "| kubectl --kubeconfig ${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml apply -f -",
    )
    # fmt: off
    _run_ck8s(
        "ops", "helmfile", "sc",
        "-l", "app=cert-manager",
        "-l", "app=dex",
        "sync" if args.use_sync else "apply", "--include-transitive-needs"
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


def open_network_policies(config: Config) -> None:
    """Open network policies"""
    if config.get("networkPlugin") is None:
        return

    for cluster in ["sc", "wc"]:
        allow_all_policy = (
            f"{TESTS_DIR}/common/network-policies/{config['networkPlugin']}-allow-all.yaml"
        )
        _run_ck8s(*f"ops kubectl {cluster} apply -f {allow_all_policy}".split())


def close_network_policies(config: Config) -> None:
    """Close network policies"""
    if config.get("networkPlugin") is None:
        return

    for cluster in ["sc", "wc"]:
        allow_all_policy = (
            f"{TESTS_DIR}/common/network-policies/{config['networkPlugin']}-allow-all.yaml"
        )
        _run_ck8s(*f"ops kubectl {cluster} delete -f {allow_all_policy}".split())


def reconfigure_ips(
    common_config: AppsConfig, sc_config: AppsConfig, wc_config: AppsConfig, args: Args
) -> None:
    """Reconfigure IPs"""

    common_config.set(
        "networkPolicies",
        {
            "global": {
                "objectStorage": {"ips": [], "ports": []},
                "objectStorageSwift": {"ips": []},
            },
        },
    )

    if (sc_ingress_subnet := dig(args.config, "scSubnets.ingress")) is not None:
        common_config.set(
            "networkPolicies",
            {"global": {"scIngress": {"ips": sc_ingress_subnet}}},
        )

    if (wc_ingress_subnet := dig(args.config, "wcSubnets.ingress")) is not None:
        common_config.set(
            "networkPolicies",
            {"global": {"wcIngress": {"ips": wc_ingress_subnet}}},
        )

    if (sc_subnets := args.config.get("scSubnets")) is not None:
        sc_config.set(
            "networkPolicies.global",
            {
                "scApiserver": {"ips": sc_subnets.get("apiServer") or ["set-me"]},
                "scNodes": {"ips": sc_subnets.get("nodes") or ["set-me"]},
            },
        )

    if (wc_subnets := args.config.get("wcSubnets")) is not None:
        wc_config.set(
            "networkPolicies.global",
            {
                "wcApiserver": {"ips": wc_subnets.get("apiServer") or ["set-me"]},
                "wcNodes": {"ips": wc_subnets.get("nodes") or ["set-me"]},
            },
        )


# Apps commands


def initialize_apps() -> None:
    """Initialize apps"""
    _run_ck8s("init", "both")


def update_ips(cluster: str) -> None:
    """Update IPs"""
    _run_ck8s("update-ips", cluster, "apply")


def apply_apps(cluster: str) -> None:
    """Apply apps"""
    _run_ck8s("apply", cluster, f"--concurrency={os.cpu_count() or 8}")


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
    _step(configure_apps)(common_config, sc_config, wc_config, args)
    _step(configure_secrets)(secrets_path, args)
    _step(open_network_policies)(args.config)
    _step(install_ingress, doc_suffix="in SC")("sc", args)
    _step(install_external_dns, doc_suffix="in SC")(
        sc_config,
        "sc",
        ["*.ops", "dex", "grafana", "harbor", "opensearch"],
        args,
    )
    _step(install_dex)(args)
    _step(install_ingress, doc_suffix="in WC")("wc", args)
    _step(install_external_dns, doc_suffix="in WC")(wc_config, "wc", ["*"], args)
    _step(reconfigure_ips)(common_config, sc_config, wc_config, args)
    _step(update_ips, doc_suffix="for both clusters")("both")
    if args.use_sync:
        _step(sync_apps, doc_suffix="in SC")("sc")
        _step(sync_apps, doc_suffix="in WC")("wc")
    else:
        _step(apply_apps, doc_suffix="in SC")("sc")
        _step(apply_apps, doc_suffix="in WC")("wc")
    _step(close_network_policies)(args.config)


def _parse_arguments(**environment: str) -> tuple[StepArgs, Args]:
    parser = argparse.ArgumentParser(description="Configure and install Apps for QA.")

    parser.add_argument(
        "-c",
        "--config",
        type=argparse.FileType("r"),
        required=True,
        help="secrets configuration file.",
    )
    parser.add_argument(
        "--sync",
        action=argparse.BooleanOptionalAction,
        required=False,
        default=False,
        help="Use sync instead of apply for the application install steps.",
    )

    StepArgs.add_parser_args(parser)

    parsed_args = parser.parse_args()

    # we're using pathlib for reading
    parsed_args.config.close()

    args = Args(
        config=json.loads(Path(parsed_args.config.name).read_text(encoding="utf-8")),
        use_sync=parsed_args.sync,
        **environment,
    )

    return StepArgs.from_parsed_args(parsed_args), args


def _get_ingress_ip(args: Args, cluster: str) -> str:
    if dig(args.config, f"externalLoadbalancers.{cluster}DomainName") is not None:
        return ""
    if (address := dig(args.config, f"externalLoadbalancers.{cluster}Address")) is not None:
        return cast(str, address)

    _run_ck8s(
        *f"ops kubectl {cluster} wait -n ingress-nginx "
        r"--for=jsonpath={.metadata.annotations.loadbalancer\.openstack\.org/load-balancer-address}"
        " service/ingress-nginx-controller --timeout=300s".split()
    )
    ingress = cast(
        dict,
        _get_ck8s_json(
            *f"ops kubectl {cluster} get -n ingress-nginx"
            " service/ingress-nginx-controller -ojson".split()
        ),
    )
    with suppress(KeyError):
        return ingress["metadata"]["annotations"][
            "loadbalancer.openstack.org/load-balancer-address"
        ]
    return ""


def _check_ck8s_env(*var_names: str) -> None:
    missing_vars = [
        f"CK8S_{var_name}" for var_name in var_names if f"CK8S_{var_name}" not in os.environ
    ]

    if missing_vars:
        print(f"Fatal: {', '.join(missing_vars)} not set.", file=sys.stderr)
        sys.exit(1)


def _get_ck8s_json(*args: str, **kwargs: Any) -> list | dict:
    return _get_json(str(BIN_DIR / "ck8s"), *args, **kwargs) or {}


def _run_ck8s(*args: str, **kwargs: Any) -> None:
    env_arg = os.environ | ({} if STEP_ARGS.get().interactive else {"CK8S_AUTO_APPROVE": "true"})
    _run(str(BIN_DIR / "ck8s"), *args, **kwargs, env=env_arg)


if __name__ == "__main__":
    main()
