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
Cypress.Commands.add("dexStaticLogin", function() {
  // Check if enabled
  cy.yqDig("sc", ".dex.enableStaticLogin")
    .then(staticLoginEnabled => {
      if (staticLoginEnabled !== "true") {
        cy.fail("dexStaticLogin: requires dex static login to be enabled")
      }
    })

  // Conditionally skip connector selection
  cy.yqSecrets(".dex.connectors | length")
    .then(connectors => {
      if (connectors !== "0") {
        cy.contains("Log in with Email")
          .click()
      }
    })

  // Fetch and type in credentials
  // The selection of the input is a bit weak but the field's label is in its own div
  cy.yqSecrets(".dex.staticPasswordNotHashed")
    .then(password => {
      cy.contains("Email Address")
        .parent()
        .parent()
        .find("input")
        .type("admin@example.com", { log: false })

      cy.contains("Password")
        .parent()
        .parent()
        .find("input")
        .type(password, { log: false })
    })

  // Finally login
  cy.contains("Login")
    .click()
})
