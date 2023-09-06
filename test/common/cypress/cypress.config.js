const { defineConfig } = require("cypress");

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    fixturesFolder: false,
    screenshotOnRunFailure: false,
    specPattern: "**.cy.js",
    supportFile: false,
  },
});
