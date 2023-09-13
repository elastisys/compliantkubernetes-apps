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
})
