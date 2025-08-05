import '../../common/cypress/grafana.js'

function loginNavigate(cy, ingress, passwordKey) {
  cy.session(ingress, () => {
    cy.visit(`https://${ingress}`)

    cy.contains('Welcome to Grafana').should('exist')

    cy.yqSecrets(passwordKey).then((password) => {
      cy.get('input[placeholder*="username"]').type('admin', { log: false })

      cy.get('input[placeholder*="password"]').type(password, { log: false })

      cy.get('button').contains('Log in').click()
    })

    cy.contains('Home').should('exist')
  })

  cy.visit(`https://${ingress}`)

  cy.contains('Home').should('exist')

  cy.on('uncaught:exception', (err, _runnable) => {
    if (err.statusText.includes('Request was aborted')) {
      return false
    }
  })

  cy.get('button[aria-label="Open menu"]').click()

  cy.get('button[aria-label="Expand section: Connections"]').click()

  cy.contains('Data sources').click()
}

describe('grafana admin datasources', function () {
  before(function () {
    cy.yq('sc', '.grafana.ops.subdomain + "." + .global.opsDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.ops.trailingDots').should((value) =>
      assert(value !== 'true', ".grafana.ops.trailingDots in sc config must not be 'true'")
    )
  })

  beforeEach(function () {
    loginNavigate(cy, this.ingress, '.grafana.password')
  })

  after(() => {
    Cypress.session.clearAllSavedSessions()
  })

  it('has prometheus', () => {
    cy.contains('prometheus-sc').should('exist')
  })

  it('has thanos all', () => {
    cy.contains('Thanos All')
      .should('exist')
      .parent()
      .siblings()
      .contains('default')
      .should('exist')
  })

  it('has thanos sc', () => {
    cy.contains('Thanos SC Only').should('exist')
  })

  it('has thanos wc', () => {
    cy.yqDigParse('sc', '.global.clustersMonitoring').then((clusters) => {
      for (const cluster of clusters) {
        cy.contains(`Thanos ${cluster} only`).should('exist')
      }
    })
  })
})

describe('grafana dev datasources', () => {
  before(function () {
    cy.yq('sc', '.grafana.user.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.user.trailingDots').should((value) =>
      assert(value !== 'true', ".grafana.user.trailingDots in sc config must not be 'true'")
    )
  })

  beforeEach(function () {
    loginNavigate(cy, this.ingress, '.user.grafanaPassword')
  })

  after(() => {
    Cypress.session.clearAllSavedSessions()
  })

  it('has service cluster', () => {
    cy.contains('Service Cluster').should('exist')
  })

  it('has workload cluster', () => {
    cy.yqDigParse('sc', '.global.clustersMonitoring').then(([first_cluster, ...rest_clusters]) => {
      cy.contains(`Workload Cluster${rest_clusters.length === 0 ? '' : ' ' + first_cluster}`)
        .should('exist')
        .parent()
        .siblings()
        .contains('default')
        .should('exist')

      for (const cluster of rest_clusters) {
        cy.contains(`Workload Cluster ${cluster}`).should('exist')
      }
    })
  })
})
