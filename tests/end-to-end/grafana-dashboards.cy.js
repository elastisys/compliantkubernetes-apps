import "../common/lib/grafana.js"

describe("grafana admin dashboards", function() {
  before(function() {
    cy.yq("sc", ".grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
      .should("not.equal", "true")
  })

  beforeEach(function() {
    cy.grafanaDexStaticLogin(this.ingress)

    cy.contains("Welcome to Grafana")
      .should("exist")
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  it('open the Backup status dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Backup status', false, 18)

    cy.get('[data-testid="data-testid dashboard-row-title-Time since last successful backup"]')
      .should('exist')
  })

  it('open the Trivy Operator Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Trivy Operator Dashboard', false, 18)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]')
      .should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NetworkPolicy Dashboard', false, 15)

    cy.get('[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]')
      .should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Kubernetes cluster status', false, 32)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]')
      .should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Gatekeeper', false, 16)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]')
      .should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NGINX Ingress controller', false, 30)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]')
      .should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Falco', 21)

    cy.get('[data-testid="data-testid Panel header Falco logs"]')
      .should('exist')
  })
})

describe("grafana dev dashboards", function() {
  before(function() {
    cy.yq("sc", ".grafana.user.subdomain + \".\" + .global.baseDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.user.trailingDots")
      .should("not.equal", "true")
  })

  beforeEach(function() {
    cy.grafanaDexStaticLogin(this.ingress)

    cy.contains("Welcome to Compliant Kubernetes")
      .should("exist")
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  // this test will fail as some backup-us are not present in wc
  // it('open the Backup status dashboard', function () {
  //   cy.testGrafanaDashboard(this.ingress, 'Backup status', 20)
  //
  //   cy.get('[data-testid="data-testid dashboard-row-title-Time since last successful backup"]')
  //     .should('exist')
  // })

  it('open the Trivy Operator Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Trivy Operator Dashboard', true, 20)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]')
      .should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NetworkPolicy Dashboard', false, 14)

    cy.get('[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]')
      .should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Kubernetes cluster status', false, 30)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]')
      .should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Gatekeeper', 18)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]')
      .should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'NGINX Ingress controller', false, 30)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]')
      .should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard(this.ingress, 'Falco', false, 21)

    cy.get('[data-testid="data-testid Panel header Falco logs"]')
      .should('exist')
  })
})
