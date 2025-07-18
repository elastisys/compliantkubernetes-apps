// End-to-end test: Harbor Dex auth
// Same as integration test without local-cluster setup

import '../../common/cypress/harbor.js'

describe('harbor dex auth', function () {
  before(function () {
    cy.yq('sc', '.harbor.subdomain + "." + .global.baseDomain').should('not.be.empty').as('ingress')
  })

  it('can login via static admin user', function () {
    cy.harborAdminLogin(this.ingress)
  })

  it('can login via static dex user', function () {
    cy.continueOn('sc', '.dex.enableStaticLogin')

    cy.harborStaticDexLogin(this.ingress)
  })

  it('can promote static dex user to admin', function () {
    cy.continueOn('sc', '.dex.enableStaticLogin')

    cy.harborAdminLogin(this.ingress)

    cy.harborStaticDexPromote(this.ingress)
  })
})
