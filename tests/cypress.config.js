const { defineConfig } = require('cypress')

module.exports = defineConfig({
  env: process.env,
  e2e: {
    setupNodeEvents(on, config) {
      const { spawn } = require('child_process')

      on('task', {
        log(message) {
          console.log(message)
          return null
        },
        kubectlLogin(kubeconfig) {
          return new Promise((resolve, reject) => {
            process.env.KUBECONFIG = kubeconfig
            var child = spawn('kubectl', ['auth', 'whoami'], {
              stdio: 'ignore',
              detached: true,
            }).unref()

            resolve(null)
          })
        },
      })
      config.env = { ...process.env, ...config.env }
      return config
    },
    fixturesFolder: false,
    screenshotOnRunFailure: false,
    specPattern: '**.cy.js',
    supportFile: 'cypress.support.js',
    defaultCommandTimeout: 10000,
  },
  experimentalMemoryManagement: true,
  numTestsKeptInMemory: 1,
})
