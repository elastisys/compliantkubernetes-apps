const { defineConfig } = require("cypress");

module.exports = defineConfig({
  env: process.env,
  e2e: {
    setupNodeEvents(on, config) {
      config.env = {
        ...process.env,
        ...config.env
      }
      return config
    },
    fixturesFolder: false,
    screenshotOnRunFailure: false,
    specPattern: "**.cy.js",
    supportFile: "cypress.support.js",
    defaultCommandTimeout: 10000,
  },
  experimentalMemoryManagement: true,
  numTestsKeptInMemory: 1
});
