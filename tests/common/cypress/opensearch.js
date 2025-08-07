Cypress.Commands.add('opensearchDexStaticLogin', (ingress) => {
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
