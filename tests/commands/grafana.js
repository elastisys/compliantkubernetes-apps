// Available as cy.testGrafanaDashboard("baseUrl", "the names of the Grafana dashboard", "the no of completed api req to wait")
Cypress.Commands.add('testGrafanaDashboard', (baseUrl, dashboardName, requestsToWait) => {
  cy.intercept("/api/**").as("api")

  cy.visit(baseUrl + '/dashboards')
  // used to view and load as much of the dashboard as possible
  cy.viewport(2560, 2160)

  cy.contains('General').click()
  cy.contains(dashboardName).click()
  // ToDo: expand all rows
  // not really best practices to target objects by id
  cy.get('[id="var-datasource"]').should('exist').and('contain', 'default')
  //cy.get('[id="var-cluster"]').should('exist')
  // wait until data was loaded by all graphs
  cy.wait(Array(requestsToWait).fill('@api'))
  // after all graphs have loaded, search for text
  // some dashboards will contain "No data" because an overwrite for NaN or Null doesn't exist
  cy.contains('No data').should('not.exist')
})
