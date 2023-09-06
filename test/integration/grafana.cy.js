describe('grafana integration', function() {
  beforeEach(function() {
    cy.visit('https://<grafana-address>')
  })

  it('should fail', function() {
    cy.contains('Welcome to Grafana').should('not.exist')
  })

  it('should pass', function() {
    cy.contains('Welcome to Grafana').should('exist')
  })

  it('should skip', function() {
    this.skip()
  })
})
