// Available as cy.yq("sc|wc", "expression") merge first then expression
// More correct than yqDig for complex data such as maps that can be merged
Cypress.Commands.add("yq", function(cluster, expression) {
  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yq: CK8S_CONFIG_PATH is unset")
  }

  if (typeof cluster === "undefined") {
    cy.fail("yq: cluster argument is missing")
  } else if (cluster !== "sc" && cluster !== "wc") {
    cy.fail("yq: cluster argument is invalid")
  }
  const configFiles = `${configPath}/defaults/common-config.yaml ${configPath}/defaults/${cluster}-config.yaml ${configPath}/common-config.yaml ${configPath}/${cluster}-config.yaml`

  if (typeof expression === "undefined") {
    cy.fail("yq: expression argument is missing")
  }

  cy.exec(`yq4 ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configFiles}`)
    .then(result => {
      if (result.stderr !== "") {
        cy.fail(`yq: error in exec: ${result.stderr}`)
      } else {
        return result.stdout
      }
    })
})

// Available as cy.yqDig("sc|wc", "expression") expression first then merge
// More efficient than yq for simple data such as scalars that cannot be merged
Cypress.Commands.add("yqDig", function(cluster, expression) {
  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yq: CK8S_CONFIG_PATH is unset")
  }

  if (typeof cluster === "undefined") {
    cy.fail("yq: cluster argument is missing")
  } else if (cluster !== "sc" && cluster !== "wc") {
    cy.fail("yq: cluster argument is invalid")
  }
  const configFiles = `${configPath}/defaults/common-config.yaml ${configPath}/defaults/${cluster}-config.yaml ${configPath}/common-config.yaml ${configPath}/${cluster}-config.yaml`

  if (typeof expression === "undefined") {
    cy.fail("yq: expression argument is missing")
  }

  cy.exec(`yq4 ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`)
    .then(result => {
      if (result.stderr !== "") {
        cy.fail(`yq: error in exec: ${result.stderr}`)
      } else {
        return result.stdout
      }
    })
})

// Available as cy.yqSecrets("expression") sops decrypt into yq expression
Cypress.Commands.add("yqSecrets", function(expression) {
  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yqSecrets: CK8S_CONFIG_PATH is unset")
  }

  if (typeof expression === "undefined") {
    cy.fail("yqSecrets: expression argument is missing")
  }

  cy.exec(`sops -d ${configPath}/secrets.yaml | yq4 e '${expression} | ... comments=""'`)
    .then(result => {
      if (result.stderr !== "") {
        cy.fail(`yq: error in exec: ${result.stderr}`)
      } else {
        return result.stdout
      }
    })
})

// Available as cy.continueOn("sc|wc", "expression") expression should evaluate to true to continue
Cypress.Commands.add("continueOn", function(cluster, expression) {
  cy.yqDig(cluster, expression)
    .then(result => {
      if (result !== "true") {
        this.skip(`${cluster}/${expression} is disabled`)
      }
    })
})

// Available as cy.dexStaticLogin() requires dex static login to be enabled
Cypress.Commands.add("dexStaticUserLogin", function(username, loginUrl, cookieName) {
  // Check if static login is enabled
  cy.yqDig("sc", ".dex.enableStaticLogin")
    .then(staticLoginEnabled => {
      if (staticLoginEnabled !== "true") {
        cy.fail("dexStaticLogin: requires dex static login to be enabled")
      }
    })

  // Conditionally skip connector selection
  cy.yqSecrets(".dex.connectors | length")
    .then(connectors => {
      if (connectors == "0") {
        cy.fail("dexStaticLogin: no connectors were set")
      }
    })

  cy.session([username, loginUrl, cookieName], () => {
    cy.visit(loginUrl)

    cy.contains('button', 'Log in with Email').click()
    cy.get('input#login').type(username)
    cy.yqSecrets(".dex.staticPasswordNotHashed")
      .then(password => {
        // {enter} causes the form to submit
        cy.get('input#password').type(`${password}{enter}`, { log: false })
      })
    // ToDO: needed mostly for OpenSearch, check for alternatives or make if configurable
    cy.wait(10000)
    // this is needed for Harbor first time login
    cy.title().then(($title) => {
      if ($title === 'Harbor') {
        cy.get("body").then(($body) => {
          const hasOidcBanner = $body[0].querySelectorAll("*[class='modal-title oidc-header-text']")
          if (hasOidcBanner.length > 0) {
            cy.get('input[name=oidcUsername]').clear().type('admin_static_user')
            cy.get('[id="saveButton"]').click()
          }
        })
      }
    })
    // Ensure Auth0 has redirected us back to the original URL
    cy.url().should('include', loginUrl)
  },
  {
    validate: () => {
      // Validate the session
      cy.getCookie(cookieName).should('exist')
    },
  }
  )
})

