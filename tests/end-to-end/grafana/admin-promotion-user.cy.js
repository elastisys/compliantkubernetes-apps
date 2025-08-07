import '../../common/cypress/grafana.js'

const DEV_USER = 'dev@example.com'

describe('user grafana user promotion', function () {
  before(function () {
    cy.yq('sc', '.grafana.user.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.user.trailingDots').then((value) =>
      assert(value !== 'true', ".grafana.user.trailingDots in sc config must not be 'true'")
    )

    // skipRoleSync must be true
    cy.yqDig('sc', '.grafana.user.oidc.skipRoleSync').then((value) =>
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
    cy.grafanaDexExtraStaticLogin(`${this.ingress}/profile`, DEV_USER)
    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaSetRole(this.ingress, '.user.grafanaPassword', DEV_USER, 'Viewer')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, DEV_USER, 'Viewer')
  })

  it('admin promotes dev@example.com to Admin', function () {
    cy.grafanaSetRole(this.ingress, '.user.grafanaPassword', DEV_USER, 'Admin')

    cy.visit(`https://${this.ingress}/logout`)

    cy.grafanaCheckRole(this.ingress, DEV_USER, 'Admin')
  })
})
