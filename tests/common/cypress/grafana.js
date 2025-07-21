// Available as cy.testGrafanaDashboard("grafana.example.com", "the names of the Grafana dashboard", "to look for and expandRows rows", "the no of completed api req to wait")
Cypress.Commands.add('testGrafanaDashboard', (ingress, dashboardName, expandRows) => {
  // View and load as much of the dashboard as possible
  cy.viewport(1920, 2560)

  // The dashboard view in Grafana need a scroll action to load all the dashboard names
  cy.contains('Kubernetes').trigger('wheel', {
    deltaY: -66.666666,
    wheelDelta: 120,
    wheelDeltaX: 0,
    wheelDeltaY: 120,
    bubbles: true,
  })

  // Navigate to the dashboard
  cy.contains(dashboardName).click()

  // Wait for the dashboard to load
  cy.contains(dashboardName)

  // Check that the datasource selector exists and is the default
  cy.get('[data-testid="data-testid dashboard controls"]')
    .contains('datasource')
    .should('exist')
    .siblings()
    .contains('default')
    .should('exist')

  // Check that the cluster selector exists
  cy.get('[data-testid="data-testid dashboard controls"]').contains('cluster').should('exist')

  // Expand all dashboard rows
  if (expandRows === true) {
    cy.get('[data-testid="dashboard-row-container"] > [aria-expanded="false"]').each((element) => {
      cy.wrap(element).click()
    })
  }

  // Wait for dashboards to load: loading indicators should appear, but then begone
  cy.get('[aria-label="Refresh"]').should('exist').as('refresh')
  cy.get('@refresh').click()
  cy.get('[aria-label="Panel loading bar"]').should('exist')
  cy.get('[aria-label="Panel loading bar"]').should('not.exist')

  // After all graphs have loaded, search for text
  // Some dashboards will contain "No data" because an overwrite for NaN or Null doesn't exist
  cy.contains('No data').should('not.exist')
})

// Available as cy.grafanaDexStaticLogin("grafana.example.com")
Cypress.Commands.add('grafanaDexStaticLogin', (ingress) => {
  cy.session([ingress], () => {
    cy.visit(`https://${ingress}`)

    cy.contains('Sign in with dex').click()

    cy.dexStaticLogin()

    cy.getCookie('grafana_session_expiry').should('exist')

    cy.contains('Home').should('exist')
  })

  cy.visit(`https://${ingress}`)

  cy.contains('Home').should('exist')
})
