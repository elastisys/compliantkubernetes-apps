describe("alertmanager", function() {
  it("can be accessed via kubectl proxy", () => {
    cy.intercept("/api/**")
      .as("api")

    cy.visitProxied(
      "wc",
      "static-dev",
      "true",
      "http://127.0.0.1:8001/api/v1/namespaces/alertmanager/services/alertmanager-operated:9093/proxy/"
    )

    cy.origin("http://127.0.0.1:8001", () => {
      cy.contains("span", 'alertname="Watchdog"')
        .should("exist")

      cy.visit("http://127.0.0.1:8001/api/v1/namespaces/alertmanager/services/alertmanager-operated:9093/proxy/#/status")

      cy.wait(['@api', '@api'], {timeout: 20000})

      cy.contains("span", "ready").should("exist")
    })
  })

  after(() => {
    cy.cleanupProxy("wc", "static-dev")
  })
})
