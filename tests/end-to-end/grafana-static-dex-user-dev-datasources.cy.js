describe("grafana static dev dex user datasources", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .grafana.user.subdomain + \".\" + .global.baseDomain")
      .should("not.contain.empty")
      .as('baseUrl')
  })
  beforeEach(function() {
    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.user.trailingDots")
      .should("not.equal", "true")

    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'grafana_session_expiry')
    cy.on('uncaught:exception', (err, runnable) => {
      if (err.statusText.includes("Request was aborted")) {
        return false
      }
    })
  })

  it('Home is visible', function () {
    cy.visit(this.baseUrl)
    cy.contains("Home")
      .should("exist")
  })

  it("has configured data sources", function() {
    cy.visit(this.baseUrl)

    cy.get("button[aria-label=\"Toggle menu\"]")
      .click()

    cy.contains("Connections")
      .click()
    cy.contains("Data sources")
      .click()

    cy.contains("Service Cluster")
      .should("exist")
    cy.contains("Workload Cluster")
      .should("exist")
      .parent()
      .contains("default")
      .should("exist")
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })
})
