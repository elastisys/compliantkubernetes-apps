import '../../common/cypress/grafana.js'

describe('ops grafana user promotion', function () {
  before(function () {
    cy.yq('sc', '.grafana.ops.subdomain + "." + .global.opsDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.ops.trailingDots').should((value) =>
      assert(value !== 'true', ".grafana.ops.trailingDots in sc config must not be 'true'")
    )

    // skipRoleSync must be true
    cy.yqDig('sc', '.grafana.ops.oidc.skipRoleSync').should((value) =>
      assert(value === 'true', ".grafana.ops.oidc.skipRoleSync in sc config must be 'true'")
    )

    // dex.enableStaticLogin must be true
    cy.yqDig('sc', '.dex.enableStaticLogin').then((value) => {
      assert(value === 'true', ".dex.enableStaticLogin in sc config must be 'true'")
    })

    // 'example.com' must be in grafana.ops.oidc.allowedDomains
    cy.yqDigParse('sc', '.grafana.ops.oidc.allowedDomains').then((domains) => {
      assert(
        domains.includes('example.com'),
        'example.com not set in .grafana.ops.oidc.allowedDomains'
      )
    })
  })

  afterEach(function () {
    cy.clearAllCookies()
    cy.wrap(-1).then(Cypress.session.clearAllSavedSessions)
  })

  it('admin demotes admin@example.com to Viewer', function () {
    cy.grafanaDexStaticLogin(`${this.ingress}/profile`, false)
    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaSetRole(this.ingress, '.grafana.password', 'admin@example.com', 'Viewer')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, 'admin@example.com', 'Viewer')
  })

  it('admin promotes admin@example.com to Admin', function () {
    cy.grafanaSetRole(this.ingress, '.grafana.password', 'admin@example.com', 'Admin')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, 'admin@example.com', 'Admin')
  })
})
