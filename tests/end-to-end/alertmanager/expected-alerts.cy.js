const EXPECTED_ALERTS = new Set(['Watchdog', 'CPUThrottlingHigh', 'FalcoAlert'])

describe('workload cluster alertmanager', function () {
  it('should validate all alert names are from expected set', function () {
    cy.visit(makeAlertManagerURL('wc'))

    cy.contains('span', 'alertname="Watchdog"').should('exist')

    cy.request('GET', makeAlertManagerURL('sc', '/api/v2/alerts')).then(assertExpectedAlerts)
  })
})

describe('service cluster alertmanager', function () {
  it('should validate all alert names are from expected set', function () {
    cy.visit(makeAlertManagerURL('sc'))

    cy.contains('span', 'alertname="Watchdog"').should('exist')

    cy.request('GET', makeAlertManagerURL('sc', '/api/v2/alerts')).then(assertExpectedAlerts)
  })
})

const makeAlertManagerURL = (/** @type {Cluster} */ cluster, route = '') => {
  let port, namespace
  if (cluster === 'sc') {
    port = '18001'
    namespace = 'monitoring'
  } else if (cluster === 'wc') {
    port = '18002'
    namespace = 'alertmanager'
  }
  return `http://127.0.0.1:${port}/api/v1/namespaces/${namespace}/services/alertmanager-operated:9093/proxy${route}`
}

const assertExpectedAlerts = (response) => {
  const extraAlerts = [
    ...new Set(
      response.body
        .filter((item) => item.status.state === 'active')
        .map((item) => item.labels.alertname)
        .filter((item) => !EXPECTED_ALERTS.has(item))
    ),
  ].toSorted()

  expect(extraAlerts, `Unexpected alerts in alertmanager: ${extraAlerts.join(', ')}`).to.be.an(
    'array'
  ).that.is.empty
}