// Available as cy.staticLogin("username", "password expression", "url for login", "username field name", "password field name", "path to test after login", "session cookie name")
Cypress.Commands.add('staticLogin', (username, passwordExpression, userField, passField, loginUrl, landingPath, cookieName) => {
  cy.session([username, passwordExpression, userField, passField, loginUrl, landingPath, cookieName], () => {
    cy.visit(loginUrl)

    // this is needed for Harbor login via local db
    cy.title().then(($title) => {
      if ($title === 'Harbor') {
        cy.get('[id="login-db"]').should('exist').click()
      }
    })
    // ToDo the username label should be configurable
    cy.get(`input[name=${userField}]`).type(username)

    cy.yqSecrets(passwordExpression)
      .then(password => {
        // {enter} causes the form to submit
        // ToDo the password label should be configurable
        cy.get(`input[name=${passField}]`).type(`${password}{enter}`, { log: false })
      })
    // we get some network errors at this step, let's see if wait fixes that
    cy.wait(5000)
    cy.url().should('include', landingPath)
  },
  {
    validate() {
      cy.getCookie(cookieName).should('exist')
    },
  }
  )
})

// Available as cy.testGrafanaDashboard("baseUrl", "the names of the Grafana dashboard", "the no of completed api req to wait")
Cypress.Commands.add('testGrafanaDashboard', (baseUrl, dashboardName, requestsToWait) => {
  cy.intercept("/api/**").as("api")

  cy.visit(baseUrl + '/dashboards')
  // used to view and load as much of the dashboard as possible
  cy.viewport(2560, 2160)

  cy.get('[data-testid="data-testid Folder header General"]').click()
  cy.get(`[data-testid="data-testid Dashboard search item ${dashboardName}"]`).click()
  // ToDo: expand all rows
  cy.wait(Array(requestsToWait).fill('@api'))
  // not really best practices to target objects by id
  cy.get('[id="var-datasource"]').should('exist').and('contain', 'default')
  cy.get('[id="var-cluster"]').should('exist')
  // some dashboards will contain "No data" because an overwrite for NaN or Null doesn't exist
  cy.contains('No data').should('not.exist')
})

// Available as cy.testOpensearchDashboard("baseUrl", "the names of the Opensearch dashboard", "the no of completed api req to wait")
Cypress.Commands.add('testOpensearchDashboard', (baseUrl, dashboardName, requestsToWait) => {
  cy.intercept("/api/**").as("api")

  cy.visit(baseUrl + '/app/dashboards')
  // used to view and load as much of the dashboard as possible
  cy.viewport(2560, 2160)
  cy.wait(Array(4).fill('@api'))
  const dashname = `${dashboardName}`.replace(" ","-")
  // turning off uncaught exception handling for location.href.split error generated by opensearch
  cy.on('uncaught:exception', (err, runnable) => {
    if (err.message.includes('location.href.split(...)[1] is undefined')) {
      return false
    }
  }
  )
  cy.get(`[data-test-subj="dashboardListingTitleLink-${dashname}"]`).click()
  cy.wait(Array(requestsToWait).fill('@api'))
  cy.get('[data-test-subj="breadcrumb last"]').should('exist').and('contain', `${dashboardName}`)
  cy.get('[data-test-subj="globalQueryBar"]').should('exist')
})

// Available as cy.testOpensearchIndex("baseUrl", "index pattern", "the no of completed req to wait")
Cypress.Commands.add('testOpensearchIndex', (baseUrl, indexPattern, requestsToWait) => {
  cy.intercept("**/search/**").as("search")

  cy.visit(baseUrl + '/app/discover')
  // turning off uncaught exception handling for location.href.split error generated by opensearch
  cy.on('uncaught:exception', (err, runnable) => {
    if (err.message.includes('location.href.split(...)[1] is undefined')) {
      return false
    }
  }
  )
  cy.wait(Array(requestsToWait).fill('@search'))
  // click to view the index patterns list
  cy.get('[data-test-subj="indexPattern-switch-link"]').should('exist').click()
  // click on the desired index pattern
  cy.get('[data-test-subj="indexPattern-switcher"]').contains(indexPattern).click()
  cy.wait(Array(requestsToWait).fill('@search'))
  // if log enties exists and are visible the hits tag should exist
  cy.get('[data-test-subj="discoverQueryHits"]').should('exist')
})
