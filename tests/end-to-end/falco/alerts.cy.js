describe('falco', function () {
  const alertmanagerUrl =
    'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/alertmanager-operated:9093/proxy'

  it('alerts are triggered and are relevant', function () {
    cy.fixture('falco-event-generator-actions.json').then((expectedAlertRules) => {
      const normalize = (str) => str.toLowerCase().replace(/[^a-z0-9]/g, '')
      const normalizedExpectedAlertRules = new Set(expectedAlertRules.map(normalize))
      cy.wait(10000) // Wait 10s for deployments to be ready
      const fetchAlerts = (retriesLeft = 5) => {
        cy.request({
          method: 'GET',
          url: `${alertmanagerUrl}/api/v2/alerts`,
          headers: { Accept: 'application/json' },
          failOnStatusCode: false,
        }).then((response) => {
          expect(response.status).to.eq(200)
          const receivedFalcoAlerts = response.body.filter(
            (alert) => alert.labels.alertname === 'FalcoAlert'
          )

          if (receivedFalcoAlerts.length === 0) {
            if (retriesLeft > 0) {
              cy.log(`Request failed or no alerts found. Retrying in 2 seconds...`)
              cy.wait(30000) // Wait 30s before the next attempt
              fetchAlerts(retriesLeft - 1)
              return
            } else {
              cy.wrap(receivedFalcoAlerts).should(
                'not.be.empty',
                `No falco alerts were found after 5 retries.`
              )
            }
          }

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
      }
      fetchAlerts()
    })
  })
})
