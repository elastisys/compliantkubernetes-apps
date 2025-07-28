const EXPECTED_ALERTS = new Set(['Watchdog', 'CPUThrottlingHigh', 'FalcoAlert'])

describe('workload cluster alertmanager', function () {
  before(function () {
    cy.visitProxiedWC(makeAlertManagerURL('alertmanager'))
  })

  it('should validate all alert names are from expected set', function () {
    cy.request('GET', makeAlertManagerURL('alertmanager', '/api/v2/alerts')).then(
      assertExpectedAlerts
    )
  })

  after(() => {
    cy.cleanupProxy('wc')
  })
})

describe('service cluster alertmanager', function () {
  before(function () {
    cy.visitProxiedSC(makeAlertManagerURL('monitoring'))
  })

  it('should validate all alert names are from expected set', function () {
    cy.request('GET', makeAlertManagerURL('monitoring', '/api/v2/alerts')).then(
      assertExpectedAlerts
    )
  })

  after(() => {
    cy.cleanupProxy('sc')
  })
})

const makeAlertManagerURL = (namespace, route = '') => {
  return `http://127.0.0.1:8001/api/v1/namespaces/${namespace}/services/alertmanager-operated:9093/proxy${route}`
}

const assertExpectedAlerts = (response) => {
  const extraAlerts = Array.from(
    new Set(
      response.body
        .map((item) => item.labels.alertname)
        .filter((item) => !EXPECTED_ALERTS.has(item))
    )
  ).toSorted()

  expect(extraAlerts, `Unexpected alerts in WC alertmanager: ${extraAlerts.join(', ')}`).to.be.an(
    'array'
  ).that.is.empty
}
