describe('falco', function () {
  const alertmanagerUrl =
    'http://127.0.0.1:18001/api/v1/namespaces/monitoring/services/alertmanager-operated:9093/proxy'

  it('alerts are triggered and are relevant', function () {
    cy.fixture('falco-event-generator-actions.json').then((expectedAlertRules) => {
      const normalize = (string_) => string_.toLowerCase().replaceAll(/[^a-z0-9]/g, '')

      const normalizedExpectedAlertRules = new Set(
        expectedAlertRules.map((element) => normalize(element))
      )

      const extractAlerts = (response) =>
        response.body.filter((alert) => alert.labels.alertname === 'FalcoAlert')

      cy.retryRequest({
        request: {
          method: 'GET',
          url: `${alertmanagerUrl}/api/v2/alerts`,
          headers: { Accept: 'application/json' },
          failOnStatusCode: false,
        },
        condition: (response) => response.status === 200 && extractAlerts(response).length > 0,
        body: (response) => {
          const unexpectedFalcoAlertRules = [
            ...new Set(
              extractAlerts(response)
                .map((alert) => normalize(alert.labels.rule))
                .filter((rule) => !normalizedExpectedAlertRules.has(rule))
            ),
          ].toSorted()

          // Assert all received falco alerts are triggered by event-generator syscalls
          expect(
            unexpectedFalcoAlertRules,
            `Received unexpected falco alerts: ${unexpectedFalcoAlertRules.join(', ')}`
          ).to.be.an('array').that.is.empty
        },
        attempts: 20,
      })
    })
  })
})
