const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  collectCoverageFrom: [
    "force-app/main/default/lwc/**/*.js",
    "!force-app/main/default/lwc/**/__tests__/**",
  ],
  modulePathIgnorePatterns: ["<rootDir>/.sf"],
  transformIgnorePatterns: [
    "/node_modules/(?!(.*@lwc/state)|(.*@lwc/engine-dom)|(.*@salesforce/sfdx-lwc-jest/src/lightning-stubs)/)",
  ],
  coverageThreshold: {
    global: { branches: 55, functions: 80, lines: 80, statements: 80 },
  },
};
