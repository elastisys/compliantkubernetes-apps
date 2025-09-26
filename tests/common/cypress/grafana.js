// Available as cy.testGrafanaDashboard("grafana.example.com", "the names of the Grafana dashboard", "to look for and expandRows rows", "the no of completed api req to wait")
Cypress.Commands.add('testGrafanaDashboard', (dashboardName, expandRows) => {
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

  cy.intercept('POST', '/api/ds/query**').as('query')

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
    cy.get('[aria-label="Expand row"]').each((element) => {
      cy.wrap(element).click({ force: true })
    })
  }

  // Wait for the first Datasource query to complete just to be on the safe side
  cy.wait('@query').its('response.statusCode').should('eq', 200)

  // Wait for panels to load - all panel divs should have descendants
  cy.get('[data-testid~="panel"][data-testid~="content"]').each(($div) => {
    cy.wrap($div).find('>div').should('exist')
  })

  // After all graphs have loaded, search for text
  // Some dashboards will contain "No data" because an overwrite for NaN or Null doesn't exist
  cy.contains('No data').should('not.exist')
})

// Available as cy.grafanaDexStaticLogin("grafana.example.com")
Cypress.Commands.add('grafanaDexStaticLogin', (ingress, cacheSession = true) => {
  const login = function () {
    cy.visitAndVerifyCSPHeader(`https://${ingress}`)

    cy.contains('Sign in with dex').click()

    cy.dexStaticLogin()

    return cy.getCookie('grafana_session_expiry').should('exist')
  }

  if (cacheSession) {
    cy.session([ingress], login)
    cy.visitAndVerifyCSPHeader(`https://${ingress}`)
  } else {
    login()
  }
  return cy.wrap(true)
})

// Available as cy.grafanaDexStaticLogin("grafana.example.com", "dev@example.com")
Cypress.Commands.add('grafanaDexExtraStaticLogin', (ingress, staticUser) => {
  cy.visitAndVerifyCSPHeader(`https://${ingress}`)

  cy.contains('Sign in with dex').click()

  cy.dexExtraStaticLogin(staticUser)

  cy.getCookie('grafana_session_expiry').should('exist')

  return cy.wrap(true)
})

// Available as cy.grafanaSetRole(ingress, '.user.grafanaPassword', 'dev@example.com', 'Viewer')
Cypress.Commands.add('grafanaSetRole', (ingress, adminPasswordKey, user, role) => {
  // Log in as the grafana admin and change the role
  cy.session([`${ingress}/admin/users`], function () {
    cy.visitAndVerifyCSPHeader(`https://${ingress}`)

    cy.yqSecrets(adminPasswordKey).then((password) => {
      cy.get('input[placeholder*="username"]').type('admin', { log: false })

      cy.get('input[placeholder*="password"]').type(password, { log: false })

      cy.get('button').contains('Log in').click()
    })

    cy.visitAndVerifyCSPHeader(`https://${ingress}/admin/users`)
  })

  cy.visitAndVerifyCSPHeader(`https://${ingress}/admin/users`)
  cy.contains('Organization users').should('be.visible').click()

  // remove TLD, form doesn't seem to like it
  const searchString = user.slice(0, Math.max(0, user.lastIndexOf('.')))
  cy.get('input[placeholder*="Search user by login"]')
    .should('not.be.disabled')
    .type(`${searchString}{enter}`)

  cy.get('[aria-label="Role"]').as('role').focus()
  cy.get('@role').type(`${role}{enter}`)

  return cy.contains('Organization user updated').should('be.visible')
})

// Available as cy.grafanaCheckRole(ingress, 'dev@example.com', 'Admin')
Cypress.Commands.add('grafanaCheckRole', (ingress, user, role) => {
  cy.intercept('/api/user/orgs').as('userOrgs')

  if (user === 'admin@example.com') {
    cy.grafanaDexStaticLogin(`${ingress}/profile`, false)
  } else {
    cy.grafanaDexExtraStaticLogin(`${ingress}/profile`, user)
  }

  cy.wait(['@userOrgs'])

  return cy.get('[data-testid="data-testid-user-orgs-table"]').contains(role).should('exist')
})
