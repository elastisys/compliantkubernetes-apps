describe('workload cluster prometheus', function () {
  it('can be accessed via kubectl proxy', () => {
    cy.visit(
      `http://127.0.0.1:${Cypress.env('WC_PROXY_PORT')}/api/v1/namespaces/monitoring/services` +
        '/kube-prometheus-stack-prometheus:9090/proxy/targets' +
        '?pool=serviceMonitor%2Fmonitoring%2Fkube-prometheus-stack-apiserver%2F0'
    )

    cy.contains('span', 'up').should('exist')
  })
})

describe('service cluster prometheus', function () {
  it('can be accessed via kubectl proxy', () => {
    cy.visit(
      `http://127.0.0.1:${Cypress.env('SC_PROXY_PORT')}/api/v1/namespaces/monitoring/services` +
        '/kube-prometheus-stack-prometheus:9090/proxy/targets' +
        '?pool=serviceMonitor%2Fmonitoring%2Fkube-prometheus-stack-apiserver%2F0'
    )

    cy.contains('span', 'up').should('exist')
  })
})
