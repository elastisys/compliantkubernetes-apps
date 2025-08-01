import '../../common/cypress/opensearch.js'

describe('opensearch admin authentication', () => {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')
  })

  it('can login via static dex user', function () {
    cy.opensearchDexStaticLogin(this.ingress)
  })
})
