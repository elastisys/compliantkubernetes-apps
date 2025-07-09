describe('kubernetes authentication', function () {
  before(function () {
    cy.withTestKubeconfig({ cluster: 'wc', user: 'static-dev', refresh: 'true' })
  })

  after(function () {
    cy.deleteTestKubeconfig({ cluster: 'wc', user: 'static-dev' })
  })

  it('can login via extra static dex user', function () {
    cy.task('kubectlLogin', Cypress.env('KUBECONFIG'))
    cy.visit(`http://localhost:8000`)

    cy.dexExtraStaticLogin('dev@example.com')

    cy.origin('http://localhost:8000', () => {
      cy.contains('Authenticated').should('exist')

      cy.contains('You have logged in to the cluster. You can close this window.').should('exist')
    })
  })
})
