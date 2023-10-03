describe("harbor static dex user", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .harbor.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .as('baseUrl')
  })
  beforeEach(function() {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'sid')
  })

  it('Harbor landing page is visible', function () {
    cy.intercept("/api/**").as("api")
    cy.visit(this.baseUrl)
    cy.wait(Array(5).fill('@api'))
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
  })

})
