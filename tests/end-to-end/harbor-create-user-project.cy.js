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

  it('Harbor login with admin and promote the dex static user to Harbor admin', function () {
    cy.staticLogin("admin", ".harbor.password", "login_username", "login_password", this.baseUrl + '/account/sign-in', '/harbor/projects', 'sid')
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.contains('a', 'Users').click()
    cy.contains('admin_static_user')
      .parents('[class="datagrid-row ng-star-inserted"]')
      .within(($row) => {
        const userIsHarborAdmin = $row[0].querySelectorAll('clr-dg-cell')[1].innerText
        cy.log(userIsHarborAdmin)
        if (userIsHarborAdmin === 'Yes') {
          cy.log("The admin_static_user is already Harbor admin")
        } else {
          cy.get('[type="checkbox"]').check({force: true})
          cy.document().its('body').find('button').filter(':contains("SET AS ADMIN")').click()
          cy.get('clr-dg-cell').eq(1).contains('Yes')
        }
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
      //this will match if other project names contain the demo_project name
      const projectExists = $table.text().includes('cypress_demo_project')
      if (projectExists) {
        cy.log("The project was already created")
      } else {
        cy.contains('button', 'New Project').click()
        cy.get('input[name="create_project_name"]').type('cypress_demo_project')
        cy.contains('button', 'OK').click()
        cy.contains('cypress_demo_project')
      }
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
      //this will match if other robot account names contain this name
      const robotAccountExists = $table.text().includes('cypress_robot')
      if (robotAccountExists) {
        cy.log("The robot account was already created")
      } else {
        cy.contains('button', 'NEW ROBOT ACCOUNT').click()
        cy.get('input[name="name"]').type('cypress_robot')
        cy.get('input[name="expiration"]').type('30')
        cy.contains('button', 'ADD').click()
        cy.contains('button', 'export to file')
      }
    })
  })
})
