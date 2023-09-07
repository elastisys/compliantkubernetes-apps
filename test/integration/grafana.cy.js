describe("grafana integration", function() {
  beforeEach(function() {
    cy.yq("sc", "\"https://\" + .grafana.ops.subdomain + \".\" + .global.opsDomain")
      .its("stdout")
      .should("not.contain", "null")
      .then(cy.visit)
  })

  it("should fail", function() {
    cy.contains("Welcome to Grafana")
      .should("not.exist")
  })

  it("should pass", function() {
    cy.contains("Welcome to Grafana")
      .should("exist")
  })

  it("should skip", function() {
    this.skip() // Example based on config: cy.skipOnDisabled("sc", "config.key")
  })
})
