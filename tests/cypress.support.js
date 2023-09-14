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

// Available as cy.yqDigParse("sc|wc", "expression") expression first then merge
// More efficient for simple data such as scalars that cannot be merged
Cypress.Commands.add("yqDigParse", function(cluster, expression) {
  if (typeof cluster === "undefined") {
    cy.fail("yqDigParse: cluster argument is missing")

  } else if (typeof expression === "undefined") {
    cy.fail("yqDigParse: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("yqDigParse: CK8S_CONFIG_PATH is unset")
  }

  if (cluster === "sc") {
    cy.exec(`yq4 -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)
      .its("stdout")
      .then(JSON.parse)

  } else if (cluster === "wc") {
    cy.exec(`yq4 -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)
      .its("stdout")
      .then(JSON.parse)

  } else {
    cy.fail("yqDigParse: cluster argument is invalid")
  }
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

// Available as cy.dexStaticUserLogin() requires dex static login to be enabled
Cypress.Commands.add("dexStaticUserLogin", function(username, loginUrl, cookieName) {
  // Check if static login is enabled
  cy.yqDig("sc", ".dex.enableStaticLogin")
    .then(staticLoginEnabled => {
      if (staticLoginEnabled !== "true") {
        cy.fail("dexStaticLogin: requires dex static login to be enabled")
      }
    })

  cy.session([username, loginUrl, cookieName], () => {
    cy.visit(loginUrl)

    // this is needed for Grafana
    cy.title().then(($title) => {
      if ($title === 'Grafana') {
        cy.contains("Sign in with dex").click()
      }
    })

    // Conditionally skip connector selection
    cy.yqSecrets(".dex.connectors | length")
      .then(connectors => {
        if (connectors !== "0") {
          cy.contains('button', 'Log in with Email').click()
        }
      })
    cy.get('input#login').type(username)
    cy.yqSecrets(".dex.staticPasswordNotHashed")
      .then(password => {
        // {enter} causes the form to submit
        cy.get('input#password').type(`${password}{enter}`, { log: false })
      })
    // this is needed for Harbor first time login
    cy.title().then(($title) => {
      if ($title === 'Harbor') {
        cy.wait(1000)
        cy.get("body").then(($body) => {
          const hasOidcBanner = $body[0].querySelectorAll("*[class='modal-title oidc-header-text']")
          cy.log(hasOidcBanner)
          if (hasOidcBanner.length > 0) {
            cy.get('input[name=oidcUsername]').clear().type('cypress_static_user')
            cy.contains('button', 'SAVE').click()
          }
        })
      }
    })
    // Ensure Auth0 has redirected us back to the original URL
    cy.url().should('include', loginUrl)
    cy.getCookie(cookieName).should('exist')
  },
  )
})

// Available as cy.staticLogin("username", "password expression", "url for login", "username field name", "password field name", "path to test after login", "session cookie name")
Cypress.Commands.add('staticLogin', (username, passwordExpression, userField, passField, loginUrl, landingPath, cookieName) => {
  cy.session([username, passwordExpression, cookieName], () => {
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
    cy.url().should('include', landingPath)
    cy.getCookie(cookieName).should('exist')
  },
  )
})
