// Available as cy.testOpensearchDashboard("baseUrl", "the names of the Opensearch dashboard")
Cypress.Commands.add('testOpensearchDashboard', (baseUrl, dashboardName) => {
  cy.visit(baseUrl + '/app/dashboards')
  // used to view and load as much of the dashboard as possible
  cy.viewport(2560, 2160)
  // click on the desired dashboard name
  cy.contains(dashboardName).click()
  // check if the desired dashboard name exists on the page
  cy.get('[data-test-subj="breadcrumb last"]').should('exist').and('contain', `${dashboardName}`)
  // check if the search bar exists on the page
  cy.get('[data-test-subj="globalQueryBar"]').should('exist')
})

// Available as cy.testOpensearchIndex("baseUrl", "index pattern")
Cypress.Commands.add('testOpensearchIndex', (baseUrl, indexPattern) => {
  cy.visit(baseUrl + '/app/discover')
  // click to view the index patterns list
  cy.get('[data-test-subj="indexPattern-switch-link"]').should('exist').click()
  // click on the desired index pattern
  cy.get('[data-test-subj="indexPattern-switcher"]').contains(indexPattern).click()
  // if log entries exists and are visible the hits tag should exist
  cy.get('[data-test-subj="discoverQueryHits"]').should('exist')
})
