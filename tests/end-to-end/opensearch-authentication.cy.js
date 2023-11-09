describe("grafana admin authentication", function() {
  before(function() {
    cy.yq("sc", ".opensearch.dashboards.subdomain + \".\" + .global.baseDomain")
      .should("not.contain.empty")
      .as("ingress")
  })

  it("can login via static dex user", function() {
    cy.yqDig("sc", ".dex.enableStaticLogin")
      .then(staticLoginEnabled => {
        if (staticLoginEnabled !== "true") {
          this.skip("dex static login is not enabled")
        }
      })

    cy.visit(`https://${this.ingress}`)

    cy.dexStaticLogin()

    cy.contains("Loading OpenSearch Dashboards")
      .should("not.exist")

    cy.contains("Welcome to Compliant Kubernetes")
      .should("exist")
  })
})
