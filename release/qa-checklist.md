# Quality Assurance Checklist

Elastisys Welkin® Apps

## Checklist

> [!note]
> This document is maintained as a reference for the quality assurance checklist for Welkin Apps.
> The actual release and quality assurance process is driven by an internal issue template, as it also ties together with internal processes, however these are templated from the same source so the main steps are accurate.

### Overview

**Sections**:

<!-- markdownlint-disable MD051 -->

- [Before QA steps](#user-content-before-qa-steps)
- [Install QA steps](#user-content-install-qa-steps)
- [Upgrade QA steps](#user-content-upgrade-qa-steps)
- [After QA steps](#user-content-after-qa-steps)
- [Release steps](#user-content-release-steps)
- [Final steps](#user-content-final-steps)

### <a id="before-qa-steps" href="#user-content-before-qa-steps">#</a> Before QA steps

> [!note]
> Whenever you need to change access from platform administrator to application developer `dev@example.com` prefer to re-login rather than impersonation `--as=dev@example.com`.
> For this you have two options:
>
> - Either set a different cache directory `export KUBECACHEDIR=${HOME}/.kube-static/cache` when switching to application developer and restore `unset KUBECACHEDIR` when switching to platform administrator.
> - Or clear the cache `rm -r ~/.kube/cache/oidc-login` whenever you switch between.

- [ ] Ensure the release follows [the release constraints](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#constraints)
- [ ] Complete [the feature freeze step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#feature-freeze)
- [ ] Complete [the staging step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#staging)

### <a id="install-qa-steps" href="#user-content-install-qa-steps">#</a> Install QA steps

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
- [ ] Dex Static Users - Enabled, `admin@example.com` and `dev@example.com` added
    <details><summary>Commands</summary>

    ```sh
    # configure
    yq -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.skipRoleSync = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.user.oidc.skipRoleSync = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name == "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["dev@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.clusterAdmin.users += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/common-config.yaml"
    yq -i '.user.adminUsers += ["dev@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    sops --set '["dex"]["extraStaticLogins"][0] {"email":"dev@example.com","userID":"08a8684b-db88-4b73-90a9-3cd1661f5467","username":"dev","password":"password","hash":"$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"}' "${CK8S_CONFIG_PATH}/secrets.yaml"
    # only needed if you intend to test gpu support <!-- TODO: Move --->
    yq -i '.opa.imageRegistry.URL += ["nvcr.io/nvidia/k8s/cuda-sample"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"

    # apply
    ./bin/ck8s apply sc
    ./bin/ck8s apply wc
    ```

    </details>
- [ ] Gatekeeper constraints - Enable user CRDs and policies needed for tests (some of these may already be enabled by default)
    <details><summary>Commands</summary>

    ```sh
yq -i '.gatekeeper.allowUserCRDs.enabled = true' "${CK8S_CONFIG_PATH}/wc-config.yaml"
yq -i '.gatekeeper.allowUserCRDs.enforcement = "deny"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
yq -i '.opa.rejectLoadBalancerService.enabled = true' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.rejectLoadBalancerService.enforcement = "deny"' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.rejectLocalStorageEmptyDir.enabled = true' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.rejectLocalStorageEmptyDir.enforcement = "warn"' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.rejectPodWithoutController.enabled = true' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.rejectPodWithoutController.enforcement = "warn"' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.minimumDeploymentReplicas.enabled = true' "${CK8S_CONFIG_PATH}/common-config.yaml"
yq -i '.opa.minimumDeploymentReplicas.enforcement = "warn"' "${CK8S_CONFIG_PATH}/common-config.yaml"

    # apply
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
- [ ] If possible let the environment stabilise into a steady state after the install
    - Best is to perform the install at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.
- [ ] Set the environment variable `NAMESPACE` to an application developer namespace (this cannot be a subnamespace)
- [ ] Set the environment variable `DOMAIN` to the environment domain

#### Automated tests

> [!note]
> Many checks have turned into automated end-to-end tests, and some may currently be a bit rough around the edges.
> Do take note of any issues you have with them so we can improve upon them.
> If you have any questions about them ask QAE or in their absence QA goto.

> [!important]
> From the `tests/` directory.

> [!tip]
> By default the Cypress tests will run headless, if you want visual feedback during testing you can export the variable `CK8S_HEADED_CYPRESS=true` before running.

- [ ] Successful `make build-main`.
- [ ] Successful `make run-end-to-end/apps`
- [ ] Successful `make run-end-to-end/general`
- [ ] Successful `make run-end-to-end/kubernetes`
- [ ] Successful `make run-end-to-end/cert-manager`
- [ ] Successful `make run-end-to-end/ingress`
- [ ] Successful `make run-end-to-end/hnc`
- [ ] Successful `make run-end-to-end/opa-gatekeeper`
- [ ] Successful `make run-end-to-end/harbor`
- [ ] Successful `make run-end-to-end/alertmanager`
- [ ] Successful `make run-end-to-end/prometheus`
- [ ] Successful `make run-end-to-end/grafana`
- [ ] Successful `make run-end-to-end/fluentd`
- [ ] Successful `make run-end-to-end/opensearch`
- [ ] Successful `make run-end-to-end/log-manager`
- [ ] Successful `make run-end-to-end/falco`
- [ ] Successful `make run-end-to-end/netpol`
- [ ] Successful `make run-end-to-end/velero`

> [!warning]
> The log-manager tests has an involved setup which may fail, so the function of log-manager might need to be checked manually.
>
> With Cilium as network plugin it is expected that the Grafana and NetworkPolicy tests will fail, and the dashboard must be checked manually, you can track [their implementation here](https://github.com/elastisys/compliantkubernetes-apps/issues/2726).

#### Application developer scenario

> [!note]
> As application developer `dev@example.com`
>
> The following checklist items aim to verify relevant parts of the public docs.
> It should be done with an exploratory mindset, and therefore some don't have well defined steps.
>
> This could be either in the context of what you would use as an application developer, what is new for this release, or in a situation with an error that would have you need to check that status of the application.

**Prepare container image**:

> [!note]
> If the `end-to-end/harbor` tests completed successfully the dev user should already be admin, else login as admin and promote it first.

- [ ] Can login to Harbor as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities

**Install helm chart**:

- [ ] Can install chart

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] Can access user demo via Ingress with valid certificate

    ```bash
    xdg-open "https://demoapp.${DOMAIN}"
    ```

**Observability Metrics**:

- [ ] Can login to Grafana as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected metrics
- [ ] Can see metrics from the user demo application
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] Can see the [CISO dashboards with metrics](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>
- [ ] Can see [ServiceMonitor and PrometheusRule from the user demo application in Prometheus](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Can see [alerts from the user demo application in Alertmanager](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)

**Observability Logs**:

- [ ] Can login to OpenSearch as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://opensearch.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected logs
- [ ] Can see logs from the user demo application
- [ ] Can see the [CISO dashboards with logs](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Platform administrator scenario

> [!note]
> As platform administrator
>
> The following checklist items should be done with an exploratory mindset, and therefore they don't have well defined steps.
>
> This could be either in the context of what you normally use, what you normally _do not_ use, what is new for this release, or in a situation with an error that would have you need to check that status of the environment.

**Observability Metrics**:

- [ ] Can login to Grafana as platform administrator via Dex

    ```bash
    xdg-open "https://grafana.ops.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected metrics
- [ ] Can see expected alerts
- [ ] Check the metrics in Grafana and review any indications of errors and warnings
    <!-- TODO: Create an Grafana dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

**Observability Logs**:

- [ ] Can login to OpenSearch as platform administrator via Dex

    ```bash
    xdg-open "https://opensearch.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected logs
- [ ] Check the logs in OpenSearch and review any indications of errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

#### GPU support

> [!important]
> GPU support checks should be done on _one_ of the scenarios, either install or upgrade.
> If you are using Cluster API as the installer you must setup GPU nodes with auto-scaling as that is tested.
> If you are using Cluster API as the installer follow [this guide](https://github.com/elastisys/mse-internal-docs/blob/main/docs/ops-manual/enable-and-operate-gpu.md) to configure the GPU worker pool.

> [!note]
> As platform administrator

- [ ] Verify the GPU Operator installation and that it's healthy
    <details><summary>Commands</summary>

    List all the GPU operator components.

    ```console
    $ ./bin/ck8s ops kubectl wc get pods -n gpu-operator
    NAME                                                              READY   STATUS    RESTARTS       AGE
    gpu-operator-74dc66799f-htkmz                                     1/1     Running   0              2d6h
    nvidia-gpu-operator-node-feature-discovery-gc-5dcd75f76-wq82r     1/1     Running   0              2d6h
    nvidia-gpu-operator-node-feature-discovery-master-56484df44p9cn   1/1     Running   0              30d
    nvidia-gpu-operator-node-feature-discovery-worker-444cn           1/1     Running   0              69d
    nvidia-gpu-operator-node-feature-discovery-worker-l2nld           1/1     Running   0              4d2h
    nvidia-gpu-operator-node-feature-discovery-worker-vs6bg           1/1     Running   0              2d7h
    ```

    Verify all the components are working fine without any errors.

    </details>

- [ ]  Validate regular reconciliation
    <details><summary>Commands</summary>

    Run the command then wait for the events to occur.
    See the details below on how the operator performs its reconciliation cycle and what log messages you should expect.

    ```console
    $ ./bin/ck8s ops kubectl wc logs -n gpu-operator -f --tail=0 deploy/gpu-operator

    {"level":"info","ts":1739356589.0991879,"logger":"controllers.Upgrade","msg":"Reconciling Upgrade","upgrade":{"name":"cluster-policy"}}
    {"level":"info","ts":1739356589.0992486,"logger":"controllers.Upgrade","msg":"Using label selector","upgrade":{"name":"cluster-policy"},"key":"app","value":"nvidia-driver-daemonset"}
    {"level":"info","ts":1739356589.0993133,"logger":"controllers.Upgrade","msg":"Building state"}
    {"level":"info","ts":1739356589.1098218,"logger":"controllers.Upgrade","msg":"Propagate state to state manager","upgrade":{"name":"cluster-policy"}}
    {"level":"info","ts":1739356589.109842,"logger":"controllers.Upgrade","msg":"State Manager, got state update"}
    {"level":"info","ts":1739356589.1098468,"logger":"controllers.Upgrade","msg":"Node states:","Unknown":0,"upgrade-done":0,"upgrade-required":0,"cordon-required":0,"wait-for-jobs-required":0,"pod-deletion-required":0,"upgrade-failed":0,"drain-required":0,"pod-restart-required":0,"validation-required":0,"uncordon-required":0}
    {"level":"info","ts":1739356589.1098578,"logger":"controllers.Upgrade","msg":"Upgrades in progress","currently in progress":0,"max parallel upgrades":1,"upgrade slots available":0,"currently unavailable nodes":0,"total number of nodes":0,"maximum nodes that can be unavailable":0}
    {"level":"info","ts":1739356589.1098645,"logger":"controllers.Upgrade","msg":"ProcessDoneOrUnknownNodes"}
    {"level":"info","ts":1739356589.1098678,"logger":"controllers.Upgrade","msg":"ProcessDoneOrUnknownNodes"}
    {"level":"info","ts":1739356589.1098716,"logger":"controllers.Upgrade","msg":"ProcessUpgradeRequiredNodes"}
    {"level":"info","ts":1739356589.1098745,"logger":"controllers.Upgrade","msg":"ProcessCordonRequiredNodes"}
    {"level":"info","ts":1739356589.1098773,"logger":"controllers.Upgrade","msg":"ProcessWaitForJobsRequiredNodes"}
    {"level":"info","ts":1739356589.1098807,"logger":"controllers.Upgrade","msg":"ProcessPodDeletionRequiredNodes"}
    {"level":"info","ts":1739356589.1098847,"logger":"controllers.Upgrade","msg":"ProcessDrainNodes"}
    {"level":"info","ts":1739356589.1098878,"logger":"controllers.Upgrade","msg":"Node drain is disabled by policy, skipping this step"}
    {"level":"info","ts":1739356589.1098914,"logger":"controllers.Upgrade","msg":"ProcessPodRestartNodes"}
    {"level":"info","ts":1739356589.1098948,"logger":"controllers.Upgrade","msg":"Starting Pod Delete"}
    {"level":"info","ts":1739356589.1098971,"logger":"controllers.Upgrade","msg":"No pods scheduled to restart"}
    {"level":"info","ts":1739356589.1099007,"logger":"controllers.Upgrade","msg":"ProcessUpgradeFailedNodes"}
    {"level":"info","ts":1739356589.1099038,"logger":"controllers.Upgrade","msg":"ProcessValidationRequiredNodes"}
    {"level":"info","ts":1739356589.1099067,"logger":"controllers.Upgrade","msg":"ProcessUncordonRequiredNodes"}
    {"level":"info","ts":1739356589.10991,"logger":"controllers.Upgrade","msg":"State Manager, finished processing"}
    ```

    </details>

    - [ ] Verify that the operator is continuously checking and updating the GPU state for reconciliation messages as shown above
    - [ ] Verify that the operator can successfully complete actions for `upgrade-required`, `cordon-required`, and `pod-deletion-required`. Once completed, ensure that no pending actions are reported
    - [ ] Ensure healthy key processing flow like `ProcessValidationRequiredNodes` and `ProcessUncordonRequiredNodes` run without errors

> [!note]
> As application developer `dev@example.com`

- [ ] Able to deploy the GPU application workload jobs successfully
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cuda-vectoradd-job
    spec:
      template:
        metadata:
          labels:
            app: cuda-vectoradd
        spec:
          restartPolicy: OnFailure
          tolerations:
          - key: "elastisys.io/node-type"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
          containers:
          - name: cuda-vectoradd
            image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0-ubuntu22.04
            resources:
              limits:
                nvidia.com/gpu: 1
                memory: 128Mi
                cpu: 500m
              requests:
                memory: 64Mi
                cpu: 250m
            securityContext:
              allowPrivilegeEscalation: false
              runAsNonRoot: true
              runAsUser: 1000
              capabilities:
                drop:
                  - ALL
              seccompProfile:
                type: RuntimeDefault
    EOF
    ```

    </details>
- [ ]  Verify GPU workload scheduled on GPU node

    ```bash
    ./bin/ck8s ops kubectl wc get pods -n "${NAMESPACE}" -l job-name=cuda-vectoradd-job -o wide
    ```

- [ ] Verify GPU resources allocated to the Pod

    ```bash
    ./bin/ck8s ops kubectl wc describe pod <pod-name> -n "${NAMESPACE}"| grep "nvidia.com/gpu"
    ```

- [ ] _With Cluster API_: Verify on-demand GPU node provisioned when requested

    ```bash
    ./bin/ck8s ops kubectl wc get nodes -l elastisys.io/node-type=gpu -o wide
    ```

- [ ] Clean up GPU test Workload

    ```bash
    ./bin/ck8s ops kubectl wc delete job cuda-vectoradd-job -n "${NAMESPACE}"
    ```

- [ ] _With Cluster API_: Verify on-demand GPU node de-provisioned when not used

    ```bash
    ./bin/ck8s ops kubectl wc get nodes -l elastisys.io/node-type=gpu -o wide
    ```

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

### <a id="upgrade-qa-steps" href="#user-content-upgrade-qa-steps">#</a> Upgrade QA steps

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
- [ ] Dex Static Users - Enabled, `admin@example.com` and `dev@example.com` added
    <details><summary>Commands</summary>

    ```sh
    # configure
    yq -i '.dex.enableStaticLogin = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.skipRoleSync = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.ops.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.user.oidc.skipRoleSync = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.grafana.user.oidc.allowedDomains += ["example.com"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name == "all_access"); .definition.users += ["admin@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i 'with(.opensearch.extraRoleMappings[]; with(select(.mapping_name != "all_access"); .definition.users += ["dev@example.com"]))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    yq -i '.clusterAdmin.users += ["admin@example.com"]' "${CK8S_CONFIG_PATH}/common-config.yaml"
    yq -i '.user.adminUsers += ["dev@example.com"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    sops --set '["dex"]["extraStaticLogins"][0] {"email":"dev@example.com","userID":"08a8684b-db88-4b73-90a9-3cd1661f5467","username":"dev","password":"password","hash":"$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"}' "${CK8S_CONFIG_PATH}/secrets.yaml"
    # only needed if you intend to test gpu support <!-- TODO: Move --->
    yq -i '.opa.imageRegistry.URL += ["nvcr.io/nvidia/k8s/cuda-sample"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"

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
- [ ] If possible let the environment stabilise into a steady state after the upgrade
    - Best is to perform the upgrade at the end of the day to give it the night to stabilise.
    - Otherwise give it at least one to two hours to stabilise if possible.

#### Automated tests

> [!note]
> Many checks have turned into automated end-to-end tests, and some may currently be a bit rough around the edges.
> Do take note of any issues you have with them so we can improve upon them.
> If you have any questions about them ask QAE or in their absence QA goto.

> [!important]
> From the `tests/` directory.

> [!tip]
> By default the Cypress tests will run headless, if you want visual feedback during testing you can export the variable `CK8S_HEADED_CYPRESS=true` before running.

- [ ] Successful `make build-main`.
- [ ] Successful `make run-end-to-end/apps`
- [ ] Successful `make run-end-to-end/general`
- [ ] Successful `make run-end-to-end/kubernetes`
- [ ] Successful `make run-end-to-end/cert-manager`
- [ ] Successful `make run-end-to-end/ingress`
- [ ] Successful `make run-end-to-end/hnc`
- [ ] Successful `make run-end-to-end/opa-gatekeeper`
- [ ] Successful `make run-end-to-end/harbor`
- [ ] Successful `make run-end-to-end/alertmanager`
- [ ] Successful `make run-end-to-end/prometheus`
- [ ] Successful `make run-end-to-end/grafana`
- [ ] Successful `make run-end-to-end/fluentd`
- [ ] Successful `make run-end-to-end/opensearch`
- [ ] Successful `make run-end-to-end/log-manager`
- [ ] Successful `make run-end-to-end/falco`
- [ ] Successful `make run-end-to-end/netpol`
- [ ] Successful `make run-end-to-end/velero`

> [!warning]
> The log-manager tests has an involved setup which may fail, so the function of log-manager might need to be checked manually.
>
> With Cilium as network plugin it is expected that the Grafana and NetworkPolicy tests will fail, and the dashboard must be checked manually, you can track [their implementation here](https://github.com/elastisys/compliantkubernetes-apps/issues/2726).

#### Application developer scenario

> [!note]
> As application developer `dev@example.com`
>
> The following checklist items aim to verify relevant parts of the public docs.
> It should be done with an exploratory mindset, and therefore some don't have well defined steps.
>
> This could be either in the context of what you would use as an application developer, what is new for this release, or in a situation with an error that would have you need to check that status of the application.

**Prepare container image**:

> [!note]
> If the `end-to-end/harbor` tests completed successfully the dev user should already be admin, else login as admin and promote it first.

- [ ] Can login to Harbor as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://harbor.${DOMAIN}"
    ```

- [ ] [Can create projects and push images by following the application developer docs](https://elastisys.io/welkin/user-guide/registry/#running-example)
- [ ] [Can configure image pull secret by following the application developer docs](https://elastisys.io/welkin/user-guide/kubernetes-api/#configure-an-image-pull-secret)
- [ ] Can scan image for vulnerabilities

**Install helm chart**:

- [ ] Can install chart

    ```bash
    helm -n "${NAMESPACE}" upgrade --atomic --install demo "${PUBLIC_DOCS_PATH}/user-demo/deploy/welkin-user-demo" \
      --set image.repository="harbor.${DOMAIN}/${REGISTRY_PROJECT}/welkin-user-demo" \
      --set image.tag="${TAG}" \
      --set ingress.hostname="demoapp.${DOMAIN}"
    ```

- [ ] Can access user demo via Ingress with valid certificate

    ```bash
    xdg-open "https://demoapp.${DOMAIN}"
    ```

**Observability Metrics**:

- [ ] Can login to Grafana as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://grafana.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected metrics
- [ ] Can see metrics from the user demo application
    <details><summary>Steps</summary>

    - Go to explore page in Grafana
    - Enter `rate(http_request_duration_seconds_count{container="welkin-user-demo"}[1m])` as the query
    - Metrics should show up

    </details>
- [ ] Can see the [CISO dashboards with metrics](https://elastisys.io/welkin/ciso-guide/)
    <details><summary>List</summary>

    - [Backup / Backup Status](https://elastisys.io/welkin/ciso-guide/backup/)
    - [Cryptography / NGINX Ingress Controller](https://elastisys.io/welkin/ciso-guide/cryptography/)
    - [Intrusion Detection / Falco](https://elastisys.io/welkin/ciso-guide/intrusion-detection/)
    - [Policy-as-Code / Gatekeeper](https://elastisys.io/welkin/ciso-guide/policy-as-code/)
    - [Network Security / NetworkPolicy](https://elastisys.io/welkin/ciso-guide/network-security/)
    - [Capacity Management / Kubernetes Cluster Status](https://elastisys.io/welkin/ciso-guide/capacity-management/)
    - [Vulnerability / Trivy Operator Dashboard](https://elastisys.io/welkin/ciso-guide/vulnerability/)

    </details>
- [ ] Can see [ServiceMonitor and PrometheusRule from the user demo application in Prometheus](https://elastisys.io/welkin/user-guide/metrics/#accessing-the-prometheus-ui)
- [ ] Can see [alerts from the user demo application in Alertmanager](https://elastisys.io/welkin/user-guide/alerts/#accessing-user-alertmanager)

**Observability Logs**:

- [ ] Can login to OpenSearch as application developer via Dex with `dev@example.com`

    ```bash
    xdg-open "https://opensearch.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected logs
- [ ] Can see logs from the user demo application
- [ ] Can see the [CISO dashboards with logs](https://elastisys.io/welkin/ciso-guide/audit-logs/)

#### Platform administrator scenario

> [!note]
> As platform administrator
>
> The following checklist items should be done with an exploratory mindset, and therefore they don't have well defined steps.
>
> This could be either in the context of what you normally use, what you normally _do not_ use, what is new for this release, or in a situation with an error that would have you need to check that status of the environment.

**Observability Metrics**:

- [ ] Can login to Grafana as platform administrator via Dex

    ```bash
    xdg-open "https://grafana.ops.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected metrics
- [ ] Can see expected alerts
- [ ] Check the volume of metrics scraped by Prometheus and ingested by Thanos and compare it to before the upgrade
    <!-- TODO: Create a Grafana dashboard to assist in measuring metrics for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.
- [ ] Check the metrics in Grafana and review any indications of errors and warnings
    <!-- TODO: Create an Grafana dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

**Observability Logs**:

- [ ] Can login to OpenSearch as platform administrator via Dex

    ```bash
    xdg-open "https://opensearch.${DOMAIN}"
    ```

- [ ] Can see expected dashboards
- [ ] Can see expected logs
- [ ] Check the volume of logs collected by Fluentd and ingested by OpenSearch and compare it to before the upgrade
    <!-- TODO: Create an OpenSearch dashboard to assist in measuring logs for QA --->
    If there is a large change compared to before the upgrade that cannot be supported by the changes done in the release then this should be investigated as this may point towards:

    - Errors caused by incompatible or misbehaving components or configurations
    - Unintentional addition or removal of components

    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.
- [ ] Check the logs in OpenSearch and review any indications of errors and warnings
    <!-- TODO: Create an OpenSearch dashboard to assist in checking logs for QA --->
    If there are clear issues then this should be fixed.
    If there are no clear issues, or if fixing the issues would require substantial work, then talk with the QAE, or TLs if they are unavailable, about either accepting or taking additional actions.

#### GPU support

> [!important]
> GPU support checks should be done on _one_ of the scenarios, either install or upgrade.
> If you are using Cluster API as the installer you must setup GPU nodes with auto-scaling as that is tested.
> If you are using Cluster API as the installer follow [this guide](https://github.com/elastisys/mse-internal-docs/blob/main/docs/ops-manual/enable-and-operate-gpu.md) to configure the GPU worker pool.

> [!note]
> As platform administrator

- [ ] Verify the GPU Operator installation and that it's healthy
    <details><summary>Commands</summary>

    List all the GPU operator components.

    ```console
    $ ./bin/ck8s ops kubectl wc get pods -n gpu-operator
    NAME                                                              READY   STATUS    RESTARTS       AGE
    gpu-operator-74dc66799f-htkmz                                     1/1     Running   0              2d6h
    nvidia-gpu-operator-node-feature-discovery-gc-5dcd75f76-wq82r     1/1     Running   0              2d6h
    nvidia-gpu-operator-node-feature-discovery-master-56484df44p9cn   1/1     Running   0              30d
    nvidia-gpu-operator-node-feature-discovery-worker-444cn           1/1     Running   0              69d
    nvidia-gpu-operator-node-feature-discovery-worker-l2nld           1/1     Running   0              4d2h
    nvidia-gpu-operator-node-feature-discovery-worker-vs6bg           1/1     Running   0              2d7h
    ```

    Verify all the components are working fine without any errors.

    </details>

- [ ]  Validate regular reconciliation
    <details><summary>Commands</summary>

    Run the command then wait for the events to occur.
    See the details below on how the operator performs its reconciliation cycle and what log messages you should expect.

    ```console
    $ ./bin/ck8s ops kubectl wc logs -n gpu-operator -f --tail=0 deploy/gpu-operator

    {"level":"info","ts":1739356589.0991879,"logger":"controllers.Upgrade","msg":"Reconciling Upgrade","upgrade":{"name":"cluster-policy"}}
    {"level":"info","ts":1739356589.0992486,"logger":"controllers.Upgrade","msg":"Using label selector","upgrade":{"name":"cluster-policy"},"key":"app","value":"nvidia-driver-daemonset"}
    {"level":"info","ts":1739356589.0993133,"logger":"controllers.Upgrade","msg":"Building state"}
    {"level":"info","ts":1739356589.1098218,"logger":"controllers.Upgrade","msg":"Propagate state to state manager","upgrade":{"name":"cluster-policy"}}
    {"level":"info","ts":1739356589.109842,"logger":"controllers.Upgrade","msg":"State Manager, got state update"}
    {"level":"info","ts":1739356589.1098468,"logger":"controllers.Upgrade","msg":"Node states:","Unknown":0,"upgrade-done":0,"upgrade-required":0,"cordon-required":0,"wait-for-jobs-required":0,"pod-deletion-required":0,"upgrade-failed":0,"drain-required":0,"pod-restart-required":0,"validation-required":0,"uncordon-required":0}
    {"level":"info","ts":1739356589.1098578,"logger":"controllers.Upgrade","msg":"Upgrades in progress","currently in progress":0,"max parallel upgrades":1,"upgrade slots available":0,"currently unavailable nodes":0,"total number of nodes":0,"maximum nodes that can be unavailable":0}
    {"level":"info","ts":1739356589.1098645,"logger":"controllers.Upgrade","msg":"ProcessDoneOrUnknownNodes"}
    {"level":"info","ts":1739356589.1098678,"logger":"controllers.Upgrade","msg":"ProcessDoneOrUnknownNodes"}
    {"level":"info","ts":1739356589.1098716,"logger":"controllers.Upgrade","msg":"ProcessUpgradeRequiredNodes"}
    {"level":"info","ts":1739356589.1098745,"logger":"controllers.Upgrade","msg":"ProcessCordonRequiredNodes"}
    {"level":"info","ts":1739356589.1098773,"logger":"controllers.Upgrade","msg":"ProcessWaitForJobsRequiredNodes"}
    {"level":"info","ts":1739356589.1098807,"logger":"controllers.Upgrade","msg":"ProcessPodDeletionRequiredNodes"}
    {"level":"info","ts":1739356589.1098847,"logger":"controllers.Upgrade","msg":"ProcessDrainNodes"}
    {"level":"info","ts":1739356589.1098878,"logger":"controllers.Upgrade","msg":"Node drain is disabled by policy, skipping this step"}
    {"level":"info","ts":1739356589.1098914,"logger":"controllers.Upgrade","msg":"ProcessPodRestartNodes"}
    {"level":"info","ts":1739356589.1098948,"logger":"controllers.Upgrade","msg":"Starting Pod Delete"}
    {"level":"info","ts":1739356589.1098971,"logger":"controllers.Upgrade","msg":"No pods scheduled to restart"}
    {"level":"info","ts":1739356589.1099007,"logger":"controllers.Upgrade","msg":"ProcessUpgradeFailedNodes"}
    {"level":"info","ts":1739356589.1099038,"logger":"controllers.Upgrade","msg":"ProcessValidationRequiredNodes"}
    {"level":"info","ts":1739356589.1099067,"logger":"controllers.Upgrade","msg":"ProcessUncordonRequiredNodes"}
    {"level":"info","ts":1739356589.10991,"logger":"controllers.Upgrade","msg":"State Manager, finished processing"}
    ```

    </details>

    - [ ] Verify that the operator is continuously checking and updating the GPU state for reconciliation messages as shown above
    - [ ] Verify that the operator can successfully complete actions for `upgrade-required`, `cordon-required`, and `pod-deletion-required`. Once completed, ensure that no pending actions are reported
    - [ ] Ensure healthy key processing flow like `ProcessValidationRequiredNodes` and `ProcessUncordonRequiredNodes` run without errors

> [!note]
> As application developer `dev@example.com`

- [ ] Able to deploy the GPU application workload jobs successfully
    <details><summary>Commands</summary>

    ```bash
    kubectl apply -n "${NAMESPACE}" -f - <<EOF
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cuda-vectoradd-job
    spec:
      template:
        metadata:
          labels:
            app: cuda-vectoradd
        spec:
          restartPolicy: OnFailure
          tolerations:
          - key: "elastisys.io/node-type"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
          containers:
          - name: cuda-vectoradd
            image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0-ubuntu22.04
            resources:
              limits:
                nvidia.com/gpu: 1
                memory: 128Mi
                cpu: 500m
              requests:
                memory: 64Mi
                cpu: 250m
            securityContext:
              allowPrivilegeEscalation: false
              runAsNonRoot: true
              runAsUser: 1000
              capabilities:
                drop:
                  - ALL
              seccompProfile:
                type: RuntimeDefault
    EOF
    ```

    </details>
- [ ]  Verify GPU workload scheduled on GPU node

    ```bash
    ./bin/ck8s ops kubectl wc get pods -n "${NAMESPACE}" -l job-name=cuda-vectoradd-job -o wide
    ```

- [ ] Verify GPU resources allocated to the Pod

    ```bash
    ./bin/ck8s ops kubectl wc describe pod <pod-name> -n "${NAMESPACE}"| grep "nvidia.com/gpu"
    ```

- [ ] _With Cluster API_: Verify on-demand GPU node provisioned when requested

    ```bash
    ./bin/ck8s ops kubectl wc get nodes -l elastisys.io/node-type=gpu -o wide
    ```

- [ ] Clean up GPU test Workload

    ```bash
    ./bin/ck8s ops kubectl wc delete job cuda-vectoradd-job -n "${NAMESPACE}"
    ```

- [ ] _With Cluster API_: Verify on-demand GPU node de-provisioned when not used

    ```bash
    ./bin/ck8s ops kubectl wc get nodes -l elastisys.io/node-type=gpu -o wide
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

### <a id="after-qa-steps" href="#user-content-after-qa-steps">#</a> After QA steps

- [ ] Update the Welcoming Dashboards "What's New" section.

  Add items for new feature or changes that are relevant for application developers, e.g. for `v0.25` "- As an application developer you can now create namespaces yourself using HNC ...".

  Remove items for releases older than two major or minor versions, e.g. for `v0.25` you keep items for `v0.25` and `v0.24` and remove all items for all older versions.

    - Edit the [Grafana dashboard](https://github.com/elastisys/compliantkubernetes-apps/tree/main/helmfile.d/charts/grafana-dashboards/files/welcome.md)
    - Edit the [OpenSearch dashboard](https://github.com/elastisys/compliantkubernetes-apps/tree/main/helmfile.d/charts/opensearch/configurer/files/dashboards-resources/welcome.md)

- [ ] Complete [the code freeze step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#code-freeze)
- [ ] The staging pull request must be approved

### <a id="release-steps" href="#user-content-release-steps">#</a> Release steps

- [ ] Complete [the release step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#release)
- [ ] Complete [the update public release notes step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#update-public-release-notes)
- [ ] Complete [the update main branch step](https://github.com/elastisys/compliantkubernetes-apps/tree/main/release#update-the-main-branch)

### <a id="final-steps" href="#user-content-final-steps">#</a> Final steps
