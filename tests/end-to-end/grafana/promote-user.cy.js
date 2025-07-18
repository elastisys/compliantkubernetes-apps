const apiTimeout = 60000
const staticUser = 'dev@example.com'

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

    cy.intercept('/api/user/orgs').as('userOrgs')

    const ingress = this.ingress

    const devLogin = function () {
      cy.visit(`https://${ingress}/profile`)

      cy.contains('Sign in with dex').click()

      cy.dexExtraStaticLogin(staticUser)

      cy.wait(['@userOrgs'], { timeout: apiTimeout })
    }

    const cyGet = function (selector) {
      return cy.get(selector, { timeout: apiTimeout })
    }

    // static user should be 'Viewer'
    devLogin()

    cyGet('[data-testid="data-testid-user-orgs-table"]').then(($userInfo) => {
      if ($userInfo.text().includes('Admin')) {
        this.skip('user is already an admin')
      }
    })

    cyGet('[data-testid="data-testid-user-orgs-table"]').contains('Viewer').should('exist')

    cy.visit(`https://${ingress}/logout`)

    // Log in as the grafana Admin and promote
    cy.visit(`https://${ingress}/admin/users`)

    cy.yqSecrets('.user.grafanaPassword').then((password) => {
      cyGet('input[placeholder*="username"]').type('admin', { log: false })

      cyGet('input[placeholder*="password"]').type(password, { log: false })

      cyGet('button').contains('Log in').click()
    })

    cy.contains('Organization users', { timeout: apiTimeout }).should('be.visible').click()
    cyGet('input[placeholder*="Search user by login"]')
      .type(staticUser.substring(0, staticUser.lastIndexOf('.')))
      .type('{enter}')

    cyGet('[aria-label="Role"]').type('Admin{enter}')

    cy.contains('Organization user updated').should('be.visible')

    cy.visit(`https://${ingress}/logout`)

    // Re-login => should be admin
    devLogin()

    cyGet('[data-testid="data-testid-user-orgs-table"]').contains('Admin').should('exist')
  })
})
