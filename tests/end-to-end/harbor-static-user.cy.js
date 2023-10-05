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
    cy.visit(this.baseUrl)
    cy.get('[class="header-title"]').should('exist').and('contain', 'Projects')
  })

})
