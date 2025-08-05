describe('falco', function () {
  const alertmanagerUrl =
    'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/alertmanager-operated:9093/proxy'

  it('alerts are triggered and are relevant', function () {
    cy.fixture('falco-event-generator-actions.json').then((expectedAlertRules) => {
      const normalize = (str) => str.toLowerCase().replace(/[^a-z0-9]/g, '')
      const normalizedExpectedAlertRules = new Set(expectedAlertRules.map(normalize))

      cy.request({
        method: 'GET',
        url: `${alertmanagerUrl}/api/v2/alerts`,
        headers: { Accept: 'application/json' },
      }).then((response) => {
        expect(response.status).to.eq(200)

        // Extract just the falco rules in firing alerts from the response body
        const receivedFalcoAlerts = response.body.filter(
          (alert) => alert.labels.alertname === 'FalcoAlert'
        )
        expect(receivedFalcoAlerts).to.not.be.empty

        const unexpectedFalcoAlertRules = Array.from(
          new Set(
            receivedFalcoAlerts
              .map((alert) => alert.labels.rule)
              .filter((alert) => !normalizedExpectedAlertRules.has(normalize(alert)))
          )
        ).toSorted()

        // Assert all received falco alerts are triggered by event-generator syscalls
        expect(
          unexpectedFalcoAlertRules,
          `Received unexpected falco alerts: ${unexpectedFalcoAlertRules.join(', ')}`
        ).to.be.an('array').that.is.empty
      })
    })
  })
})
