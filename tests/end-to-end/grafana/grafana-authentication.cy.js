describe("grafana admin authentication", function() {
  before(function() {
    cy.yq("sc", ".grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
      .should("not.equal", "true")
  })

  it("can login via static admin user", function() {
    cy.visit(`https://${this.ingress}`)

    cy.yqSecrets(".grafana.password")
      .then(password => {
        cy.get('input[placeholder*="username"]')
          .type("admin", { log: false })

        cy.get('input[placeholder*="password"]')
          .type(password, { log: false })


        cy.get("button")
          .contains("Log in")
          .click()
      })

    cy.contains("Home")
      .should("exist")

    cy.contains("Welcome to Grafana")
      .should("exist")
  })

  it("can login via static dex user", function() {
    cy.yqDig("sc", ".dex.enableStaticLogin")
      .then(staticLoginEnabled => {
        if (staticLoginEnabled !== "true") {
          this.skip("dex static login is not enabled")
        }
      })

    cy.visit(`https://${this.ingress}`)

    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

    cy.contains("Home")
      .should("exist")

    cy.contains("Welcome to Grafana")
      .should("exist")
  })
})

describe("grafana dev authentication", function() {
  before(function() {
    cy.yq("sc", ".grafana.user.subdomain + \".\" + .global.baseDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.user.trailingDots")
      .should("not.equal", "true")
  })

  it("can login via static admin user", function() {
    cy.visit(`https://${this.ingress}`)

    cy.yqSecrets(".user.grafanaPassword")
      .then(password => {
        cy.get('input[placeholder*="username"]')
          .type("admin", { log: false })

        cy.get('input[placeholder*="password"]')
          .type(password, { log: false })

        cy.get("button")
          .contains("Log in")
          .click()
      })

    cy.contains("Home")
      .should("exist")

    cy.contains("Welcome to Compliant Kubernetes")
      .should("exist")
  })

  it("can login via static dex user", function() {
    cy.yqDig("sc", ".dex.enableStaticLogin")
      .then(staticLoginEnabled => {
        if (staticLoginEnabled !== "true") {
          this.skip("dex static login is not enabled")
        }
      })

    cy.visit(`https://${this.ingress}`)

    cy.contains("Sign in with dex")
      .click()

    cy.dexStaticLogin()

    cy.contains("Home")
      .should("exist")

    cy.contains("Welcome to Compliant Kubernetes")
      .should("exist")
  })
})
