describe("harbor create user project and robot account", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .harbor.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .as('baseUrl')
  })

  beforeEach(function() {
    cy.viewport(2560, 2160)
  })

  it('Harbor login and create the dex static user', function () {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'sid')
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
  })

  it('Harbor promote the dex static user to Harbor admin', function () {
    cy.staticLogin("admin", ".harbor.password", "login_username", "login_password", this.baseUrl + '/account/sign-in', '/harbor/projects', 'sid')
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.contains('a', 'Users').click()
    cy.contains('admin@example.com')
      .parents('[class="datagrid-row ng-star-inserted"]')
      .within(($row) => {
        cy.get('[type="checkbox"]').check({force: true})
        cy.document().its('body').find('button').filter(':contains("SET AS ADMIN")').click()
        cy.get('clr-dg-cell').eq(1).contains('Yes')
    })
  })

  it('Harbor create dex static user project', function () {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'sid')
    cy.visit(this.baseUrl + '/harbor/projects')
    cy.intercept("**/api/**").as("api")
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.wait(Array(7).fill('@api'))
    cy.get('[class="datagrid-table"]')
      .then(($table) => {
        cy.contains('button', 'New Project').click()
        cy.get('input[name="create_project_name"]').type('cypress_demo_project')
        cy.contains('button', 'OK').click()
        cy.contains('cypress_demo_project')
    })
  })

  it('Harbor create robot account for dex static user', function () {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'sid')
    cy.visit(this.baseUrl + '/harbor/projects')
    cy.intercept("**/api/**").as("api")
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.wait(Array(2).fill('@api'))
    cy.contains('cypress_demo_project').click()
    cy.contains('button', 'Robot Accounts').click()
    cy.wait(Array(13).fill('@api'))
    cy.get('[class="datagrid-table"]')
      .then(($table) => {
        cy.contains('button', 'NEW ROBOT ACCOUNT').click()
        cy.get('input[name="name"]').type('cypress_robot_account')
        cy.get('input[name="expiration"]').type('30')
        cy.contains('button', 'ADD').click()
        cy.contains('button', 'export to file')
    })
  })

  it('Harbor delete dex static user project', function () {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'sid')
    cy.visit(this.baseUrl + '/harbor/projects')
    cy.intercept("**/api/**").as("api")
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.wait(Array(7).fill('@api'))
    cy.contains('cypress_demo_project')
      .parents('[class="datagrid-row-master datagrid-row-flex ng-star-inserted"]')
      .within(($row) => {
        cy.get('[type="checkbox"]').check({force: true})
        cy.document().its('body').find('clr-dropdown').filter(':contains("ACTION")').click()
        cy.document().its('body').find('button').filter(':contains("Delete")').click()
        cy.document().its('body').find('button').filter(':contains("DELETE")').click()
    })
  })

  it('Harbor delete the dex static user', function () {
    cy.staticLogin("admin", ".harbor.password", "login_username", "login_password", this.baseUrl + '/account/sign-in', '/harbor/projects', 'sid')
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.contains('a', 'Users').click()
    cy.contains('admin@example.com')
      .parents('[class="datagrid-row ng-star-inserted"]')
      .within(($row) => {
        cy.get('[type="checkbox"]').check({force: true})
        cy.document().its('body').find('button').filter(':contains("REVOKE ADMIN")').click()
        cy.get('[type="checkbox"]').check({force: true})
        cy.document().its('body').find('clr-dropdown').filter(':contains("Actions")').click()
        cy.document().its('body').find('button').filter(':contains("Delete")').click({force: true})
        cy.document().its('body').find('button').filter(':contains("DELETE")').click()
    })
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })
})
