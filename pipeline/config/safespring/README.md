# pipeline-safespring

## Where

- **CityCloud Kna1**
- **CityCloud Fra1**
- **CityCloud CompliantCloud**
- **Safespring**
- **ElastX**
- **Exoscale**
- **UpCloud \<de-fra1|es-mad1|fi-hel2|nl-ams1|pl-waw1|uk-lon1\>**

## What

- [compliantkubernetes-kubespray@v2.20.0-ck8s5](https://github.com/elastisys/compliantkubernetes-kubespray/tree/v2.20.0-ck8s5)
- [compliantkubernetes-apps@v0.29.0](https://github.com/elastisys/compliantkubernetes-apps/tree/v0.29.0)
- [postgresql@v1.7.1-ck8s6](https://github.com/elastisys/compliantkubernetes-postgresql/tree/v1.7.1-ck8s6)
- [redis@v1.1.1-ck8s4](https://github.com/elastisys/compliantkubernetes-redis/tree/v1.1.1-ck8s4)
- [rabbitmq@v3.10.7-ck8s2](https://github.com/elastisys/compliantkubernetes-rabbitmq/tree/v3.10.7-ck8s2)
- [argocd@v2.4.20-ck8s1](https://github.com/elastisys/ck8s-argocd/tree/v2.4.20-ck8s1)
- [jaeger@v1.39.0-ck8s1](https://github.com/elastisys/ck8s-jaeger/tree/v1.39.0-ck8s1)

## TODO

Please read the [instructions](https://github.com/elastisys/ck8s-ops/blob/main/docs/ops-manual/TODO-instructions-doc.md) before creating an item.

### Next Maintenance Window

<details>
<summary>E.g. Create dedicated nodes for postgres</summary>

- **Pre-requisite**: Please fill the pre-requisite Ex- ToS etc
- **Estimated time**: Time durations to implement the tasks
- **Estimated Downtime**: Information about the related downtime
- **Description of Tasks**: Description of tasks
- **Instructions to perform tasks**: Set of instructions how to implement the tasks
      - - Docs / operator logs etc ?
- **Note**: Important note

</details>

### Medium

### Low

## Openstack access

> **_WARNING:_** user your own/admin credentials when running terraform.

```console
source ${CK8S_CONFIG_PATH}/openrc.sh
source <(sops -d ${CK8S_CONFIG_PATH}/secret/openstack-app-credentials-for-kubespray.sh)
```

## DNS

Do we own the domain?

- [ ] yes
- [ ] no

To modify DNS records edit `dns.json` and run:

```console
aws route53 change-resource-record-sets --hosted-zone-id xyz --change-batch file://dns.json
```

## Postgres

We've installed the postgres-operator in the cluster.
Installation instructions for the operator are found under `postgresql/`.

## Redis

We've installed the redis-operator in the cluster.
Installation instructions for the operator are found under `redis/`.

## RabbitMQ

We've installed rabbitmq in the cluster.
Installation instructions for the operator are found under `rabbitmq/`.

## Jaeger

We've installed jaeger in the cluster.
Installation instructions for the operator are found under `jaeger/`.

## ArgoCD

We've installed ArgoCD in the cluster.
Installation instructions for the operator are found under `argocd/`.
