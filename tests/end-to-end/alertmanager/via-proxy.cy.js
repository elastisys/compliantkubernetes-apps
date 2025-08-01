describe('workload cluster alertmanager', function () {
  it('can be accessed via kubectl proxy', () => {
    cy.visitProxiedWc(
      'http://127.0.0.1:8001/api/v1/namespaces/alertmanager/services/alertmanager-operated:9093/proxy/'
    )

    // Note the change of origin is needed because we got here via a redirect
    cy.origin('http://127.0.0.1:8001', () => {
      cy.contains('span', 'alertname="Watchdog"').should('exist')
    })
  })

  after(() => {
    cy.cleanupProxy('wc')
  })
})

describe('service cluster alertmanager', function () {
  it('can be accessed via kubectl proxy', () => {
    cy.visitProxiedSc(
      'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/alertmanager-operated:9093/proxy/'
    )

    cy.contains('span', 'alertname="Watchdog"').should('exist')
  })

  after(() => {
    cy.cleanupProxy('sc')
  })
})
