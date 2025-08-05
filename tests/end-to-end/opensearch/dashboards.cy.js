const opt = { matchCase: false }

import '../../common/cypress/opensearch'

describe('opensearch dashboards', function () {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.be.empty')
      .as('ingress')

    cy.yqDig('sc', '.opensearch.indexPerNamespace').should('not.be.empty').as('indexPerNamespace')
    // 'admin@example.com' must have all_access permissions
    cy.yqDigParse(
      'sc',
      '.opensearch.extraRoleMappings[] | select(.mapping_name == "all_access") | .definition.users'
    ).then((users) => {
      assert(
        users.includes('admin@example.com'),
        'admin@example.com is not in the list of users with all_access permissions'
      )
    })
  })

  beforeEach(function () {
    cy.opensearchDexStaticLogin(this.ingress)

    cy.on('uncaught:exception', (err, runnable) => {
      if (err.message.includes("Cannot read properties of undefined (reading 'split')")) {
        return false
      } else if (err.message.includes('location.href.split(...)[1] is undefined')) {
        return false
      }
    })
  })

  after(() => {
    Cypress.session.clearAllSavedSessions()
  })

  it('open the audit user dashboard', function () {
    // open sidebar menu
    cy.contains('title', 'menu', opt).parents('button').click()

    // navigate to dashboards
    cy.get('nav').contains('li', 'dashboard', opt).click()

    cy.contains('loading opensearch dashboards', opt).should('not.exist')

    // navigate to audit user dashboard
    cy.contains('a', 'audit user', opt).click()

    cy.contains('loading opensearch dashboards', opt).should('not.exist')

    // assert contains dashboard elements

    cy.contains('audit counter', opt).should('be.visible')

    cy.contains('resource selector', opt).should('be.visible')
    cy.contains('user selector', opt).should('be.visible')
    cy.contains('verb selector', opt).should('be.visible')

    cy.contains('api-requests', opt).should('be.visible')
    cy.contains('audit logs - all', opt).should('be.visible')
  })

  it('test kubeaudit index', function () {
    cy.opensearchTestIndexPattern('kubeaudit')
  })

  it('test kubernetes index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    cy.opensearchTestIndexPattern('kubernetes')
  })

  it('test other index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    cy.opensearchTestIndexPattern('other')
  })

  it('test authlog index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    cy.opensearchTestIndexPattern('authlog')
  })
})

describe('Verify indices are managed in ISM UI', function () {
  const opt = { matchCase: false }
  const managedIndices = ['authlog', 'kubeaudit', 'kubernetes', 'other']

  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.be.empty')
      .as('ingress')
  })

  beforeEach(function () {
    cy.opensearchDexStaticLogin(this.ingress)
  })

  managedIndices.forEach((index) => {
    it(`should confirm index "${index}" is listed in ISM managed indices UI`, function () {
      // Open sidebar
      cy.contains('title', 'menu', opt).parents('button').click()

      // Go to Management > Index Management
      cy.get('nav').contains('li', 'Management', opt).click()
      cy.contains('a', 'index management', opt).click()

      // Clicks on Managed Indices tab
      cy.contains('a', 'state management policies', opt).click()

      // Searches for the index
      cy.get('input[placeholder*="Search"]').clear().type(index)

      // Confirms that index appears in the results
      cy.contains('td', index, opt).should('be.visible')
    })
  })
})

describe('Verify snapshot policy exists via search', function () {
  const opt = { matchCase: false }

  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.be.empty')
      .as('ingress')
  })

  beforeEach(function () {
    cy.viewport(1600, 900) // Ensure layout is wide enough to avoid text wrapping
    cy.opensearchDexStaticLogin(this.ingress)
  })

  it('should find snapshot policy snapshot_management_policy via search', function () {
    cy.contains('title', 'menu', opt).parents('button').click()
    // Go to Management > Snapshot Management
    cy.get('nav').contains('li', 'Management', opt).click()
    cy.contains('a', 'snapshot management', opt).click()
    // Click on Managed Indices tab
    cy.contains('a', 'snapshot policies', opt).click()
    // Assert snapshot policy row is visible
    cy.contains('td', 'snapshot_management_policy', opt).should('be.visible')
  })
})

describe('Create a manual snapshot', function () {
  const opt = { matchCase: false }
  const snapshotName = `cypress-snapshot-${Date.now()}`
  const snapshotPrefix = 'cypress-snapshot-'
  const indices = `*`
  const indexPattern = '*'

  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.be.empty')
      .as('ingress')
  })

  beforeEach(function () {
    cy.viewport(1600, 900)
    cy.opensearchDexStaticLogin(this.ingress)
  })

  it('should take a snapshot successfully', function () {
    cy.contains('title', 'menu', opt).parents('button').click()
    cy.get('nav').contains('li', 'Management', opt).click()
    cy.contains('a', 'snapshot management', opt).click()
    cy.contains('a', 'snapshots', opt).click()
    cy.contains('button', 'Take snapshot', opt).click()

    // Type the snapshot name
    cy.get('input[placeholder="Enter snapshot name"]').clear().type(snapshotName)

    // Open the index pattern dropdown
    cy.get('div[role="combobox"]').first().click()

    cy.get('div[role="combobox"] input').first().type('*{enter}', { force: true })

    cy.get('div[role="combobox"]').first().should('contain.text', '*')

    cy.intercept('PUT', '/api/ism/_snapshots/**').as('takeSnapshot')
    // After clicking "Add"
    cy.contains('button', 'Add', opt).should('not.be.disabled').click()

    cy.contains('th', 'Time last updated').click()
    cy.wait('@takeSnapshot') // Wait for snapshot request to complete
    cy.contains('th', 'Time last updated').click()
    // Wait for snapshot name to show up in the table
    cy.contains('td', snapshotName).should('be.visible')
  })
})
