// Available as cy.testGrafanaDashboard("grafana.example.com", "the names of the Grafana dashboard", "to look for and expandRows rows", "the no of completed api req to wait")
Cypress.Commands.add('testGrafanaDashboard', (ingress, dashboardName, expandRows, requestsToWait) => {

  cy.intercept("/api/**")
    .as("api")

  // View and load as much of the dashboard as possible
  cy.viewport(1920, 2560)

  cy.visit(`https://${ingress}/dashboards`)

  // The dashboard view in Grafana need a scroll action to load all the dashboard names
  cy.contains('Kubernetes')
    .trigger("wheel", { deltaY: -66.666666, wheelDelta: 120, wheelDeltaX: 0, wheelDeltaY: 120, bubbles: true})

  // Navigate to the dashboard
  cy.contains(dashboardName)
    .click()

  // Wait for the dashboard to load
  cy.contains(dashboardName)

  // Check that the datasource selector exists and is the default
  cy.get("form")
    .contains("datasource")
    .should("exist")
    .siblings()
    .contains("default")
    .should("exist")

  // Check that the cluster selector exists
  cy.get("form")
    .contains("cluster")
    .should("exist")

  // Expand all dashboard rows
  if (expandRows === true) {
    cy.get(".dashboard-row--collapsed")
      .each((element) => {
        cy.wrap(element)
          .click()
      })
  }

  // Wait for dashboards to load
  cy.wait(Array(requestsToWait).fill('@api'))

  // After all graphs have loaded, search for text
  // Some dashboards will contain "No data" because an overwrite for NaN or Null doesn't exist
  cy.contains('No data')
    .should('not.exist')
})

// Available as cy.grafanaDexStaticLogin("grafana.example.com")
Cypress.Commands.add("grafanaDexStaticLogin", (ingress) => {
  cy.session([ingress], () => {
    cy.visit(`https://${ingress}`)

    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

    cy.getCookie("grafana_session_expiry")
      .should('exist')

    cy.contains("Home")
      .should('exist')
  })

  cy.visit(`https://${ingress}`)

  cy.contains("Home")
    .should('exist')
})
