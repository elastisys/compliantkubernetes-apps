import '../../common/cypress/grafana.js'

describe('grafana admin dashboards', function () {
  before(function () {
    cy.yq('sc', '.grafana.ops.subdomain + "." + .global.opsDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.ops.trailingDots').should('not.equal', 'true')
  })

  beforeEach(function () {
    cy.grafanaDexStaticLogin(`${this.ingress}/dashboards`)
  })

  after(function () {
    Cypress.session.clearAllSavedSessions()
  })

  it('open the Backup status dashboard', function () {
    cy.testGrafanaDashboard('Backup status', false)

    cy.get(
      '[data-testid="data-testid dashboard-row-title-Time since last successful backup"]'
    ).should('exist')
  })

  it('open the Trivy Operator Dashboard', function () {
    cy.testGrafanaDashboard('Trivy Operator Dashboard', false)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]').should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard('NetworkPolicy Dashboard', false)

    cy.get(
      '[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]'
    ).should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard('Kubernetes cluster status', false)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]').should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard('Gatekeeper', false)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]').should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard('NGINX Ingress controller', false)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]').should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard('Falco', false)

    cy.get('[data-testid="data-testid Panel header Falco logs"]').should('exist')
  })
})
