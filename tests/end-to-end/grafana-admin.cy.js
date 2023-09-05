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

  it("has configured data sources", function() {
    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

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
})
