describe("opensearch static dex user", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .opensearch.subdomain + \".\" + .global.baseDomain")
      .should("not.be.empty")
      .as('baseUrl')
    cy.yq("sc", ".opensearch.indexPerNamespace")
      .should("not.be.empty")
      .as('indexPerNamespace')
  })
  beforeEach(function() {
    cy.dexStaticUserLogin("admin@example.com", this.baseUrl, 'security_authentication')
  })

  it('Welcome dashboard is visible', function () {
    cy.intercept("/api/**").as("api")
    cy.visit(this.baseUrl)
    cy.wait(Array(5).fill('@api'))
    cy.get('[data-test-subj="markdownBody"]').should('exist').and('contain', 'Welcome to Compliant Kubernetes!')
  })

  it('open the Audit user  dashboard', function () {
    cy.intercept("**/search/**").as("search")
    cy.testOpensearchDashboard(this.baseUrl, 'Audit user', 10)

    // this will require that the user has some audit entries
    // cy.wait(Array(4).fill('@search'))
    // cy.get('[data-test-subj="comboBoxToggleListButton"]').first().click()
    // cy.get('[data-test-subj="option_admin@example.com"]').click()
    // cy.get('[data-test-subj="comboBoxToggleListButton"]').first().click()
    // cy.contains('button', 'Apply changes').first().click()
  })

  it('test kubernetes index', function () {
    if (this.indexPerNamespace) {
      this.skip()
    } else {
      cy.testOpensearchIndex(this.baseUrl, 'kubernetes', 1)
    }
  })

  it('test kubeaudit index', function () {
    cy.testOpensearchIndex(this.baseUrl, 'kubeaudit', 1)
  })

  // ToDo: decide if we want to add the admin@example.com user as admin and test more indices
})
