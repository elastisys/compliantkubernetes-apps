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
    cy.grafanaDexStaticLogin(this.ingress)

    cy.contains('Welcome to Welkin').should('exist')
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
    cy.testGrafanaDashboard(this.ingress, 'Trivy Operator Dashboard', false, 20)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]').should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NetworkPolicy Dashboard', false, 14)

    cy.get(
      '[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]'
    ).should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Kubernetes cluster status', false, 30)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]').should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Gatekeeper', 18)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]').should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NGINX Ingress controller', false, 26)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]').should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Falco', false, 21)

    cy.get('[data-testid="data-testid Panel header Falco logs"]').should('exist')
  })
})
