const opt = { matchCase: false }

function opensearchDexStaticLogin(cy, ingress) {
  // Need to ignore error response from GET /api/dataconnections for non-authorized user.
  //
  // {
  //     "statusCode": 403,
  //     "error": "Forbidden",
  //     "message": "{
  //         "status": 403,
  //       "error": {
  //           "type": "OpenSearchSecurityException",
  //         "reason": "There was internal problem at backend",
  //         "details": "no permissions for [cluster:admin/opensearch/ql/datasources/read] and User [name=admin@example.com, backend_roles=[], requestedTenant=null]"
  //       }
  //   }"
  // }
  //
  // TODO: Narrow this down to the specific request OR investigate if a user
  //       actually should have this permission.
  cy.on('uncaught:exception', (err, runnable) => {
    if (err.message.includes('Forbidden')) {
      return false
    }
  })

  cy.session([ingress], () => {
    cy.visit(`https://${ingress}`)

    cy.dexStaticLogin()

    cy.contains('loading opensearch dashboards', opt).should('not.exist')

    cy.contains('Welcome to Welkin').should('be.visible')
  })

  cy.visit(`https://${ingress}`)

  cy.contains('loading opensearch dashboards', opt).should('not.exist')

  cy.contains('Welcome to Welkin').should('be.visible')
}

function opensearchTestIndexPattern(cy, indexPattern) {
  // open sidebar menu
  cy.contains('title', 'menu', opt).parents('button').click()

  // navigate to discover
  cy.get('nav').contains('li', 'discover', opt).click()

  // select index pattern
  cy.contains('div', 'kubeaudit*').click()
  cy.contains('button', indexPattern).click()

  cy.contains('no results match your search criteria', opt).should('not.exist')

  cy.contains('hits', opt).should('be.visible')
}

describe('opensearch dashboards', function () {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.be.empty')
      .as('ingress')

    cy.yqDig('sc', '.opensearch.indexPerNamespace').should('not.be.empty').as('indexPerNamespace')
  })

  beforeEach(function () {
    opensearchDexStaticLogin(cy, this.ingress)

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
    opensearchTestIndexPattern(cy, 'kubeaudit')
  })

  it('test kubernetes index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    opensearchTestIndexPattern(cy, 'kubernetes')
  })

  it('test other index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    opensearchTestIndexPattern(cy, 'other')
  })

  it('test authlog index', function () {
    if (this.indexPerNamespace === 'true') {
      this.skip()
    }

    opensearchTestIndexPattern(cy, 'authlog')
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
    opensearchDexStaticLogin(cy, this.ingress)
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
    opensearchDexStaticLogin(cy, this.ingress)
  })

  it(`should find snapshot policy snapshot_management_policy via search`, function () {
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
    opensearchDexStaticLogin(cy, this.ingress)
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

    // After clicking "Add"
    cy.contains('button', 'Add', opt).should('not.be.disabled').click()

    cy.contains('th', 'Time last updated').click()
    cy.wait(1000) //wait for the page to re-render
    cy.contains('th', 'Time last updated').click()
    // Wait for snapshot name to show up in the table
    cy.contains('td', snapshotName).should('be.visible')
  })
})
