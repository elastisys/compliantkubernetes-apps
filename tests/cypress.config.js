import { defineConfig } from 'cypress'

import { spawn } from 'node:child_process'

import path from 'node:path'

const PROXY_READY_MARKER = '%%PROXY_READY%%'
const PROXY_WAITING_FOR_DEX_MARKER = '%%PROXY_WAITING_FOR_DEX%%'
const DEFAULT_TIMEOUT = 60 * 1000

export default defineConfig({
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

            resolve(-1)
          })
        },
        wrapProxy(kubeconfig) {
          process.env.KUBECONFIG = kubeconfig
          const batsFile = /** @type {string} */ (process.env.BATS_TEST_FILENAME)
          const wrapperPath = path.resolve(
            path.dirname(batsFile) + '/../../../scripts/kubeproxy-wrapper.sh'
          )

          const proxy = spawn(wrapperPath, [], {
            detached: true,
            stdio: ['ignore', 'pipe', 'pipe'],
          })
          return new Promise((resolve) => {
            proxy.stdout.on('data', (data) => {
              if (data.includes(PROXY_WAITING_FOR_DEX_MARKER)) {
                resolve(data.toString().split(' ')[1])
              } else if (data.includes(PROXY_READY_MARKER)) {
                resolve(-1)
              }
            })
          })
        },
        pKill(name) {
          return new Promise((resolve) => {
            spawn('pkill', ['-f', name], { detached: true, stdio: 'ignore' })
            resolve(-1)
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
