describe('opensearch admin authentication', () => {
  before(function () {
    cy.yq('sc', '.opensearch.dashboards.subdomain + "." + .global.baseDomain')
      .should('not.contain.empty')
      .as('ingress')
  })

  it('can login via static dex user', function () {
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

    cy.continueOn('sc', '.dex.enableStaticLogin')

    cy.visit(`https://${this.ingress}`)

    cy.dexStaticLogin()

    cy.contains('Loading OpenSearch Dashboards').should('not.exist')

    cy.contains('Welcome to Welkin').should('exist')
  })
})
