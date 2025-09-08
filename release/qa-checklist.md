# Quality Assurance Checklist

Elastisys Welkin® Apps

## Checklist

> [!note]
> This document is maintained as a reference for the quality assurance checklist for Welkin Apps.
> The actual release and quality assurance process is driven by an internal issue template, as it also ties together with internal processes, however these are templated from the same source so the main steps are accurate.

### Overview

**Sections**:

- [Before QA steps](#before-qa-steps)
- [Install QA steps](#install-qa-steps)
- [Upgrade QA steps](#upgrade-qa-steps)
- [After QA steps](#after-qa-steps)
- [Release steps](#release-steps)
- [Final steps](#final-steps)

### Before QA steps

> [!note]
> Whenever you need to change access from platform administrator to application developer `admin@example.com` prefer to re-login rather than impersonation `--as=admin@example.com`.
> For this you have two options:
>
> - Either set a different cache directory `export KUBECACHEDIR=${HOME}/.kube-static/cache` when switching to application developer and restore `unset KUBECACHEDIR` when switching to platform administrator.
> - Or clear the cache `rm -r ~/.kube/cache/oidc-login` whenever you switch between.

- [ ] Ensure the release follows [the release constraints](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#constraints)
- [ ] Complete [the feature freeze step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#feature-freeze)
- [ ] Complete [the staging step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#staging)

### Install QA steps

> _Apps install scenario_

#### Environment setup

**Provider**:

- [ ] Azure (alpha)
- [ ] Elastx (prod)
- [ ] Safespring (prod)
- [ ] UpCloud (prod)

**Installer**:

- [ ] Cluster API (beta)
- [ ] Kubespray (prod)

**Network Plugin**:

- [ ] Calico (prod)
- [ ] Cilium (alpha)

**Configuration**:

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
    <details><summary>Commands</summary>

    ```bash
    # configure
    yq -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    yq -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply
    ./bin/ck8s apply sc
    ./bin/ck8s apply wc
    ```

    </details>
- [ ] Grafana trailing dots - Disabled
    <details><summary>Commands</summary>

    ```sh
    yq -i '.grafana.user.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply
    ./bin/ck8s ops helmfile sc -lapp=grafana diff
    ./bin/ck8s ops helmfile sc -lapp=grafana apply
    ```

    </details>
- [ ] Rclone sync - Enabled and preferably configured to a different infrastructure provider.
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace (this cannot be a subnamespace)
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Status tests

> [!note]
> As platform administrator

- [ ] Check that the deployment is idempotent

    ```bash
    ./bin/ck8s dry-run sc
    # should not report any changes

    ./bin/ck8s dry-run wc
    # should not report any changes
    ```

    If changes are reported, apply once and try again, if changes are still reported then there is an issue that must be fixed.

- [ ] Successful `./bin/ck8s test sc|wc`
- [ ] If possible let the environment stabilise into a steady state after the install
    - Best is to perform the install at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.

#### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `make build-main` from the `tests/` directory
- [ ] Successful `make run-end-to-end` from the `tests/` directory

#### Kubernetes access

> [!note]
> As platform administrator

- [ ] Can login as platform administrator via Dex with IdP

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer `admin@example.com` via Dex with static user
- [ ] Can list access

    ```bash
    kubectl -n "${NAMESPACE}" auth can-i --list
    ```

- [ ] Can delegate admin access

    ```console
    $ kubectl -n "${NAMESPACE}" edit rolebinding extra-workload-admins
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Can delegate view access

    ```console
    $ kubectl edit clusterrolebinding extra-user-view
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Cannot run with root by default

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-root-nginx
    spec:
      podSelector:
        matchLabels:
          app: root-nginx
      policyTypes:
        - Ingress
        - Egress
      ingress:
        - {}
      egress:
        - {}
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        app: root-nginx
      name: root-nginx
    spec:
      restartPolicy: Never
      containers:
        - name: nginx
          image: nginx:stable
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
    EOF
    ```

#### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/welkin/user-guide/namespaces/#namespace-management)
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    apiVersion: hnc.x-k8s.io/v1alpha2
    kind: SubnamespaceAnchor
    metadata:
      name: ${NAMESPACE}-qa-test
    EOF

    kubectl get ns "${NAMESPACE}-qa-test"

    kubectl get subns -n "${NAMESPACE}" "${NAMESPACE}-qa-test" -o yaml
    ```

    </details>
- [ ] Ensure the default roles, rolebindings, and NetworkPolicies propagated
    <details><summary>Commands</summary>

    ```bash
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
    ```

    </details>

#### Harbor

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer via Dex with static user
    <details><summary>Steps</summary>

    - Login to Harbor with `admin@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

    - Login to Harbor with the admin user and promote `admin@example.com` to admin
    - Re-login with `admin@example.com`

    </details>
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
    - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
    - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

#### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

    ```bash
    kubectl get constraints
    ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/welkin/tree/main/user-demo/deploy/welkin-user-demo)
>
> - Set `NAMESPACE` to an application developer namespaces
> - Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With unset NetworkPolicies, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
    ```

- [ ] With unset resources, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
    ```

- [ ] With valid values, try to deploy, should succeed

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

#### cert-manager and Ingress-NGINX

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
    - [ ] Endpoints are reachable
    - [ ] Status includes correct IP addresses

#### Metrics

> [!note]
> As platform administrator

- [ ] Can login to platform administrator Grafana via Dex with IdP
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Cilium related dashboards are available and working

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to application developer Grafana via Dex with static user
    <details><summary>Steps</summary>

    - Login to Grafana with `admin@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

    - Login to Grafana with the admin user and promote `admin@example.com` to admin
    - Re-login with `admin@example.com`

    </details>
- [ ] Welcome dashboard presented first
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Metrics are available from user demo application
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>

#### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
    - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

#### Logs

> [!note]
> As platform administrator

- [ ] Able to run log-manager compaction jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # these commands must be changed if running non-standard cluster names
    ENVIRONMENT_NAME="<environment-name>"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-sc-compaction" "audit-${ENVIRONMENT_NAME}-sc-compaction-qa"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-wc-compaction" "audit-${ENVIRONMENT_NAME}-wc-compaction-qa"
    kubectl -n fluentd-system create job --from "cronjob/sc-logs-logs-compaction" "sc-logs-logs-compaction"
    ```

    Check the resulting bucket (S3) or container (Azure) that the all logs are collected into zstd compressed chunks, only logs from the current day should be gzipped as sent by Fluentd.

    </details>
- [ ] Able to run log-manager retention jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # these commands must be changed if running non-standard cluster names
    ENVIRONMENT_NAME="<environment-name>"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-sc-retention" "audit-${ENVIRONMENT_NAME}-sc-retention-qa"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-wc-retention" "audit-${ENVIRONMENT_NAME}-wc-retention-qa"
    kubectl -n fluentd-system create job --from "cronjob/sc-logs-logs-retention" "sc-logs-logs-retention"
    ```

    Check the resulting bucket (S3) or container (Azure) that the old logs are removed and current logs are kept, you may reconfigure the retention span to further test it.

    </details>
- [ ] Able to run OpenSearch curator jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # as long as curator is enabled it should run every five minutes
    kubectl -n opensearch-system get job -lapp.kubernetes.io/name=opensearch-curator
    ```

    Check the index management within OpenSearch to ensure that old indices are removed, you may reconfigure the retention span to further test it.

    </details>
- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Indices managed (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Logs available (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Snapshots configured
- [ ] Check the logs in OpenSearch and review any errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (Kubeaudit, Kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Falco

> [!note]
> As platform administrator

- [ ] Deploy the [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator#with-kubernetes) to generate events in wc
    <details><summary>Commands</summary>

    ```bash
    # Install

    kubectl create namespace event-generator
    kubectl label namespace event-generator owner=operator

    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update

    helm -n event-generator install event-generator falcosecurity/event-generator \
      --set securityContext.runAsNonRoot=true \
      --set securityContext.runAsGroup=65534 \
      --set securityContext.runAsUser=65534 \
      --set podSecurityContext.fsGroup=65534 \
      --set config.actions=""

    # Uninstall

    helm -n event-generator uninstall event-generator
    kubectl delete namespace event-generator
    ```

    </details>

- [ ] Logs are available in OpenSearch Dashboards
- [ ] Logs are relevant

#### Network Policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Take backups and snapshots

> [!note]
> As platform administrator

Prepare items to test disaster recovery:

- [ ] Login to Harbor and create a project and robot account:

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

- [ ] Login to Harbor with your access token:

    ```bash
    docker login "harbor.${DOMAIN}"
    ```

- [ ] Set the environment variable `REGISTRY_PROJECT` to the name of the created project
- [ ] Push the image `ghcr.io/elastisys/curl-jq:1.0.0` to the created project

    ```bash
    docker pull "ghcr.io/elastisys/curl-jq:1.0.0"
    docker tag "ghcr.io/elastisys/curl-jq:1.0.0" "harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0"
    docker push "harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0"
    ```

- [ ] [Create an image pull secret following the application developer docs](https://elastisys.io/welkin/user-guide/deploy/#configure-an-image-pull-secret)
- [ ] Deploy a Pod with a PersistantVolume on the workload cluster:
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-all
    spec:
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress
      ingress:
        - {}
      egress:
        - {}
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: velero-app-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: velero-app
    spec:
      restartPolicy: Never
      imagePullSecrets:
        - name: pull-secret
      containers:
        - name: read
          image: harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0
          command: ['sh', '-c', 'while true; do tail /pod-data/file.log && sleep 1800; done']
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
          volumeMounts:
            - name: shared-data
              mountPath: /pod-data
        - name: write
          image: harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0
          command: ['sh', '-c', 'while true; do echo "$(date +%F_%T) - Hello, Kubernetes!" >> /pod-data/file.log && sleep 1800; done']
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
          volumeMounts:
            - name: shared-data
              mountPath: /pod-data
      securityContext:
        runAsUser: 999
      volumes:
        - name: shared-data
          persistentVolumeClaim:
            claimName: velero-app-pvc
    EOF
    ```

    </details>

Follow the public disaster recovery documentation to take backups:

- [ ] Can [take Harbor backup](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup_1)
- [ ] Can [take OpenSearch snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup)
- [ ] Can [take Velero snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup_2)
- [ ] Can run Rclone sync:

    ```bash
    # create rclone sync jobs for all cronjobs:
    for cronjob in $(./bin/ck8s ops kubectl sc -n rclone get cronjobs -lapp.kubernetes.io/instance=rclone-sync -oname); do
      ./bin/ck8s ops kubectl sc -n rclone create job --from "${cronjob}" "${cronjob/#cronjob.batch\/}"
    done

    # wait for rclone sync jobs to finish
    ./bin/ck8s ops kubectl sc -n rclone get pods -lapp.kubernetes.io/instance=rclone-sync -w
    ```

#### Restore backups and snapshots

> [!note]
> As platform administrator
<!--divide-->
> [!important]
> Before running each restore you should either completely or partially delete the data within the target service, and after each restore validate that the data is restored.

Follow the public disaster recovery documentation to perform restores from the prepared backups:

- [ ] Can [run Rclone restore](https://github.com/elastisys/compliantkubernetes-apps/blob/main/restore/rclone/README.md)
    - _Examples of deleted data: Complete or partial removal of data with buckets or containers for Fluentd logs or Thanos, avoid tampering with Harbor, OpenSearch, and Velero._
- [ ] Can [restore Harbor backup](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore_1)
    - _Examples of deleted data: Complete or partial removal of Harbor configuration, project or user data._
- [ ] Can [restore OpenSearch snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore)
    - _Examples of deleted data: Complete or partial removal of OpenSearch indices and documents._
- [ ] Can [restore Velero snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore_2)
    - _Examples of deleted data: Complete or partial removal of application developer Kubernetes resources._

### Upgrade QA steps

> _Apps upgrade scenario_

#### Environment setup

**Provider**:

- [ ] Azure (alpha)
- [ ] Elastx (prod)
- [ ] Safespring (prod)
- [ ] UpCloud (prod)

**Installer**:

- [ ] Cluster API (beta)
- [ ] Kubespray (prod)

**Network Plugin**:

- [ ] Calico (prod)
- [ ] Cilium (alpha)

**Configuration**:

- [ ] Flavor - Prod
- [ ] Dex IdP - Google
- [ ] Dex Static User - Enabled and `admin@example.com` added as an application developer
    <details><summary>Commands</summary>

    ```bash
    # configure
    yq -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.user.adminUsers += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    yq -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply
    ./bin/ck8s apply sc
    ./bin/ck8s apply wc
    ```

    </details>
- [ ] Grafana trailing dots - Disabled
    <details><summary>Commands</summary>

    ```sh
    yq -i '.grafana.user.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.trailingDots = false' "${CK8S_CONFIG_PATH}/sc-config.yaml"

    # apply
    ./bin/ck8s ops helmfile sc -lapp=grafana diff
    ./bin/ck8s ops helmfile sc -lapp=grafana apply
    ```

    </details>
- [ ] Rclone sync - Enabled and preferably configured to a different infrastructure provider.
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace (this cannot be a subnamespace)
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Take backups and snapshots

> [!note]
> As platform administrator

Prepare items to test disaster recovery:

- [ ] Login to Harbor and create a project and robot account:

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

- [ ] Login to Harbor with your access token:

    ```bash
    docker login "harbor.${DOMAIN}"
    ```

- [ ] Set the environment variable `REGISTRY_PROJECT` to the name of the created project
- [ ] Push the image `ghcr.io/elastisys/curl-jq:1.0.0` to the created project

    ```bash
    docker pull "ghcr.io/elastisys/curl-jq:1.0.0"
    docker tag "ghcr.io/elastisys/curl-jq:1.0.0" "harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0"
    docker push "harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0"
    ```

- [ ] [Create an image pull secret following the application developer docs](https://elastisys.io/welkin/user-guide/deploy/#configure-an-image-pull-secret)
- [ ] Deploy a Pod with a PersistantVolume on the workload cluster:
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-all
    spec:
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress
      ingress:
        - {}
      egress:
        - {}
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: velero-app-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: velero-app
    spec:
      restartPolicy: Never
      imagePullSecrets:
        - name: pull-secret
      containers:
        - name: read
          image: harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0
          command: ['sh', '-c', 'while true; do tail /pod-data/file.log && sleep 1800; done']
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
          volumeMounts:
            - name: shared-data
              mountPath: /pod-data
        - name: write
          image: harbor.${DOMAIN}/${REGISTRY_PROJECT}/curl-jq:1.0.0
          command: ['sh', '-c', 'while true; do echo "$(date +%F_%T) - Hello, Kubernetes!" >> /pod-data/file.log && sleep 1800; done']
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
          volumeMounts:
            - name: shared-data
              mountPath: /pod-data
      securityContext:
        runAsUser: 999
      volumes:
        - name: shared-data
          persistentVolumeClaim:
            claimName: velero-app-pvc
    EOF
    ```

    </details>

Follow the public disaster recovery documentation to take backups:

- [ ] Can [take Harbor backup](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup_1)
- [ ] Can [take OpenSearch snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup)
- [ ] Can [take Velero snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#backup_2)
- [ ] Can run Rclone sync:

    ```bash
    # create rclone sync jobs for all cronjobs:
    for cronjob in $(./bin/ck8s ops kubectl sc -n rclone get cronjobs -lapp.kubernetes.io/instance=rclone-sync -oname); do
      ./bin/ck8s ops kubectl sc -n rclone create job --from "${cronjob}" "${cronjob/#cronjob.batch\/}"
    done

    # wait for rclone sync jobs to finish
    ./bin/ck8s ops kubectl sc -n rclone get pods -lapp.kubernetes.io/instance=rclone-sync -w
    ```

#### Upgrade

- [ ] Can upgrade according to [the migration docs for this version](https://github.com/elastisys/compliantkubernetes-apps/tree/main/migration)

#### Status tests

> [!note]
> As platform administrator

- [ ] Check that the deployment is idempotent

    ```bash
    ./bin/ck8s dry-run sc
    # should not report any changes

    ./bin/ck8s dry-run wc
    # should not report any changes
    ```

    If changes are reported, apply once and try again, if changes are still reported then there is an issue that must be fixed.

- [ ] Successful `./bin/ck8s test sc|wc`
- [ ] If possible let the environment stabilise into a steady state after the upgrade
    - Best is to perform the upgrade at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.

#### Automated tests

> [!note]
> As platform administrator

- [ ] Successful `make build-main` from the `tests/` directory
- [ ] Successful `make run-end-to-end` from the `tests/` directory

#### Kubernetes access

> [!note]
> As platform administrator

- [ ] Can login as platform administrator via Dex with IdP

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer `admin@example.com` via Dex with static user
- [ ] Can list access

    ```bash
    kubectl -n "${NAMESPACE}" auth can-i --list
    ```

- [ ] Can delegate admin access

    ```console
    $ kubectl -n "${NAMESPACE}" edit rolebinding extra-workload-admins
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Can delegate view access

    ```console
    $ kubectl edit clusterrolebinding extra-user-view
      # Add some subject
      subjects:
        # You can specify more than one "subject"
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: jane # "name" is case sensitive
    ```

- [ ] Cannot run with root by default

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-root-nginx
    spec:
      podSelector:
        matchLabels:
          app: root-nginx
      policyTypes:
        - Ingress
        - Egress
      ingress:
        - {}
      egress:
        - {}
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        app: root-nginx
      name: root-nginx
    spec:
      restartPolicy: Never
      containers:
        - name: nginx
          image: nginx:stable
          resources:
            requests:
              memory: 64Mi
              cpu: 250m
            limits:
              memory: 128Mi
              cpu: 500m
    EOF
    ```

#### Hierarchical Namespaces

> [!note]
> As application developer `admin@example.com`

- [ ] [Can create a subnamespace by following the application developer docs](https://elastisys.io/welkin/user-guide/namespaces/#namespace-management)
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    apiVersion: hnc.x-k8s.io/v1alpha2
    kind: SubnamespaceAnchor
    metadata:
      name: ${NAMESPACE}-qa-test
    EOF

    kubectl get ns "${NAMESPACE}-qa-test"

    kubectl get subns -n "${NAMESPACE}" "${NAMESPACE}-qa-test" -o yaml
    ```

    </details>
- [ ] Ensure the default roles, rolebindings, and NetworkPolicies propagated
    <details><summary>Commands</summary>

    ```bash
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}"
    kubectl get role,rolebinding,netpol -n "${NAMESPACE}-qa-test"
    ```

    </details>

#### Harbor

> [!note]
> As application developer `admin@example.com`

- [ ] Can login as application developer via Dex with static user
    <details><summary>Steps</summary>

    - Login to Harbor with `admin@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

    - Login to Harbor with the admin user and promote `admin@example.com` to admin
    - Re-login with `admin@example.com`

    </details>
- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities
- [ ] Configure project to disallow vulnerabilities
    - Try to pull image with vulnerabilities, should fail

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

- [ ] Configure project to allow vulnerabilities
    - Try to pull image with vulnerabilities, should succeed

    ```bash
    docker pull "harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo:${TAG}"
    ```

#### Gatekeeper

> [!note]
> As application developer `admin@example.com`

- [ ] Can list OPA rules

    ```bash
    kubectl get constraints
    ```

> [!note]
> Using [the user demo helm chart](https://github.com/elastisys/welkin/tree/main/user-demo/deploy/welkin-user-demo)
>
> - Set `NAMESPACE` to an application developer namespaces
> - Set `PUBLIC_DOCS_PATH` to the path of the public docs repo

- [ ] With invalid image repository, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With invalid image tag, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag=latest \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] With unset NetworkPolicies, try to deploy, should warn due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set networkPolicy.enabled=false
    ```

- [ ] With unset resources, try to deploy, should fail due to constraint

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}" \
      --set resources.requests=null
    ```

- [ ] With valid values, try to deploy, should succeed

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

#### cert-manager and Ingress-NGINX

> [!note]
> As platform administrator

- [ ] All certificates ready including user demo
- [ ] All ingresses ready including user demo
    - [ ] Endpoints are reachable
    - [ ] Status includes correct IP addresses

#### Metrics

> [!note]
> As platform administrator

- [ ] Can login to platform administrator Grafana via Dex with IdP
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Cilium related dashboards are available and working
- [ ] Check the volume of metrics scraped by Prometheus and ingested by Thanos and compare it to before the upgrade
    <!-- TODO: Create a Grafana dashboard to assist in measuring metrics for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to application developer Grafana via Dex with static user
    <details><summary>Steps</summary>

    - Login to Grafana with `admin@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

    - Login to Grafana with the admin user and promote `admin@example.com` to admin
    - Re-login with `admin@example.com`

    </details>
- [ ] Welcome dashboard presented first
- [ ] Dashboards are available and viewable
- [ ] Metrics are available from all clusters
- [ ] Metrics are available from user demo application
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>

#### Alerts

> [!note]
> As platform administrator

- [ ] No alert open except `Watchdog`, `CPUThrottlingHigh` and `FalcoAlert`
    - Can be seen in the alert section in platform administrator Grafana

> [!note]
> As application developer `admin@example.com`

- [ ] [Access Prometheus following the application developer docs](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Prometheus picked up user demo ServiceMonitor and PrometheusRule
- [ ] [Access Alertmanager following the application developer docs](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)
- [ ] Alertmanager `Watchdog` firing

#### Logs

> [!note]
> As platform administrator

- [ ] Able to run log-manager compaction jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # these commands must be changed if running non-standard cluster names
    ENVIRONMENT_NAME="<environment-name>"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-sc-compaction" "audit-${ENVIRONMENT_NAME}-sc-compaction-qa"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-wc-compaction" "audit-${ENVIRONMENT_NAME}-wc-compaction-qa"
    kubectl -n fluentd-system create job --from "cronjob/sc-logs-logs-compaction" "sc-logs-logs-compaction"
    ```

    Check the resulting bucket (S3) or container (Azure) that the all logs are collected into zstd compressed chunks, only logs from the current day should be gzipped as sent by Fluentd.

    </details>
- [ ] Able to run log-manager retention jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # these commands must be changed if running non-standard cluster names
    ENVIRONMENT_NAME="<environment-name>"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-sc-retention" "audit-${ENVIRONMENT_NAME}-sc-retention-qa"
    kubectl -n fluentd-system create job --from "cronjob/audit-${ENVIRONMENT_NAME}-wc-retention" "audit-${ENVIRONMENT_NAME}-wc-retention-qa"
    kubectl -n fluentd-system create job --from "cronjob/sc-logs-logs-retention" "sc-logs-logs-retention"
    ```

    Check the resulting bucket (S3) or container (Azure) that the old logs are removed and current logs are kept, you may reconfigure the retention span to further test it.

    </details>
- [ ] Able to run OpenSearch curator jobs successfully
    <details><summary>Commands</summary>

    ```bash
    # as long as curator is enabled it should run every five minutes
    kubectl -n opensearch-system get job -lapp.kubernetes.io/name=opensearch-curator
    ```

    Check the index management within OpenSearch to ensure that old indices are removed, you may reconfigure the retention span to further test it.

    </details>
- [ ] Can login to OpenSearch Dashboards via Dex with IdP
- [ ] Indices created (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Indices managed (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Logs available (Authlog, Kubeaudit, Kubernetes, Other)
- [ ] Snapshots configured
- [ ] Check the volume of logs collected by Fluentd and ingested by OpenSearch and compare it to before the upgrade
    <!-- TODO: Create an OpenSearch dashboard to assist in measuring logs for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.
- [ ] Check the logs in OpenSearch and review any errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

> [!note]
> As application developer `admin@example.com`

- [ ] Can login to OpenSearch Dashboards via Dex with static user
- [ ] Welcome dashboard presented first
- [ ] Logs available (Kubeaudit, Kubernetes)
- [ ] [CISO dashboards available and working](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Falco

> [!note]
> As platform administrator

- [ ] Deploy the [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator#with-kubernetes) to generate events in wc
    <details><summary>Commands</summary>

    ```bash
    # Install

    kubectl create namespace event-generator
    kubectl label namespace event-generator owner=operator

    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update

    helm -n event-generator install event-generator falcosecurity/event-generator \
      --set securityContext.runAsNonRoot=true \
      --set securityContext.runAsGroup=65534 \
      --set securityContext.runAsUser=65534 \
      --set podSecurityContext.fsGroup=65534 \
      --set config.actions=""

    # Uninstall

    helm -n event-generator uninstall event-generator
    kubectl delete namespace event-generator
    ```

    </details>

- [ ] Logs are available in OpenSearch Dashboards
- [ ] Logs are relevant

#### Network Policies

- [ ] No dropped packets in NetworkPolicy Grafana dashboard

#### Restore backups and snapshots

> [!note]
> As platform administrator
<!--divide-->
> [!important]
> Before running each restore you should either completely or partially delete the data within the target service, and after each restore validate that the data is restored.

Follow the public disaster recovery documentation to perform restores from the prepared backups:

- [ ] Can [run Rclone restore](https://github.com/elastisys/compliantkubernetes-apps/blob/main/restore/rclone/README.md)
    - _Examples of deleted data: Complete or partial removal of data with buckets or containers for Fluentd logs or Thanos, avoid tampering with Harbor, OpenSearch, and Velero._
- [ ] Can [restore Harbor backup](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore_1)
    - _Examples of deleted data: Complete or partial removal of Harbor configuration, project or user data._
- [ ] Can [restore OpenSearch snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore)
    - _Examples of deleted data: Complete or partial removal of OpenSearch indices and documents._
- [ ] Can [restore Velero snapshot](https://elastisys.io/welkin/operator-manual/disaster-recovery/#restore_2)
    - _Examples of deleted data: Complete or partial removal of application developer Kubernetes resources._

### After QA steps

- [ ] Update the Welcoming Dashboards "What's New" section.

  Add items for new feature or changes that are relevant for application developers, e.g. for `v0.25` "- As an application developer you can now create namespaces yourself using HNC ...".

  Remove items for releases older than two major or minor versions, e.g. for `v0.25` you keep items for `v0.25` and `v0.24` and remove all items for all older versions.

    - Edit the [Grafana dashboard](https://github.com/elastisys/compliantkubernetes-apps/tree/main/helmfile.d/charts/grafana-dashboards/files/welcome.md)
    - Edit the [OpenSearch dashboard](https://github.com/elastisys/compliantkubernetes-apps/tree/main/helmfile.d/charts/opensearch/configurer/files/dashboards-resources/welcome.md)

- [ ] Complete [the code freeze step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#code-freeze)
- [ ] The staging pull request must be approved

### Release steps

- [ ] Complete [the release step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#release)
- [ ] Complete [the update public release notes step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#update-public-release-notes)
- [ ] Complete [the update main branch step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#update-the-main-branch)

### Final steps
