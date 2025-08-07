import '../../common/cypress/opensearch'

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
    cy.opensearchDexStaticLogin(this.ingress)
    cy.on('uncaught:exception', (error) => {
      if (
        error.message.includes("Cannot read properties of undefined (reading 'split')") ||
        error.message.includes('location.href.split(...)[1] is undefined')
      ) {
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
      .closest('.embPanel') // Locate the panel
      .within(() => {
        cy.get('.embPanel__content').should('not.have.attr', 'data-loading', 'true')
        cy.contains('No results found', { matchCase: false }).should('not.exist')
      })
  })
})
