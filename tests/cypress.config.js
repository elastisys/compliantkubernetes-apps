const { defineConfig } = require('cypress')

const PROXY_READY_MARKER = '%%PROXY_READY%%'

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
          return new Promise((resolve) => {
            process.env.KUBECONFIG = kubeconfig
            const child = spawn('kubectl', ['auth', 'whoami'], { stdio: 'ignore', detached: true })

            child.unref()

            resolve(null)
          })
        },
        wrapProxy(kubeconfig) {
          process.env.KUBECONFIG = kubeconfig

          const path = require('path')
          const wrapperPath = path.resolve(
            path.dirname(process.env.BATS_TEST_FILENAME) + '/../../../scripts/kubeproxy-wrapper.sh'
          )

          const proxy = spawn(wrapperPath, [], {
            detached: true,
            stdio: ['ignore', 'pipe', 'pipe'],
          })
          return new Promise((resolve) => {
            proxy.stdout.on('data', (data) => {
              if (data.includes(PROXY_READY_MARKER)) {
                const redirectUrl = data.toString().split(' ')[1]
                resolve(redirectUrl)
              }
            })
          })
        },
        pKill(name) {
          return new Promise((resolve) => {
            spawn('pkill', ['-f', name], { detached: true, stdio: 'ignore' })
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
