describe('opensearch admin authentication', () => {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')
  })

  it('can login via static dex user', function () {
    cy.continueOn('sc', '.dex.enableStaticLogin')

    cy.visitAndVerifyCSPHeader(`https://${this.ingress}`, '**/app/dashboards**', true)

    cy.contains('Loading OpenSearch Dashboards').should('not.exist')

    cy.contains('Welcome to Welkin').should('exist')
  })
})
