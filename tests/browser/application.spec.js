import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import fs from 'node:fs';

const credentials = JSON.parse(fs.readFileSync('.runtime/demo-credentials.json', 'utf8').replace(/^\uFEFF/, ''));
const passenger = credentials.find(item => item.role === 'PASSENGER');
const manager = credentials.find(item => item.role === 'TRANSPORT_MANAGER');
const operator = credentials.find(item => item.role === 'ROUTE_OPERATOR');
const environment = Object.fromEntries(fs.readFileSync('.env', 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).map(line => line.split('=')));

async function signIn(page, account) {
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    await page.getByRole('textbox', { name: 'Email', exact: true }).fill(account.email);
    await page.getByLabel('Password', { exact: true }).fill(account.password);
    await page.locator('#submitAuth').click();
    await expect(page.getByRole('dialog')).not.toBeVisible();
}

test('public startup, keyboard dialog, themes and narrow layout', async ({ page }) => {
    const errors = [];
    page.on('pageerror', failure => errors.push(failure.message));
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Find your next trip' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'View trips' }).first()).toBeVisible();
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    await expect(page.getByRole('textbox', { name: 'Email', exact: true })).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).not.toBeVisible();
    await expect(page.locator('#authButton')).toBeFocused();
    for (const width of [1280, 320]) {
        await page.setViewportSize({ width, height: 850 });
        for (const theme of ['dark', 'light']) {
            if (await page.locator('html').getAttribute('data-theme') !== theme) await page.locator('#themeButton').click();
            const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
            expect(results.violations).toEqual([]);
            expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
            await page.screenshot({ path: `test-results/routes-${theme}-${width}.png`, fullPage: true });
        }
    }
    expect(errors).toEqual([]);
});

test('passenger purchases, views and refunds a ticket', async ({ page }) => {
    await page.goto('/');
    await signIn(page, passenger);
    await page.getByRole('link', { name: 'Trips', exact: true }).click();
    await page.getByRole('button', { name: 'Choose ticket', exact: true }).last().click();
    await page.getByLabel('Ticket type').selectOption('TEN_RIDE');
    await page.getByRole('button', { name: 'Reserve for 10 minutes' }).click();
    await expect(page.getByRole('heading', { name: 'Confirm payment' })).toBeVisible();
    await page.getByRole('button', { name: /^Pay / }).click();
    await expect(page.getByRole('heading', { name: 'My bookings', exact: true })).toBeVisible();
    await page.getByRole('link', { name: 'My tickets', exact: true }).click();
    page.once('dialog', dialog => dialog.accept());
    await page.getByRole('button', { name: 'Refund unused ticket' }).first().click();
    await expect(page.locator('#notice')).toContainText('refunded');
});

test('text enlargement, reduced motion and keyboard focus remain usable', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.setViewportSize({ width: 1280, height: 850 });
    await page.goto('/');
    // Accessibility: test 200% text enlargement separately from the existing 320px reflow checks.
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%'; });
    await expect(page.getByRole('button', { name: 'View trips' }).first()).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    expect(await page.locator('#content').evaluate(node => getComputedStyle(node).animationName)).toBe('none');
    await page.keyboard.press('Tab');
    await expect(page.getByRole('link', { name: 'Skip to content' })).toBeFocused();
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    await expect(page.getByRole('textbox', { name: 'Email', exact: true })).toBeFocused();
    await page.keyboard.press('Shift+Tab');
    await expect(page.locator('#closeAuth')).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(page.locator('#authButton')).toBeFocused();
});

test('staff permissions and reports use actual service data', async ({ page }) => {
    await page.goto('/');
    await signIn(page, manager);
    await expect(page.getByRole('heading', { name: 'Staff workspace' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Manage accounts', exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'Reports', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Transport report' })).toBeVisible();
    await expect(page.getByRole('table')).toBeVisible();
});

