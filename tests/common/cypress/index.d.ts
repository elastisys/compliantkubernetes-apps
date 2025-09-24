type Cluster = 'sc' | 'wc'
type GrafanaRole = 'Admin' | 'Editor' | 'Viewer'

declare const yqArgumentsToConfigFiles: (cluster: Cluster, expression: string) => string
declare const userToSession: (user: string) => string

/// <reference types="cypress" />

declare namespace Cypress {
  interface Chainable<Subject> {
    /**
     * Apparently this was removed in Cypress v10...
     */
    fail(message: string): void

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
     * cy.retryRequest({
     *   request: {
     *     url: 'http://example.com',
     *     headers: { Accept: 'application/json' },
     *     failOnStatusCode: false,
     *   },
     *   condition: (response) => response.status === 200,
     *   body: (response) => {
     *     expect(response.body).to.be.an('array')
     *   },
     *   attempts: 12,
     * })
     */
    retryRequest(arguments_: {
      request: Partial<RequestOptions>
      condition: (Response) => bool
      body?: (Response) => void
      attempts?: number
      waitTime?: number
    }): Chainable<any>

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
     * cy.withTestKubeconfig({ session: 'static-admin', refresh: true })
     */
    withTestKubeconfig(arguments_: {
      session: string
      url?: string
      refresh: boolean
    }): Chainable<string>

    /**
     * @example
     * cy.deleteTestKubeconfig('static-admin' )
     */
    deleteTestKubeconfig(session: string): Chainable<any>

    /**
     * @example
     * cy.visitAndVerifyCSPHeader('https://grafana.domain')
     */
    visitAndVerifyCSPHeader(url: string, interceptUrl?: string, doDexLogin?: boolean): Chainable<any>

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

    /**
     * @example
     * cy.opensearchDexStaticLogin('https://opensearch.domain')
     */
    opensearchDexStaticLogin(ingress: string): Chainable<any>

    /**
     * @example
     * cy.opensearchTestIndexPattern('indexPattern')
     */
    opensearchTestIndexPattern(indexPattern: string): Chainable<any>
  }
}
