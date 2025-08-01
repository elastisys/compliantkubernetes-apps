describe('falco', function () {
  const alertmanagerUrl =
    'http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/alertmanager-operated:9093/proxy'
  const expectedAlertRules = [
    'Clear Log Activities',
    'Create Hardlink Over Sensitive Files',
    'Create Symlink Over Sensitive Files',
    'Directory traversal monitored file read',
    'Disallowed SSH Connection Non Standard Port',
    'Drop and execute new binary in container',
    'Execution from /dev/shm',
    'Fileless execution via memfd_create',
    'Find AWS Credentials',
    'Netcat Remote Code Execution in Container',
    'PTRACE anti-debug attempt',
    'PTRACE attached to process',
    'Packet socket created in container',
    'Remove Bulk Data from Disk',
    'Run shell untrusted',
    'Search Private Keys or Passwords',
  ]

  it('alerts are triggered and are relevant', function () {
    cy.request({
      method: 'GET',
      url: `${alertmanagerUrl}/api/v2/alerts`,
      headers: { Accept: 'application/json' },
    }).then((response) => {
      expect(response.status).to.eq(200)

      // Extract just the falco rules in firing alerts from the response body
      const receivedFalcoAlerts = response.body.filter(
        (alert) => alert.labels.alertname == 'FalcoAlert'
      )

      const receivedFalcoAlertRules = receivedFalcoAlerts.map((alert) => alert.labels.rule)
      // For each expected rule, assert that it is included in the list of received alerts
      expectedAlertRules.forEach((expectedRule) => {
        expect(receivedFalcoAlertRules).to.include(expectedRule)
      })
    })
  })
})
