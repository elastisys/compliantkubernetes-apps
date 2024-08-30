import "../../common/cypress/grafana.js"

describe("grafana admin datasources", function() {
  before(function() {
    cy.yq("sc", ".grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
      .should("not.equal", "true")
  })

  beforeEach(function() {
    cy.grafanaDexStaticLogin(this.ingress)

    cy.contains("Welcome to Grafana")
      .should("exist")

    cy.on('uncaught:exception', (err, runnable) => {
      if (err.statusText.includes("Request was aborted")) {
        return false
      }
    })

    cy.get('button[aria-label="Open menu"]')
      .click()

    cy.get('button[aria-label="Expand section Connections"]')
      .click()

    cy.contains("Data sources")
      .click()
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  it("has prometheus", function() {
    cy.contains("prometheus-sc")
      .should("exist")
  })

  it("has thanos all", function() {
    cy.contains("Thanos All")
      .should("exist")
      .siblings()
      .contains("default")
      .should("exist")
  })

  it("has thanos sc", function() {
    cy.contains("Thanos SC Only")
      .should("exist")
  })

  it("has thanos wc", function() {
    cy.yqDigParse("sc", ".global.clustersMonitoring")
      .then(clusters => {
        for (const cluster of clusters) {
          cy.contains(`Thanos ${cluster} only`)
            .should("exist")
        }
      })
  })
})

describe("grafana dev datasources", function() {
  before(function() {
    cy.yq("sc", ".grafana.user.subdomain + \".\" + .global.baseDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.user.trailingDots")
      .should("not.equal", "true")
  })

  beforeEach(function() {
    cy.grafanaDexStaticLogin(this.ingress)

    cy.contains("Welcome to Compliant Kubernetes")
      .should("exist")

    cy.on('uncaught:exception', (err, runnable) => {
      if (err.statusText.includes("Request was aborted")) {
        return false
      }
    })

    cy.get('button[aria-label="Open menu"]')
      .click()

    cy.get('button[aria-label="Expand section Connections"]')
      .click()

    cy.contains("Data sources")
      .click()
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  it("has service cluster", function() {
    cy.contains("Service Cluster")
      .should("exist")
  })

  it("has workload cluster", function() {
    cy.contains("Workload Cluster")
      .should("exist")
      .siblings()
      .contains("default")
      .should("exist")
  })
})
