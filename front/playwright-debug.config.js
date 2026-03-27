/** @type {import('@playwright/test').PlaywrightTestConfig} */
module.exports = {
  testDir: '.',
  testMatch: 'fluid-debug-test.js',
  timeout: 30000,
  use: {
    headless: true,
    baseURL: 'http://localhost:8000',
    screenshot: 'only-on-failure',
  },
};
