const apiTimeout = 30000

describe('grafana user promotion', function () {
  before(function () {
    cy.yq('sc', '.grafana.user.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')

    // Cypress does not like trailing dots
    cy.yqDig('sc', '.grafana.user.trailingDots').should((value) =>
      assert(value !== 'true', ".grafana.user.trailingDots in sc config must not be 'true'")
    )
  })

  it('can promote a static user to admin', function () {
    cy.yqDig('sc', '.dex.enableStaticLogin').then((staticLoginEnabled) => {
      if (staticLoginEnabled !== 'true') {
        this.skip('dex static login is not enabled')
      }
    })

    cy.yqDigParse('sc', '.grafana.user.oidc.allowedDomains').then((domains) => {
      if (!domains.includes('example.com')) {
        this.skip('example.com not set in .grafana.ops.oidc.allowedDomains')
      }
    })

    cy.intercept('/api/**').as('api')

    const ingress = this.ingress

    const devLogin = function () {
      cy.visit(`https://${ingress}/profile`)

      cy.contains('Sign in with dex').click()

      cy.dexExtraStaticLogin('dev@example.com')

      cy.wait(Array(12).fill('@api'), { timeout: apiTimeout })
    }

    // static user should be 'Viewer'
    devLogin()

    cy.get('[data-testid="data-testid-user-orgs-table"]').then(($userInfo) => {
      if ($userInfo.text().includes('Admin')) {
        this.skip('user is already an admin')
      }
    })

    cy.get('[data-testid="data-testid-user-orgs-table"]').contains('Viewer').should('exist')

    cy.visit(`https://${ingress}/logout`)

    // Log in as the grafana Admin and promote
    cy.visit(`https://${ingress}/admin/users`)

    cy.yqSecrets('.user.grafanaPassword').then((password) => {
      cy.get('input[placeholder*="username"]').type('admin', { log: false })

      cy.get('input[placeholder*="password"]').type(password, { log: false })

      cy.get('button').contains('Log in').click()
    })

    cy.get('[aria-label="Edit user dev"]', { timeout: apiTimeout }).should('exist').click()

    cy.contains('Change role', { timeout: apiTimeout }).should('be.visible').click()
    cy.get('[aria-haspopup="true"]').click().type('Admin{enter}')
    cy.get('span').contains('Save').click()

    cy.visit(`https://${ingress}/logout`)

    // Re-login => should be admin
    devLogin()

    cy.get('[data-testid="data-testid-user-orgs-table"]').contains('Admin').should('exist')
  })
})
