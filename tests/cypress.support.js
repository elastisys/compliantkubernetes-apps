const yqArgsToConfigFiles = function (cluster, expression) {
  const configPath = Cypress.env('CK8S_CONFIG_PATH')
  if (typeof configPath === 'undefined') {
    cy.fail('yq: CK8S_CONFIG_PATH is unset')
  }

  if (typeof cluster === 'undefined') {
    cy.fail('yq: cluster argument is missing')
  } else if (cluster !== 'sc' && cluster !== 'wc') {
    cy.fail('yq: cluster argument is invalid')
  }

  if (typeof expression === 'undefined') {
    cy.fail('yq: expression argument is missing')
  }

  return `${configPath}/defaults/common-config.yaml ${configPath}/defaults/${cluster}-config.yaml ${configPath}/common-config.yaml ${configPath}/${cluster}-config.yaml`
}

// Available as cy.yq("sc|wc", "expression") merge first then expression
// More correct than yqDig for complex data such as maps that can be merged
Cypress.Commands.add('yq', (cluster, expression) => {
  const configFiles = yqArgsToConfigFiles(cluster, expression)

  cy.exec(
    `yq ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configFiles}`
  ).its('stdout')
})

// Available as cy.yqDig("sc|wc", "expression") expression first then merge
// More efficient than yq for simple data such as scalars that cannot be merged
Cypress.Commands.add('yqDig', (cluster, expression) => {
  const configFiles = yqArgsToConfigFiles(cluster, expression)

  cy.exec(
    `yq ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`
  ).its('stdout')
})

// Available as cy.yqDigParse("sc|wc", "expression") expression first then merge
// More efficient for simple data such as scalars that cannot be merged
Cypress.Commands.add('yqDigParse', (cluster, expression) => {
  const configFiles = yqArgsToConfigFiles(cluster, expression)

  cy.exec(
    `yq -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`
  )
    .its('stdout')
    .then(JSON.parse)
})

// Available as cy.yqSecrets("expression") sops decrypt into yq expression
Cypress.Commands.add('yqSecrets', (expression) => {
  const configPath = Cypress.env('CK8S_CONFIG_PATH')
  if (typeof configPath === 'undefined') {
    cy.fail('yqSecrets: CK8S_CONFIG_PATH is unset')
  }

  if (typeof expression === 'undefined') {
    cy.fail('yqSecrets: expression argument is missing')
  }

  cy.exec(`sops -d ${configPath}/secrets.yaml | yq e '${expression} | ... comments=""'`).its(
    'stdout'
  )
})

// Available as cy.continueOn("sc|wc", "expression") expression should evaluate to true to continue
Cypress.Commands.add('continueOn', function (cluster, expression) {
  cy.yqDig(cluster, expression).then((result) => {
    if (result !== 'true') {
      this.skip(`${cluster}/${expression} is disabled`)
    }
  })
})

// Available as cy.dexStaticLogin()
Cypress.Commands.add('dexStaticLogin', () => {
  // Requires dex static login to be enabled
  cy.yqDig('sc', '.dex.enableStaticLogin').should('equal', 'true')

  // Conditionally skip connector selection
  cy.yqSecrets('.dex.connectors | length').then((connectors) => {
    if (connectors !== '0') {
      cy.get('button').contains('Log in with Email').click()
    }
  })

  cy.yqSecrets('.dex.staticPasswordNotHashed').then((password) => {
    cy.get('input[placeholder*="email address"]').type('admin@example.com', { log: false })

    cy.get('input[placeholder*="password"]').type(password, { log: false })

    cy.get('button').contains('Login').click()
  })
})

// Available as cy.dexExtraStaticLogin()
Cypress.Commands.add('dexExtraStaticLogin', (email) => {
  // Requires dex static login to be enabled
  cy.yqDig('sc', '.dex.enableStaticLogin').should('equal', 'true')

  cy.yqSecrets('.dex.extraStaticLogins | length').then(parseInt).should('be.at.least', 1)

  // Conditionally skip connector selection
  cy.yqSecrets('.dex.connectors | length').then((connectors) => {
    if (connectors !== '0') {
      cy.get('button').contains('Log in with Email').click()
    }
  })

  cy.yqSecrets(`.dex.extraStaticLogins[] | select(.email == "${email}").password`).then(
    (password) => {
      cy.get('input[placeholder*="email address"]').type(email, { log: false })

      cy.get('input[placeholder*="password"]').type(password, { log: false })

      cy.get('button').contains('Login').click()
    }
  )
})

Cypress.Commands.add(
  'visitProxied',
  function ({ cluster, user, url, refresh, checkAdmin = false }) {
    if (checkAdmin) {
      cy.yqDigParse(cluster, '.user.adminUsers').then((adminUsers) => {
        if (!adminUsers.includes('dev@example.com')) {
          cy.fail(
            'dev@example.com not found in .user.adminUsers\n' +
              `Please add it and run 'ck8s ops helmfile ${cluster} -lapp=dev-rbac apply' to update the RBAC rules.`
          )
        }
      })
    }

    cy.withTestKubeconfig({ cluster, user, url, refresh }).then(() => {
      cy.task('wrapProxy', Cypress.env('KUBECONFIG')).then((redir_url) => {
        cy.visit(`${redir_url}`)
        cy.dexExtraStaticLogin('dev@example.com')
      })
    })
  }
)

Cypress.Commands.add('cleanupProxy', function ({ cluster, user }) {
  cy.task('pKill', 'kubeproxy-wrapper.sh')
  cy.deleteTestKubeconfig({ cluster, user })
})

Cypress.Commands.add('withTestKubeconfig', function ({ cluster, user, url = null, refresh }) {
  const config_base = Cypress.env('CK8S_CONFIG_PATH') + '/.state/kube_config'
  const base_kubeconfig = `${config_base}_${cluster}.yaml`
  const user_kubeconfig = `${config_base}_${cluster}_${user}.yaml`
  Cypress.env('KUBECONFIG', user_kubeconfig)

  let userArgs = [
    `--token-cache-dir=~/.kube/cache/oidc-login/test-${user}`,
    '--skip-open-browser',
    '--force-refresh',
  ]
  if (url !== null) {
    userArgs.push(`--open-url-after-authentication=${url}`)
  }

  cy.exec(
    `yq '.users[0].user.exec.args += ${JSON.stringify(userArgs)}' < "${base_kubeconfig}" > ${user_kubeconfig}`
  ).its('stdout')

  if (refresh) {
    cy.exec(`rm -rf ~/.kube/cache/oidc-login/test-${user}`)
  }
})

Cypress.Commands.add('deleteTestKubeconfig', function ({ cluster, user }) {
  const test_kubeconfig =
    Cypress.env('CK8S_CONFIG_PATH') + `/.state/kube_config_${cluster}_${user}.yaml`
  cy.exec(`rm ${test_kubeconfig}`)
})
