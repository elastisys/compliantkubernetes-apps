describe('alertmanager', function () {
  it('can be accessed via kubectl proxy', () => {
    cy.intercept('/api/**').as('api')

    cy.visitProxied({
      cluster: 'wc',
      user: 'static-dev',
      url: 'http://127.0.0.1:8001/api/v1/namespaces/alertmanager/services/alertmanager-operated:9093/proxy/',
      refresh: true,
      checkAdmin: true,
    })

    cy.origin('http://127.0.0.1:8001', () => {
      cy.contains('span', 'alertname="Watchdog"').should('exist')
    })
  })

  after(() => {
    cy.cleanupProxy({ cluster: 'wc', user: 'static-dev' })
  })
})