test('operator sees validation tasks without management actions', async ({ page }) => {
    await page.goto('/'); await signIn(page, operator);
    await expect(page.getByRole('button', { name: 'Manage routes', exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'Validate bookings', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Validate bookings' })).toBeVisible();
});

test('sign out clears local credentials when the server is unavailable', async ({ page }) => {
    await page.goto('/'); await signIn(page, passenger);
    await page.route('**/api/v1/passenger/logout', route => route.fulfill({status: 503,
        json: {error: {code: '503', message: 'Unavailable'}}}));
    await page.getByRole('button', {name: 'Sign out', exact: true}).click();
    await expect(page.locator('#authButton')).toHaveText('Sign in');
    expect(await page.evaluate(() => sessionStorage.getItem('uth.token'))).toBeNull();
});

test('administrator can review account access and audit records', async ({ page }) => {
    await page.goto('/');
    await signIn(page, { email: environment.UTH_ADMIN_EMAIL, password: environment.UTH_ADMIN_PASSWORD });
    await page.getByRole('button', { name: 'Manage accounts', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Manage accounts' })).toBeVisible();
    await page.getByRole('link', { name: 'Staff workspace', exact: true }).click();
    await page.getByRole('button', { name: 'Audit and delivery', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Audit records', exact: true })).toBeVisible();
});

test('API error and HTML payload remain readable and inert', async ({ page }) => {
    await page.route('**/api/v1/transport/routes?*', route => route.fulfill({ json: {
        items: [{ id: 'inert', name: '<img src=x onerror="window.injected=true">', startLocation: 'A', endLocation: 'B', baseFareMinor: 100, transportType: 'BUS' }],
        total: 1, limit: 20, offset: 0,
    } }));
    await page.goto('/');
    await expect(page.getByRole('heading', { name: '<img src=x onerror="window.injected=true">' })).toBeVisible();
    expect(await page.evaluate(() => window.injected)).toBeUndefined();
    await page.unroute('**/api/v1/transport/routes?*');
    await page.route('**/api/v1/transport/trips?*', route => route.fulfill({ status: 503, json: { error: { message: 'Service unavailable. Try again.' } } }));
    await page.getByRole('link', { name: 'Trips', exact: true }).click();
    await expect(page.getByRole('alert')).toContainText('Service unavailable');
    await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();
});

test('late responses cannot replace newer navigation', async ({ page }) => {
    let release;
    const gate = new Promise(resolve => { release = resolve; });
    await page.route('**/api/v1/transport/routes?*', async route => {
        await gate;
        await route.fulfill({ json: { items: [], total: 0, limit: 20, offset: 0 } });
    });
    await page.goto('/', { waitUntil: 'commit' });
    await page.getByRole('link', { name: 'Trips', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Upcoming trips' })).toBeVisible();
    const response = page.waitForResponse('**/api/v1/transport/routes?*');
    release();
    await (await response).finished();
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await expect(page.getByRole('heading', { name: 'Upcoming trips' })).toBeVisible();
});

test('unknown roles cannot open staff navigation', async ({ page }) => {
    await page.addInitScript(() => sessionStorage.setItem('uth.token', 'test-token'));
    await page.route('**/api/v1/passenger/me', route => route.fulfill({ json: { id: 'test', role: 'OPERATOR', firstName: 'Unknown' } }));
    await page.goto('/#staff');
    await expect(page.getByRole('heading', { name: 'Find your next trip' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Staff workspace', exact: true })).toHaveCount(0);
});

test('manager creates, edits and cancels transport through the UI', async ({ page, request }) => {
    test.setTimeout(90000);
    let routeId;
    let tripId;
    let retired = false;
    await page.goto('/'); await signIn(page, manager);
    const token = await page.evaluate(() => sessionStorage.getItem('uth.token'));
    const headers = { Authorization: `Bearer ${token}` };
    const routeName = `Browser route ${crypto.randomUUID()}`;
    try {
        await page.getByRole('button', { name: 'Manage routes', exact: true }).click();
        await page.getByRole('button', { name: 'Create route', exact: true }).click();
        await page.getByLabel('Route name', { exact: true }).fill(routeName);
        await page.getByLabel('Start location', { exact: true }).fill('Browser start');
        await page.getByLabel('End location', { exact: true }).fill('Browser destination');
        await page.getByLabel('Base fare (NAD)', { exact: true }).fill('12.50');
        const routeResponse = page.waitForResponse(response => response.url().endsWith('/transport/routes') && response.request().method() === 'POST');
        await page.getByRole('button', { name: 'Save route', exact: true }).click();
        const createdRoute = await routeResponse;
        expect(createdRoute.status()).toBe(200); routeId = (await createdRoute.json()).id;
        await page.getByRole('link', { name: 'Staff workspace', exact: true }).click();
        await page.getByRole('button', { name: 'Manage trips', exact: true }).click();
        await page.getByRole('button', { name: 'Create trip', exact: true }).click();
        await page.getByRole('combobox', { name: 'Route', exact: true }).selectOption({ label: routeName });
        const local = minutes => {
            const time = new Date(Date.now() + minutes * 60000);
            return new Date(time - time.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
        };
        await page.getByLabel('Departure (your local time)', { exact: true }).fill(local(60));
        await page.getByLabel('Arrival (your local time)', { exact: true }).fill(local(90));
        const tripResponse = page.waitForResponse(response => response.url().endsWith('/transport/trips') && response.request().method() === 'POST', { timeout: 10000 });
        await page.getByRole('button', { name: 'Save trip', exact: true }).click();
        const createdTrip = await tripResponse;
        expect(createdTrip.status()).toBe(200); tripId = (await createdTrip.json()).id;
        const tripRow = page.getByRole('article').filter({ has: page.getByRole('heading', { name: routeName, exact: true }) });
        await tripRow.getByRole('button', { name: 'Edit schedule', exact: true }).click();
        await page.getByLabel('Seats', { exact: true }).fill('41');
        await page.getByRole('button', { name: 'Save trip', exact: true }).click();
        await expect(tripRow).toContainText('41 / 41');
        page.once('dialog', dialog => dialog.accept());
        await tripRow.getByRole('button', { name: 'Cancel trip', exact: true }).click();
        await expect(page.locator('#notice')).toContainText('Trip cancelled');
        await page.getByRole('link', { name: 'Staff workspace', exact: true }).click();
        await page.getByRole('button', { name: 'Manage routes', exact: true }).click();
        const routeRow = page.getByRole('article').filter({ has: page.getByRole('heading', { name: routeName, exact: true }) });
        page.once('dialog', dialog => dialog.accept());
        await routeRow.getByRole('button', { name: 'Retire', exact: true }).click();
        await expect(routeRow).toHaveCount(0); retired = true;
    } finally {
        if (tripId) expect((await request.post(`/api/v1/transport/trips/${tripId}/cancel`, { headers, data: {} })).status()).toBe(200);
        if (routeId && !retired) expect((await request.delete(`/api/v1/transport/routes/${routeId}`, { headers })).status()).toBe(200);
    }
});
