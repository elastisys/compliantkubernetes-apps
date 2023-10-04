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
    cy.intercept("/api/**").as("api")
    cy.visit(this.baseUrl)
    cy.wait(Array(5).fill('@api'))
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
  })

})
