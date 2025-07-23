import '../../common/cypress/grafana.js'

describe('user grafana user promotion', function () {
  before(function () {
    cy.yq('sc', '.grafana.user.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.user.trailingDots').should((value) =>
      assert(value !== 'true', ".grafana.user.trailingDots in sc config must not be 'true'")
    )

    // skipRoleSync must be true
    cy.yqDig('sc', '.grafana.user.oidc.skipRoleSync').should((value) =>
      assert(value === 'true', ".grafana.user.oidc.skipRoleSync in sc config must be 'true'")
    )

    // dex.enableStaticLogin must be true
    cy.yqDig('sc', '.dex.enableStaticLogin').then((value) => {
      assert(value === 'true', ".dex.enableStaticLogin in sc config must be 'true'")
    })

    // 'example.com' must be in grafana.user.oidc.allowedDomains
    cy.yqDigParse('sc', '.grafana.user.oidc.allowedDomains').then((domains) => {
      assert(
        domains.includes('example.com'),
        'example.com not set in .grafana.user.oidc.allowedDomains'
      )
    })
  })

  after(() => {
    cy.clearAllCookies()
    Cypress.session.clearAllSavedSessions()
  })

  it('admin demotes dev@example.com to Viewer', function () {
    cy.grafanaSetRole(this.ingress, '.user.grafanaPassword', 'dev@example.com', 'Viewer')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, 'dev@example.com', 'Viewer')
  })

  it('admin promotes dev@example.com to Admin', function () {
    cy.grafanaSetRole(this.ingress, '.user.grafanaPassword', 'dev@example.com', 'Admin')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, 'dev@example.com', 'Admin')
  })
})
