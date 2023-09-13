describe("grafana admin", function() {
  beforeEach(function() {
    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
      .should("not.equal", "true")

    cy.yq("sc", "\"https://\" + .grafana.ops.subdomain + \".\" + .global.opsDomain")
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
})
