describe("grafana admin authentication", function() {
  before(function() {
    cy.yq("sc", ".grafana.ops.subdomain + \".\" + .global.opsDomain")
      .should("not.contain.empty")
      .as("ingress")

    // Cypress does not like trailing dots
    cy.yqDig("sc", ".grafana.ops.trailingDots")
      .should((value) => assert(value !== "true", ".grafana.ops.trailingDots in sc config must not be 'true'"))
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

    cy.yqDigParse("sc", ".grafana.ops.oidc.allowedDomains")
      .then(domains => {
        if (!domains.includes("example.com")) {
          this.skip("example.com not set in .grafana.ops.oidc.allowedDomains")
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
      .should((value) => assert(value !== "true", ".grafana.user.trailingDots in sc config must not be 'true'"))
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

    cy.yqDigParse("sc", ".grafana.user.oidc.allowedDomains")
      .then(domains => {
        if (!domains.includes("example.com")) {
          this.skip("example.com not set in .grafana.user.oidc.allowedDomains")
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
