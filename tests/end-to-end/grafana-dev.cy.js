describe("grafana dev", function() {
  beforeEach(function() {
    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.user.trailingDots")
      .should("not.equal", "true")

    cy.yq("sc", "\"https://\" + .grafana.user.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .then(cy.visit)
  })

  it("can login via dex with static user", function() {
    cy.url()
      .should("include", "/login")

    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

    cy.contains("Home")
      .should("exist")
  })

  it("has configured data sources", function() {
    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

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
})
