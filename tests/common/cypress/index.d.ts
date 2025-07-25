/// <reference types="cypress" />

declare namespace Cypress {
  interface Chainable<Subject> {
    /**
     * @example
     *  cy.yq('sc', '.harbor.subdomain')
     */
    yq(cluster: string, expression: string): Chainable<string>

    /**
     * @example
     *  cy.yqDig('sc', '.grafana.ops.trailingDots')
     */
    yqDig(cluster: string, expression: string): Chainable<string>

    /**
     * @example
     * cy.yqDigParse('sc', '.grafana.user.oidc.allowedDomains')
     */
    yqDigParse(cluster: string, expression: string): Chainable<any>

    /**
     * @example
     * cy.yqSecrets('.grafana.password')
     */
    yqSecrets(expression: string): Chainable<string>

    /**
     * @example
     * cy.continueOn('sc', '.harbor.enabled')
     */
    continueOn(cluster: string, expression: string): Chainable<any>

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
     *   user: 'static-dev',
     *   url: 'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/targets?pool=serviceMonitor%2Fmonitoring%2Fkube-prometheus-stack-apiserver%2F0',
     *   refresh: 'true',
     *   checkAdmin: true,
     * })
     */
    visitProxied(args: {
      cluster: string
      user: string
      url: string
      refresh: boolean
      checkAdmin?: boolean
    }): Chainable<any>

    /**
     * @example
     * cy.cleanupProxy({ cluster: 'sc', user: 'static-admin' })
     */
    cleanupProxy(args: { cluster: string; user: string }): Chainable<any>

    /**
     * @example
     * cy.withTestKubeconfig('sc', 'static-admin', true)
     */
    withTestKubeconfig(args: {
      cluster: string
      user: string
      url?: string
      refresh: boolean
    }): Chainable<string>

    /**
     * @example
     * cy.deleteTestKubeconfig({ cluster: 'sc', user: 'static-admin' })
     */
    deleteTestKubeconfig(args: { cluster: string; user: string }): Chainable<any>
  }
}
