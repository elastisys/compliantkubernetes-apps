import '../../common/cypress/grafana.js'

describe('grafana dev dashboards', function () {
  before(function () {
    cy.yq('sc', '.grafana.user.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.user.trailingDots').should('not.equal', 'true')
  })

  beforeEach(function () {
    cy.grafanaDexStaticLogin(`${this.ingress}/dashboards`)
  })

  after(() => {
    Cypress.session.clearAllSavedSessions()
  })

  // this test will fail as some backup-us are not present in wc
  // it('open the Backup status dashboard', () => {
  //   cy.testGrafanaDashboard(this.ingress, 'Backup status', 20)
  //
  //   cy.get('[data-testid="data-testid dashboard-row-title-Time since last successful backup"]')
  //     .should('exist')
  // })

  it('open the Trivy Operator Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Trivy Operator Dashboard', false)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]').should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NetworkPolicy Dashboard', false)

    cy.get(
      '[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]'
    ).should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Kubernetes cluster status', false)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]').should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Gatekeeper', false)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]').should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NGINX Ingress controller', false)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]').should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Falco', false)

    cy.get('[data-testid="data-testid Panel header Falco logs"]').should('exist')
  })
})
