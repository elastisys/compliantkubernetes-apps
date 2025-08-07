describe('opensearch admin authentication', () => {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')
  })

  it('can login via static dex user', function () {
    cy.continueOn('sc', '.dex.enableStaticLogin')

    cy.visit(`https://${this.ingress}`)

    cy.dexStaticLogin()

    cy.contains('Loading OpenSearch Dashboards').should('not.exist')

    cy.contains('Welcome to Welkin').should('exist')
  })
})
