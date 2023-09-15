// Available as cy.yq("sc|wc", "expression") merge first then expression
// More correct for complex data such as maps that can be merged
Cypress.Commands.add("yq", function(cluster, expression) {
  if (typeof cluster === "undefined") {
    cy.fail("yq: cluster argument is missing")

  } else if (typeof expression === "undefined") {
    cy.fail("yq: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yq: CK8S_CONFIG_PATH is unset")
  }

  if (cluster === "sc") {
    cy.exec(`yq4 ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)

  } else if (cluster === "wc") {
    cy.exec(`yq4 ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)

  } else {
    cy.fail("yq: cluster argument is invalid")
  }
})

// Available as cy.yqDig("sc|wc", "expression") expression first then merge
// More efficient for simple data such as scalars that cannot be merged
Cypress.Commands.add("yqDig", function(cluster, expression) {
  if (typeof cluster === "undefined") {
    cy.fail("yqDig: cluster argument is missing")

  } else if (typeof expression === "undefined") {
    cy.fail("yqDig: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yqDig: CK8S_CONFIG_PATH is unset")
  }

  if (cluster === "sc") {
    cy.exec(`yq4 ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)

  } else if (cluster === "wc") {
    cy.exec(`yq4 ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)

  } else {
    cy.fail("yqDig: cluster argument is invalid")
  }
})

// Available as cy.yqSecrets("expression") sops decrypt into yq expression
Cypress.Commands.add("yqSecrets", function(expression) {
  if (typeof expression === "undefined") {
    cy.fail("yqSecrets: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yqSecrets: CK8S_CONFIG_PATH is unset")
  }

  cy.exec(`sops -d ${configPath}/secrets.yaml | yq4 e '${expression} | ... comments=""'`)
})

// Available as cy.skipOnDisabled("sc|wc", "expression") expression should be without leading dot and trailing dot enabled
Cypress.Commands.add("skipOnDisabled", function(cluster, expression) {
  cy.yqDig(cluster, `.${expression}.enabled`)
    .then(function(result) {
      if (result.stdout !== "true") {
        this.skip(`${cluster}/${expression} is disabled`)
      }
    })
})

// Available as cy.staticLogin("username", "password expression", "url for login", "path to test after login", "session cookie name")
Cypress.Commands.add('staticLogin', (username, passwordExpression, loginUrl, landingPath, cookieName) => {
  cy.session([username, passwordExpression, loginUrl, landingPath, cookieName], () => {
    cy.visit(loginUrl)
    // ToDo the username label should be configurable
    cy.get('input[name=user]').type(username)

    cy.yqSecrets(passwordExpression)
      .its("stdout")
      .then(password => {
        // {enter} causes the form to submit
        // ToDo the password label should be configurable
        cy.get('input[name=password]').type(`${password}{enter}`, { log: false })
      })
    // we get some network errors at this step, let's see if wait fixes them
    cy.wait(5000)
    cy.url().should('include', landingPath)
  },
  {
    validate() {
      cy.getCookie(cookieName).should('exist')
    },
    cacheAcrossSpecs: true,
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
