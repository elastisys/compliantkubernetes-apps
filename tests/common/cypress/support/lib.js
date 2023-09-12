// Available as cy.yq("sc|wc" "expression") merge first then expression
// More correct for complex data such as maps that can be merged
Cypress.Commands.add("yq", function(cluster, expression) {
  if (typeof cluster === "undefined") {
    cy.fail("getConfig: cluster argument is missing")

  } else if (typeof expression === "undefined") {
    cy.fail("getConfig: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("getConfig: CK8S_CONFIG_PATH is unset")
  }

  if (cluster === "sc") {
    cy.exec(`yq4 ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)

  } else if (cluster === "wc") {
    cy.exec(`yq4 ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)

  } else {
    cy.fail("getConfig: cluster argument is invalid")
  }
})

// Available as cy.yqDig("sc|wc" "expression") expression first then merge
// More efficient for simple data such as scalars that cannot be merged
Cypress.Commands.add("yqDig", function(cluster, expression) {
  if (typeof cluster === "undefined") {
    cy.fail("getConfig: cluster argument is missing")

  } else if (typeof expression === "undefined") {
    cy.fail("getConfig: expression argument is missing")
  }

  const configPath = Cypress.env("CK8S_CONFIG_PATH")
  if (typeof configPath === "undefined") {
    cy.fail("getConfig: CK8S_CONFIG_PATH is unset")
  }

  if (cluster === "sc") {
    cy.exec(`yq4 ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/sc-config.yaml ${configPath}/common-config.yaml ${configPath}/sc-config.yaml`)

  } else if (cluster === "wc") {
    cy.exec(`yq4 ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configPath}/defaults/common-config.yaml ${configPath}/defaults/wc-config.yaml ${configPath}/common-config.yaml ${configPath}/wc-config.yaml`)

  } else {
    cy.fail("getConfig: cluster argument is invalid")
  }
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
