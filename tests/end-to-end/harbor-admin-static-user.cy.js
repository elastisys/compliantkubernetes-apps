describe("harbor admin static user", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .harbor.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .as('baseUrl')
  })
  beforeEach(function() {
    cy.staticLogin("admin", ".harbor.password", "login_username", "login_password", this.baseUrl + '/account/sign-in', '/harbor/projects', 'sid')
  })

  it('Harbor landing page is visible', function () {
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
    cy.contains('button', 'admin').click()
  })

  after(function() {
    Cypress.session.clearAllSavedSessions()
  })
})
