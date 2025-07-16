// End-to-end test: Harbor Dex auth
// Same as integration test without local-cluster setup

import '../../common/cypress/harbor.js'

describe('harbor dex auth', () => {
  before(() => {
    cy.yq('sc', '.harbor.subdomain + "." + .global.baseDomain').should('not.be.empty').as('ingress')
  })

  it('can login via static admin user', () => {
    cy.harborAdminLogin(this.ingress)
  })

  it('can login via static dex user', () => {
    cy.yqDig('sc', '.dex.enableStaticLogin').then((staticLoginEnabled) => {
      if (staticLoginEnabled !== 'true') {
        this.skip('dex static login is not enabled')
      }
    })

    cy.harborStaticDexLogin(this.ingress)
  })

  it('can promote static dex user to admin', () => {
    cy.yqDig('sc', '.dex.enableStaticLogin').then((staticLoginEnabled) => {
      if (staticLoginEnabled !== 'true') {
        this.skip('dex static login is not enabled')
      }
    })

    cy.harborAdminLogin(this.ingress)

    cy.harborStaticDexPromote(this.ingress)
  })
})
