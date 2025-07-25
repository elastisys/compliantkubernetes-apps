/// <reference types="cypress" />

declare namespace Cypress {
  type Cluster = 'sc' | 'wc'
  type GrafanaRole = 'Admin' | 'Editor' | 'Viewer'

  interface Chainable<Subject> {
    /**
     * @example
     *  cy.yq('sc', '.harbor.subdomain')
     */
    yq(cluster: Cluster, expression: string): Chainable<string>

    /**
     * @example
     *  cy.yqDig('sc', '.grafana.ops.trailingDots')
     */
    yqDig(cluster: Cluster, expression: string): Chainable<string>

    /**
     * @example
     * cy.yqDigParse('sc', '.grafana.user.oidc.allowedDomains')
     */
    yqDigParse(cluster: Cluster, expression: string): Chainable<any>

    /**
     * @example
     * cy.yqSecrets('.grafana.password')
     */
    yqSecrets(expression: string): Chainable<string>

    /**
     * @example
     * cy.continueOn('sc', '.harbor.enabled')
     */
    continueOn(cluster: Cluster, expression: string): Chainable<any>

    /**
     * @example
     * cy.dexStaticLogin()
     */
    dexStaticLogin(): Chainable<any>

    /**
     * @example
     * cy.dexExtraStaticLogin('dev@example.com')
     */
    dexExtraStaticLogin(email: string): Chainable<any>

    /**
     * @example
     * cy.visitProxied({
     *   cluster: 'wc',
     *   user: 'dev@example.com',
     *   url: 'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/targets?pool=serviceMonitor%2Fmonitoring%2Fkube-prometheus-stack-apiserver%2F0',
     *   refresh: true,
     *   checkAdmin: true,
     * })
     */
    visitProxied(args: {
      cluster: Cluster
      user: string
      url: string
      refresh?: boolean
      checkAdmin?: boolean
    }): Chainable<any>

    /**
     * @example
     * cy.cleanupProxy({ cluster: 'sc', user: 'dev@example.com' })
     */
    cleanupProxy(args: { cluster: Cluster; user: string }): Chainable<any>

    /**
     * @example
     * cy.withTestKubeconfig({ cluster: 'sc', session: 'static-admin', refresh: true })
     */
    withTestKubeconfig(args: {
      cluster: Cluster
      session: string
      url?: string
      refresh: boolean
    }): Chainable<string>

    /**
     * @example
     * cy.deleteTestKubeconfig({ cluster: 'sc', session: 'static-admin' })
     */
    deleteTestKubeconfig(args: { cluster: Cluster; session: string }): Chainable<any>

    /**
     * @example
     * cy.testGrafanaDashboard('Kubernetes cluster status', false)
     */
    testGrafanaDashboard(dashboardName: string, expandRows: boolean): Chainable<any>

    /**
     * @example
     * cy.grafanaDexStaticLogin('https://grafana.domain')
     */
    grafanaDexStaticLogin(ingress: string, cacheSession?: boolean): Chainable<any>

    /**
     * @example
     * cy.grafanaDexExtraStaticLogin('https://grafana.domain', 'dev@example.com')
     */
    grafanaDexExtraStaticLogin(ingress: string, staticUser: string): Chainable<any>

    /**
     * @example
     * cy.grafanaSetRole('https://grafana.domain', '.user.grafanaPassword', 'dev@example.com', 'Admin')
     */
    grafanaSetRole(
      ingress: string,
      adminPasswordKey: string,
      user: string,
      role: GrafanaRole
    ): Chainable<any>

    /**
     * @example
     * cy.grafanaCheckRole('https://grafana.domain', 'dev@example.com', 'Admin')
     */
    grafanaCheckRole(ingress: string, user: string, role: GrafanaRole): Chainable<any>

    /**
     * @example
     * cy.harborAdminLogin('https://harbor.domain')
     */
    harborAdminLogin(ingress: string): Chainable<any>

    /**
     * @example
     * cy.harborStaticDexLogin('https://harbor.domain')
     */
    harborStaticDexLogin(ingress: string): Chainable<any>

    /**
     * @example
     * cy.harborStaticDexPromote()
     */
    harborStaticDexPromote(): Chainable<any>
  }
}
