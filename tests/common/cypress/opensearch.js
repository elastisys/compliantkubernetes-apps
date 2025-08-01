Cypress.Commands.add('opensearchDexStaticLogin', (ingress) => {
  // Need to ignore error response from GET /api/dataconnections for non-authorized user.
  //
  // {
  //     "statusCode": 403,
  //     "error": "Forbidden",
  //     "message": "{
  //         "status": 403,
  //       "error": {
  //           "type": "OpenSearchSecurityException",
  //         "reason": "There was internal problem at backend",
  //         "details": "no permissions for [cluster:admin/opensearch/ql/datasources/read] and User [name=admin@example.com, backend_roles=[], requestedTenant=null]"
  //       }
  //   }"
  // }
  //
  // TODO: Narrow this down to the specific request OR investigate if a user
  //       actually should have this permission.
  cy.on('uncaught:exception', (err, runnable) => {
    if (err.message.includes('Forbidden')) {
      return false
    }
  })

  cy.session([ingress], () => {
    cy.visit(`https://${ingress}`)

    cy.dexStaticLogin()

    cy.contains('loading opensearch dashboards', { matchCase: false }).should('not.exist')

    cy.contains('Welcome to Welkin').should('be.visible')
  })

  cy.visit(`https://${ingress}`)

  cy.contains('loading opensearch dashboards', { matchCase: false }).should('not.exist')

  cy.contains('Welcome to Welkin').should('be.visible')
})

Cypress.Commands.add('opensearchTestIndexPattern', (indexPattern) => {
  // open sidebar menu
  cy.contains('title', 'menu', { matchCase: false }).parents('button').click()

  // navigate to discover
  cy.get('nav').contains('li', 'discover', { matchCase: false }).click()

  // select index pattern
  cy.contains('div', 'kubeaudit*').click()
  cy.contains('button', indexPattern).click()

  cy.contains('no results match your search criteria', { matchCase: false }).should('not.exist')

  cy.contains('hits', { matchCase: false }).should('be.visible')
})
