// ToDo set up the baseUrl here and drop the baseUrl alias
describe("grafana-admin dashboards e2e", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as('baseUrl')
  })
  beforeEach(function() {
    cy.staticLogin("admin", ".grafana.password", "user", "password", this.baseUrl + '/login', 'orgId', 'grafana_session_expiry')
  })

  it('landing page navigation toolbar is visible', function () {
    cy.intercept("/api/**").as("api")
    cy.visit(this.baseUrl + '/?orgId=1')
    cy.wait(Array(5).fill('@api'))
    cy.get('[data-testid="data-testid Nav toolbar"]').should('exist')
  })

  it('open the Backup status dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'Backup status', 12)

    cy.get('[data-testid="data-testid dashboard-row-title-Time since last successful backup"]').should('exist')
  })

  it('open the Trivy Operator Dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'Trivy Operator Dashboard', 12)

    cy.get('[data-testid="data-testid Panel menu Security Overview"]').should('exist')
  })

  it('open the NetworkPolicy Dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'NetworkPolicy Dashboard', 12)

    cy.get('[data-testid="data-testid Panel menu Packets allowed by NetworkPolicy going from pod"]').should('exist')
  })

  it('open the Kubernetes cluster status dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'Kubernetes cluster status', 18)

    cy.get('[data-testid="data-testid Panel menu Running pods not ready"]').should('exist')
  })

  it('open the Gatekeeper dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'Gatekeeper', 12)

    cy.get('[data-testid="data-testid Panel header Gatekeeper logs"]').should('exist')
  })

  it('open the NGINX Ingress controller dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'NGINX Ingress controller', 22)

    cy.get('[data-testid="data-testid Panel header Controller Request Volume"]').should('exist')
  })

  it('open the Falco dashboard', function () {
    cy.testGrafanaDashboard(this.baseUrl, 'Falco', 16)

    cy.get('[data-testid="data-testid Panel header Falco logs"]').should('exist')
  })

})
