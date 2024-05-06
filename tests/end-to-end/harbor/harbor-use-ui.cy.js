// bats file_tags=harbor,use-ui
// same as integration test without local-cluster setup

import "../../common/cypress/harbor.js"

const opt = { matchCase: false }
const slug = "end-to-end-tests-harbor-manage-resources"

describe("harbor ui", function() {
  before(function() {
    cy.yq("sc", '.harbor.subdomain + "." + .global.baseDomain')
      .should("not.be.empty")
      .as('ingress')
      .then(() => {
        cy.harborStaticDexLogin(this.ingress)

        cy.contains("dex-static-user", opt)
          .click()

        cy.contains("log out", opt)
          .click()

        cy.harborAdminLogin(this.ingress)

        cy.harborStaticDexPromote(this.ingress)
      })
  })

  beforeEach(function() {
    cy.session([this.ingress], () => {
      cy.harborStaticDexLogin(this.ingress)
    })

    cy.visit(`https://${this.ingress}`)

    cy.viewport(1280, 720)
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })

  it("can create project", function() {
    cy.contains("button", "new project", opt)
      .click()

    cy.contains("label", "project name", opt)
      .siblings()
      .find("input")
      .clear()
      .type(`${slug}-project`)

    cy.contains("button", "ok", opt)
      .click()

    cy.contains(`${slug}-project`)
      .parent()
      .siblings()
      .contains("project admin", opt)

    cy.contains("created project successfully", opt)
  })

  it("can create system robot account", function() {
    cy.contains("robot accounts", opt)
      .click()

    cy.contains("button", "new robot account", opt)
      .click()

    cy.contains("label", "name", opt)
      .siblings()
      .find("input")
      .clear()
      .type(`${slug}-robot`)

    cy.contains(`${slug}-project`)
      .parent()
      .parent()
      .parent()
      .parent()
      .find("input[type=checkbox]")
      .check({ force: true })

    cy.contains("button", "next", opt)
      .click()

    cy.contains("button", "select all", opt)
      .click()

    cy.contains("button", "next", opt)
      .click()

    cy.contains("button", "finish", opt)
      .click()

    cy.contains(`created 'robot$${slug}-robot' successfully`, opt)
  })

  it("can delete system robot account", function() {
    cy.contains("robot accounts", opt)
      .click()

    cy.contains(`${slug}-robot`)
      .parent()
      .parent()
      .parent()
      .parent()
      .find("input[type=checkbox]")
      .check({ force: true })

    cy.contains("action", opt)
      .click()

    cy.contains("delete", opt)
      .click()

    cy.contains("button", "delete", opt)
      .click()

    cy.contains("deleted robot(s) successfully", opt)
  })

  it("can create project robot account", function() {
    cy.contains(`${slug}-project`)
      .click()

    cy.contains("button", "robot accounts", opt)
      .click()

    cy.contains("button", "new robot account", opt)
      .click()

    cy.contains("label", "name", opt)
      .siblings()
      .find("input")
      .clear()
      .type(`${slug}-robot`)

    cy.contains("label", "expiration time", opt)
      .siblings()
      .find("input[type=text]")
      .clear()
      .type("30")

    cy.contains("button", "next", opt)
      .click()

    cy.contains("button", "select all", opt)
      .click()

    cy.contains("button", "finish", opt)
      .click()

    cy.contains(`created 'robot$${slug}-project+${slug}-robot' successfully`, opt)
  })

  it("can delete project robot account", function() {
    cy.contains(`${slug}-project`)
      .click()

    cy.contains("button", "robot accounts", opt)
      .click()

    cy.contains(`${slug}-robot`)
      .parent()
      .parent()
      .parent()
      .parent()
      .find("input[type=checkbox]")
      .check({ force: true })

    cy.contains("action", opt)
      .click()

    cy.contains("delete", opt)
      .click()

    cy.contains("button", "delete", opt)
      .click()

    cy.contains("deleted robot(s) successfully", opt)
  })

  it("can delete project", function() {
    cy.contains(`${slug}-project`)
      .parent()
      .siblings()
      .contains("project admin", opt)

    cy.contains(`${slug}-project`)
      .parent()
      .parent()
      .parent()
      .parent()
      .find("input[type=checkbox]")
      .check({ force: true })

    cy.contains("action", opt)
      .click()

    cy.contains("delete", opt)
      .click()

    cy.contains("button", "delete", opt)
      .click()

    cy.contains("deleted successfully", opt)
  })
})
