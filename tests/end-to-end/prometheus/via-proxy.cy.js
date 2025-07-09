describe("prometheus", function() {
  it("can be accessed via kubectl proxy", () => {
    cy.visitProxied(
      "wc",
      "static-dev",
      "true",
      "http://127.0.0.1:8001/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/targets?pool=serviceMonitor%2Fmonitoring%2Fkube-prometheus-stack-apiserver%2F0"
    )

    cy.origin("http://127.0.0.1:8001", () => {
      cy.contains("span", "up")
        .should("exist")
    })
  })

  after(() => {
    cy.cleanupProxy("wc", "static-dev")
  })
})
