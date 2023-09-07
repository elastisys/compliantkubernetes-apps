const { defineConfig } = require("cypress");

const supportFile = typeof process.env.ROOT === "undefined" ? "support/lib.js" : process.env.ROOT + "/test/common/cypress/support/lib.js"

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
    supportFile: supportFile,
  },
});
