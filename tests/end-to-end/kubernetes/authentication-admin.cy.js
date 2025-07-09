describe('kubernetes authentication', function () {
  before(function () {
    cy.withTestKubeconfig({ cluster: 'wc', user: 'static-admin', refresh: 'true' })
  })

  after(function () {
    cy.deleteTestKubeconfig({ cluster: 'wc', user: 'static-admin' })
  })

  it('can login via static dex user', function () {
    cy.yqDig('sc', '.dex.enableStaticLogin').then((staticLoginEnabled) => {
      if (staticLoginEnabled !== 'true') {
        this.skip('dex static login is not enabled')
      }
    })

    cy.task('kubectlLogin', Cypress.env('KUBECONFIG'))
    cy.visit(`http://localhost:8000`)

    cy.dexStaticLogin()

    cy.origin('http://localhost:8000', () => {
      cy.contains('Authenticated').should('exist')

      cy.contains('You have logged in to the cluster. You can close this window.').should('exist')
    })
  })
})
