const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  roots: ["<rootDir>/force-app"],
  modulePathIgnorePatterns: ["<rootDir>/.sfdx/", "<rootDir>/.sf/"],
  transformIgnorePatterns: [
    "/node_modules/(?!(.*@lwc/state)|(.*@lwc/engine-dom)|(.*@salesforce/sfdx-lwc-jest/src/lightning-stubs)/)"
  ],
  collectCoverageFrom: [
    "force-app/main/default/lwc/**/*.js",
    "!force-app/main/default/lwc/**/__tests__/**"
  ],
  coverageThreshold: {
    global: { branches: 80, functions: 90, lines: 90, statements: 90 }
  }
};
