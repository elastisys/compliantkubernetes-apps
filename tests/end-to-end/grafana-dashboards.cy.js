describe("grafana integration", function() {
  before(function() {
    cy.yq("sc", "\"https://\" + .grafana.ops.subdomain + \".\" + .global.opsDomain")
      .its("stdout")
      .should("not.contain", "null")
      .as('url')
    cy.yqSecrets(".grafana.password")
      .its("stdout")
      .as('password')
  })
  beforeEach(function() {
    cy.staticLogin("admin", this.password, this.url + '/login')
  })

  it('navigation toolbar is visible', function () {
    cy.intercept('GET', this.url + '/?orgId=1').as('getMain')
    cy.visit(this.url + '/?orgId=1')
    cy.wait('@getMain')
    cy.get('[data-testid="data-testid Nav toolbar"]').should('exist')
  })

  it('open the backup status dashboard', function () {
    cy.intercept('GET', this.url + '/dashboards').as('getDashboards')
    cy.visit(this.url + '/dashboards')
    cy.get('[data-testid="data-testid Folder header General"]').click()
    cy.wait('@getDashboards')
    cy.contains('Backup status').click()
  })
})
