const opt = { matchCase: false }

function opensearchDexStaticLogin(cy, ingress) {
  cy.session([ingress], () => {
    cy.visit(`https://${ingress}`)

    cy.dexStaticLogin()

    cy.contains("loading opensearch dashboards", opt)
      .should("not.exist")

    cy.contains("Welcome to Compliant Kubernetes")
      .should("be.visible")
  })

  cy.visit(`https://${ingress}`)

  cy.contains("loading opensearch dashboards", opt)
  .should("not.exist")

  cy.contains("Welcome to Compliant Kubernetes")
    .should("be.visible")
}

function opensearchTestIndexPattern(cy, indexPattern) {
  // open sidebar menu
  cy.contains("title", "menu", opt)
    .parents("button")
    .click()

  // navigate to discover
  cy.get("nav")
    .contains("li", "discover", opt)
    .click()

  // select index pattern
  cy.contains("div", "kubeaudit*")
    .click()
  cy.contains("button", indexPattern)
    .click()

  cy.contains("no results match your search criteria", opt)
    .should("not.exist")

  cy.contains("hits", opt)
    .should("be.visible")
}

describe("opensearch dashboards", function() {
  before(function() {
    cy.yq("sc", ".opensearch.dashboards.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .as("ingress")

    cy.yqDig("sc", ".opensearch.indexPerNamespace")
      .should("not.be.empty")
      .as('indexPerNamespace')
  })

  beforeEach(function() {
    opensearchDexStaticLogin(cy, this.ingress)

    cy.on('uncaught:exception', (err, runnable) => {
      if (err.message.includes("Cannot read properties of undefined (reading 'split')")) {
        return false
      } else if (err.message.includes('location.href.split(...)[1] is undefined')) {
        return false
      }
    })
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  it("open the audit user dashboard", function() {
    // open sidebar menu
    cy.contains("title", "menu", opt)
      .parents("button")
      .click()

    // navigate to dashboards
    cy.get("nav")
      .contains("li", "dashboard", opt)
      .click()

    cy.contains("loading opensearch dashboards", opt)
      .should("not.exist")

    // navigate to audit user dashboard
    cy.contains("a", "audit user", opt)
      .click()

    cy.contains("loading opensearch dashboards", opt)
      .should("not.exist")

    // assert contains dashboard elements

    cy.contains("audit counter", opt)
      .should("be.visible")

    cy.contains("resource selector", opt)
      .should("be.visible")
    cy.contains("user selector", opt)
      .should("be.visible")
    cy.contains("verb selector", opt)
      .should("be.visible")

    cy.contains("api-requests", opt)
      .should("be.visible")
    cy.contains("audit logs - all", opt)
      .should("be.visible")
  })

  it('test kubeaudit index', function () {
    opensearchTestIndexPattern(cy, "kubeaudit")
  })

  it('test kubernetes index', function () {
    if (this.indexPerNamespace === "true") {
      this.skip()
    }

    opensearchTestIndexPattern(cy, "kubernetes")
  })
})
