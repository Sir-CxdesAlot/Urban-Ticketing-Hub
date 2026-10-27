import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './tests/browser',
    timeout: 45000,
    expect: { timeout: 10000 },
    fullyParallel: false,
    workers: 1,
    retries: 0,
    reporter: [['list'], ['html', { open: 'never' }]],
    use: { baseURL: process.env.UTH_TEST_BASE_URL || 'http://localhost:8080',
        browserName: 'chromium', trace: 'off', screenshot: 'only-on-failure' },
});
