const { defineConfig } = require('cypress')
const { spawn } = require('node:child_process')

const DEFAULT_TIMEOUT = 60 * 1000

module.exports = defineConfig({
  env: process.env,
  e2e: {
    setupNodeEvents(on, config) {
      on('task', {
        log(message) {
          console.log(message)
        },
        kubectlLogin(kubeconfig) {
          return new Promise((resolve) => {
            process.env.KUBECONFIG = kubeconfig
            const child = spawn('kubectl', ['auth', 'whoami'], { stdio: 'ignore', detached: true })

            child.unref()

            resolve(true)
          })
        },
      })
      config.env = { ...process.env, ...config.env }
      return config
    },
    fixturesFolder: 'cypress/fixtures',
    screenshotOnRunFailure: false,
    specPattern: '**.cy.js',
    supportFile: 'common/cypress/support.js',
    defaultCommandTimeout: DEFAULT_TIMEOUT,
    execTimeout: DEFAULT_TIMEOUT,
    taskTimeout: DEFAULT_TIMEOUT,
    pageLoadTimeout: DEFAULT_TIMEOUT,
    requestTimeout: DEFAULT_TIMEOUT,
    responseTimeout: DEFAULT_TIMEOUT,
  },
  experimentalMemoryManagement: true,
  numTestsKeptInMemory: 1,
})
