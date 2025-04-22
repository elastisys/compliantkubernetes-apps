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

  cy.exec(`yq ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configFiles}`)
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

  cy.exec(`yq ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`)
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
    cy.exec(`yq -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)
      .its("stdout")
      .then(JSON.parse)

  } else if (cluster === "wc") {
    cy.exec(`yq -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)
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

  cy.exec(`sops -d ${configPath}/secrets.yaml | yq e '${expression} | ... comments=""'`)
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

// Available as cy.dexStaticLogin()
Cypress.Commands.add("dexStaticLogin", () => {
  // Requires dex static login to be enabled
  cy.yqDig("sc", ".dex.enableStaticLogin")
    .should("equal", "true")

  // Conditionally skip connector selection
  cy.yqSecrets(".dex.connectors | length")
    .then(connectors => {
      if (connectors !== "0") {
        cy.get("button")
          .contains("Log in with Email")
          .click()
      }
    })

  cy.yqSecrets(".dex.staticPasswordNotHashed")
    .then(password => {
      cy.get('input[placeholder*="email address"]')
        .type("admin@example.com", { log: false })

      cy.get('input[placeholder*="password"]')
        .type(password, { log: false })

      cy.get("button")
        .contains("Login")
        .click()
    })
})
