Cypress.Commands.add("harborAdminLogin", (ingress) => {
  cy.visit(`https://${ingress}/account/sign-in`)

  cy.reload()

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
})

Cypress.Commands.add("harborStaticDexLogin", (ingress) => {
  cy.visit(`https://${ingress}`)

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

Cypress.Commands.add("harborStaticDexPromote", (ingress) => {
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
