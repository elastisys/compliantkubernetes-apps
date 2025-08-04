function opensearchDexStaticLogin(cy, ingress) {
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
  // TODO: This is copied from opensearch tests. Move it to cypress/opensearch.js for modularity
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
}

describe('falco', function () {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')
  })

  after(function () {
    Cypress.session.clearAllSavedSessions()
  })

  beforeEach(function () {
    opensearchDexStaticLogin(cy, this.ingress)
    cy.on('uncaught:exception', (err, runnable) => {
      if (err.message.includes("Cannot read properties of undefined (reading 'split')")) {
        return false
      } else if (err.message.includes('location.href.split(...)[1] is undefined')) {
        return false
      }
    })
  })

  it('logs are available in opensearch dashboard', function () {
    cy.contains('title', 'menu', { matchCase: false }).parents('button').click()

    // Navigate to Dashboards
    cy.get('nav').contains('li', 'dashboard', { matchCase: false }).click()
    cy.contains('loading opensearch dashboards', { matchCase: false }).should('not.exist')

    // Navigate to Logging overview (Audit/Falco)
    cy.contains('a', 'logging overview (audit/falco)', { matchCase: false }).click()
    cy.contains('loading opensearch dashboards', { matchCase: false }).should('not.exist')

    // Assert contains falco logs
    const panelTitle = 'Falco logs'
    cy.contains('.embPanel__title .embPanel__titleText', panelTitle)
      .should('be.visible')
      .closest('.embPanel') //Locate the panel
      .within(() => {
        cy.get('.embPanel__content').should('not.have.attr', 'data-loading', 'true')
        cy.contains('No results found', { matchCase: false }).should('not.exist')
      })
  })
})
