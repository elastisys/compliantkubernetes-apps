describe("kubernetes authentication", function() {
  before(function() {
    cy.withTestKubeconfig("wc", "static-dev", "true")
  })

  it("can login via extra static dex user", function() {

    cy.yqDig("sc", ".dex.enableStaticLogin")
      .then(staticLoginEnabled => {
        if (staticLoginEnabled !== "true") {
          this.skip("dex static login is not enabled")
        }
      })

    cy.task('kubectlLogin', Cypress.env("KUBECONFIG"))
    cy.visit(`http://localhost:8000`)

    cy.dexExtraStaticLogin("dev@example.com")

    cy.origin('http://localhost:8000', () => {
      cy.contains("Authenticated")
        .should("exist")

      cy.contains("You have logged in to the cluster. You can close this window.")
        .should("exist")
    })
  })
})
