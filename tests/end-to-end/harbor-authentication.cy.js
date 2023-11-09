function harborAdminLogin(cy, ingress) {
  cy.visit(`https://${ingress}/account/sign-in`)

  cy.contains("LOGIN VIA LOCAL DB")
    .click()

  cy.yqSecrets(".harbor.password")
    .then(password => {
      cy.get('input[placeholder*="Username"]')
        .type("admin", { log: false })

      cy.get('input[placeholder*="Password"]')
        .type(password, { log: false })

      cy.get("button")
        .contains("LOG IN")
        .click()
    })

  cy.contains("Projects")
    .should("exist")

  cy.contains("admin")
    .should("exist")
}

describe("harbor authentication", function() {
  before(function() {
    cy.yq("sc", '.harbor.subdomain + "." + .global.baseDomain')
      .should("not.be.empty")
      .as('ingress')
  })

  it("can login via static admin user", function() {
    harborAdminLogin(cy, this.ingress)
  })

  it("can login via static dex user", function() {
    cy.yqDig("sc", ".dex.enableStaticLogin")
      .then(staticLoginEnabled => {
        if (staticLoginEnabled !== "true") {
          this.skip("dex static login is not enabled")
        }
      })

    cy.visit(`https://${this.ingress}`)

    cy.dexStaticLogin()

    cy.url().then(url => {
      if (url.includes("oidc-onboard")) {
        cy.contains("label", "Username")
          .siblings()
          .get("input")
          .clear()
          .type("dex-static-user")

        cy.contains("SAVE")
          .click()
      }
    })

    cy.contains("Projects")
      .should("exist")

    cy.contains("dex-static-user")
      .should("exist")
  })

  it("promote static dex user to admin", function() {
    harborAdminLogin(cy, this.ingress)

    cy.contains("Users")
      .click()

    cy.contains("admin@example.com")
      .parent()
      .parent()
      .parent()
      .find("input[type=checkbox]")
      .check({ force: true })

    cy.get("button[id=set-admin]")
      .then(element => {
        if (element.text().includes("SET AS ADMIN")) {
          cy.wrap(element)
            .click()
        }
      })

    cy.contains("admin@example.com")
      .siblings()
      .contains("Yes")
  })
})
