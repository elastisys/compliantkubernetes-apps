const DEV_USER = 'dev@example.com'

const yqArgumentsToConfigFiles = (cluster, expression) => {
  const configPath = Cypress.env('CK8S_CONFIG_PATH')
  if (configPath === undefined) {
    cy.fail('yq: CK8S_CONFIG_PATH is unset')
  }

  if (cluster === undefined) {
    cy.fail('yq: cluster argument is missing')
  } else if (cluster !== 'sc' && cluster !== 'wc') {
    cy.fail('yq: cluster argument is invalid')
  }

  if (expression === undefined) {
    cy.fail('yq: expression argument is missing')
  }

  return `${configPath}/defaults/common-config.yaml ${configPath}/defaults/${cluster}-config.yaml ${configPath}/common-config.yaml ${configPath}/${cluster}-config.yaml`
}

const userToSession = function (user) {
  return user.replaceAll(/[^a-zA-Z]+/g, '-').replaceAll(/^-+|-+$/g, '')
}

// Available as cy.yq("sc|wc", "expression") merge first then expression
// More correct than yqDig for complex data such as maps that can be merged
Cypress.Commands.add('yq', (cluster, expression) => {
  const configFiles = yqArgumentsToConfigFiles(cluster, expression)

  cy.exec(
    `yq ea 'explode(.) as $item ireduce ({}; . * $item) | ${expression} | ...comments=""' ${configFiles}`
  ).its('stdout')
})

// Available as cy.yqDig("sc|wc", "expression") expression first then merge
// More efficient than yq for simple data such as scalars that cannot be merged
Cypress.Commands.add('yqDig', (cluster, expression) => {
  const configFiles = yqArgumentsToConfigFiles(cluster, expression)

  cy.exec(
    `yq ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`
  ).its('stdout')
})

// Available as cy.yqDigParse("sc|wc", "expression") expression first then merge
// More efficient for simple data such as scalars that cannot be merged
Cypress.Commands.add('yqDigParse', (cluster, expression) => {
  const configFiles = yqArgumentsToConfigFiles(cluster, expression)

  cy.exec(
    `yq -oj ea 'explode(.) | ${expression} | select(. != null) | {"wrapper": .} as $item ireduce ({}; . *$item) | .wrapper | ... comments=""' ${configFiles}`
  )
    .its('stdout')
    .then(JSON.parse)
})

// Available as cy.yqSecrets("expression") sops decrypt into yq expression
Cypress.Commands.add('yqSecrets', (expression) => {
  const configPath = Cypress.env('CK8S_CONFIG_PATH')
  if (configPath === undefined) {
    cy.fail('yqSecrets: CK8S_CONFIG_PATH is unset')
  }

  if (expression === undefined) {
    cy.fail('yqSecrets: expression argument is missing')
  }

  cy.exec(`sops -d ${configPath}/secrets.yaml | yq e '${expression} | ... comments=""'`).its(
    'stdout'
  )
})

// Available as cy.continueOn("sc|wc", "expression") expression should evaluate to true to continue
Cypress.Commands.add('continueOn', function (cluster, expression) {
  cy.yqDig(cluster, expression).then(function (result) {
    if (result !== 'true') {
      this.skip(`${cluster}/${expression} is disabled`)
    }
  })
})

Cypress.Commands.add('retryRequest', (options) => {
  const { request, condition, body, attempts = 10, waitTime = 5000 } = options

  cy.request(request).then((response) => {
    if (condition(response)) {
      body(response)
    } else {
      if (attempts > 0) {
        cy.wait(waitTime)
        cy.retryRequest({ ...options, attempts: attempts - 1 })
      } else {
        throw new Error('retryRequest failed')
      }
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

  cy.yqSecrets('.dex.extraStaticLogins | length').then(Number.parseInt).should('be.at.least', 1)

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

Cypress.Commands.add('visitProxiedWC', function (url, user = DEV_USER) {
  cy.yqDigParse('wc', '.user.adminUsers').then((adminUsers) => {
    if (!adminUsers.includes(user)) {
      cy.fail(
        `${user} not found in .user.adminUsers\n` +
          `Please add it and run 'ck8s ops helmfile wc -lapp=dev-rbac apply' to update the RBAC rules.`
      )
    }
  })

  cy.withTestKubeconfig({ session: userToSession(user), url, refresh: true }).then(() => {
    cy.task('wrapProxy', Cypress.env('KUBECONFIG')).then((dex_url) => {
      assert(dex_url, 'could not extract Dex URL from kube proxy')
      cy.visit(`${dex_url}`)
      cy.dexExtraStaticLogin(user)
    })
  })
})

Cypress.Commands.add('visitProxiedSC', function (url) {
  Cypress.env('KUBECONFIG', Cypress.env('CK8S_CONFIG_PATH') + '/.state/kube_config_sc.yaml')
  cy.task('wrapProxy', Cypress.env('KUBECONFIG')).then((dex_url) => {
    cy.visit(url, { retryOnStatusCodeFailure: dex_url !== true })
  })
})

Cypress.Commands.add('cleanupProxy', function (cluster, user = DEV_USER) {
  cy.task('pKill', 'kubeproxy-wrapper.sh')
  if (cluster === 'wc' && user !== null) {
    cy.deleteTestKubeconfig(userToSession(user))
  }
})

Cypress.Commands.add('withTestKubeconfig', function ({ session, url, refresh }) {
  const config_base = Cypress.env('CK8S_CONFIG_PATH') + '/.state/kube_config'
  const base_kubeconfig = `${config_base}_wc.yaml`
  const user_kubeconfig = `${config_base}_wc_${session}.yaml`
  Cypress.env('KUBECONFIG', user_kubeconfig)

  let userArguments = [
    `--token-cache-dir=~/.kube/cache/oidc-login/test-${session}`,
    '--skip-open-browser',
    '--force-refresh',
  ]
  if (url !== undefined) {
    userArguments.push(`--open-url-after-authentication=${url}`)
  }

  cy.exec(
    `yq '.users[0].user.exec.args += ${JSON.stringify(userArguments)}' < "${base_kubeconfig}" > ${user_kubeconfig}`
  ).its('stdout')

  if (refresh) {
    cy.exec(`rm -rf ~/.kube/cache/oidc-login/test-${session}`)
  }
})

Cypress.Commands.add('deleteTestKubeconfig', function (session) {
  const test_kubeconfig = Cypress.env('CK8S_CONFIG_PATH') + `/.state/kube_config_wc_${session}.yaml`
  cy.exec(`rm -f ${test_kubeconfig}`)
})
