describe("grafana static dex user datasources test", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as('baseUrl')
  })
  beforeEach(function() {
    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
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

    cy.contains("Latest from the blog")
      .parent()
      .parent()
      .contains("Loading")
      .should("not.exist")

    cy.contains("Connections")
      .click()

    cy.contains("Data sources")
      .click()

    cy.contains("prometheus-sc")
      .should("exist")
    cy.contains("Thanos All")
      .should("exist")
      .parent()
      .contains("default")
      .should("exist")
    cy.contains("Thanos SC Only")
      .should("exist")
    cy.yqDigParse("sc", ".global.clustersMonitoring")
      .then(clusters => {
        for (const cluster of clusters) {
          cy.contains(`Thanos ${cluster} only`)
            .should("exist")
        }
      })
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })
})
