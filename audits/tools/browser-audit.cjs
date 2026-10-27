// Isolated browser probes. All service traffic is intercepted; no backend data is changed.
// Run: node audits/tools/browser-audit.cjs <absolute playwright package directory>
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require(process.argv[2] || 'playwright');
const root = path.resolve(__dirname, '../../ui');
const out = path.resolve(__dirname, '../evidence');
fs.mkdirSync(out, { recursive: true });
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.gif': 'image/gif' };
const server = http.createServer((req, res) => {
  const file = path.resolve(root, '.' + decodeURIComponent(req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0]));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, data) => { if (err) res.writeHead(404).end(); else { res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream'); res.end(data); } });
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  const results = { environment: 'Synthetic service responses derived from source contracts; not live backend tests', requests: [], errors: [], probes: {} };
  let maliciousRouteFixture = false;
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await context.newPage();
    page.on('pageerror', err => results.errors.push(err.message));
    await page.route(/^http:\/\/localhost:808[1-6]\//, async route => {
      const req = route.request(); const url = new URL(req.url());
      results.requests.push({ method: req.method(), path: url.pathname, body: req.postData() });
      let body = []; let status = 200;
      if (url.pathname === '/api/v1/transport/routes') body = [{ _id: '123456789012345678901234', name: maliciousRouteFixture ? '<img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" onload="window.__auditStoredMarkup=true">' : 'Audit Route', startLocation: 'Central', endLocation: 'University', intermediateStops: ['Market'], transportType: 'BUS', basePrice: 15.5, isActive: true }];
      else if (url.pathname === '/api/v1/transport/trips' || url.pathname.endsWith('/trips')) body = [{ _id: '123456789012345678901235', routeId: '123456789012345678901234', departureTime: '2026-10-28T08:00:00Z', arrivalTime: '2026-10-28T09:00:00Z', availableSeats: 4, totalSeats: 45, status: 'SCHEDULED' }];
      else if (url.pathname === '/api/v1/admin/login') {
        const data = JSON.parse(req.postData() || '{}');
        if (!data.username) { status = 400; body = { message: 'missing required field username (source contract)' }; }
        else body = { success: true, adminId: 'audit-admin', username: 'audit', role: 'SUPER_ADMIN' };
      } else if (url.pathname.endsWith('/health')) body = 'Service is running';
      else if (url.pathname === '/api/v1/passenger/login') { status = 401; body = { message: 'Invalid credentials' }; }
      else if (url.pathname === '/api/v1/ticketing/purchase') { status = 404; body = { message: 'Resource not found (source contract)' }; }
      else if (url.pathname === '/api/v1/admin/dashboard') body = { totalUsers: 3, totalRoutes: 1, totalTickets: 0, activeTickets: 0, successfulPayments: 0, activeDisruptions: 0, systemStatus: 'OPERATIONAL' };
      else { status = 404; body = { message: 'No synthetic fixture for source resource' }; }
      await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body), headers: { 'access-control-allow-origin': '*' } });
    });
    page.on('dialog', dialog => dialog.dismiss());
    await page.goto(`http://127.0.0.1:${server.address().port}/`, { waitUntil: 'networkidle' });
    results.probes.initial = await page.evaluate(() => ({
      title: document.title,
      duplicateIds: [...document.querySelectorAll('[id]')].map(e => e.id).filter((id,i,a) => a.indexOf(id) !== i),
      brokenImages: [...document.images].filter(e => !e.complete || e.naturalWidth === 0).map(e => e.src),
      horizontalOverflow: document.documentElement.scrollWidth > innerWidth,
      roles: Object.keys(App.api.ROLES),
      unknownRolePasses: App.api.hasMinimumRole('OPERATOR'),
      guestCanReadAdmin: App.api.hasMinimumRole('SUPER_ADMIN'),
      apiKeys: Object.keys(App.api)
    }));
    await page.screenshot({ path: path.join(out, 'desktop-dark.png'), fullPage: true });
    await page.locator('#loginBtn').click();
    results.probes.loginModal = await page.evaluate(() => {
      const el = document.getElementById('loginModal');
      return { role: el.getAttribute('role'), ariaModal: el.getAttribute('aria-modal'), labelledby: el.getAttribute('aria-labelledby'), focused: document.activeElement.id, open: !el.hidden };
    });
    await page.keyboard.press('Escape');
    results.probes.escapeClosesLogin = await page.locator('#loginModal').evaluate(e => e.hidden);
    await page.locator('#closeLoginModal').click();
    results.probes.adminLogin = await page.evaluate(async () => ({ result: await App.api.adminLogin('audit', 'synthetic'), loggedIn: App.api.session.loggedIn }));
    await page.evaluate(() => { Object.assign(App.api.session, { loggedIn: true, guestMode: false, userRole: 'PASSENGER', userId: 'audit-passenger', user: { id: 'audit-passenger' }, token: 'synthetic' }); });
    results.probes.purchase = await page.evaluate(() => App.api.purchaseTicket({ tripId: '123456789012345678901235', quantity: 1, paymentMethod: 'CARD' }));
    results.probes.passengerUnknownRolePasses = await page.evaluate(() => App.api.hasMinimumRole('OPERATOR'));
    results.probes.missingApiReferences = await page.evaluate(() => {
      return { processPayment: typeof App.api.processPayment, requestRefund: typeof App.api.requestRefund, getSession: typeof App.api.getSession };
    });
    await page.evaluate(() => { App.api.clearSession(); App.permissions.refresh(); App.theme.applyTheme('light'); });
    await page.setViewportSize({ width: 390, height: 844 });
    results.probes.mobile = await page.evaluate(() => ({ width: innerWidth, scrollWidth: document.documentElement.scrollWidth, overflowElements: [...document.querySelectorAll('body *')].filter(e => { const r=e.getBoundingClientRect(); return r.width && r.right > innerWidth + 1 && getComputedStyle(e).position !== 'fixed'; }).slice(0,12).map(e => ({ tag:e.tagName, id:e.id, class:e.className })) }));
    await page.screenshot({ path: path.join(out, 'mobile-light.png'), fullPage: true });
    await page.setViewportSize({ width: 320, height: 800 });
    results.probes.narrow = await page.evaluate(() => ({ width: innerWidth, scrollWidth: document.documentElement.scrollWidth }));
    results.probes.a11y = await page.evaluate(() => ({
      unlabeledInputs: [...document.querySelectorAll('input,select,textarea')].filter(e => e.type !== 'hidden' && !e.labels?.length && !e.getAttribute('aria-label') && !e.getAttribute('aria-labelledby')).map(e => e.id),
      emptyButtons: [...document.querySelectorAll('button')].filter(e => !e.textContent.trim() && !e.getAttribute('aria-label') && !e.getAttribute('title') && !e.querySelector('img[alt]:not([alt=""])')).map(e => e.id),
      smallVisibleTargets: [...document.querySelectorAll('button,a,input,select')].filter(e => {const r=e.getBoundingClientRect(); return r.width>0 && r.height>0 && (r.width<24 || r.height<24);}).map(e => ({id:e.id,text:e.textContent.trim().slice(0,40),width:e.getBoundingClientRect().width,height:e.getBoundingClientRect().height})).slice(0,20)
    }));
    // Exercise the actual renderer with a non-networking marker, not an external payload.
    results.probes.tripMarkupInjection = await page.evaluate(async () => {
      const safe = '<img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" onload="window.__auditMarkup=true">';
      App.modals.openTicketModal({ routeName:safe, departureTime:'08:00', arrivalTime:'09:00', price:15, availableSeats:2 });
      await new Promise(resolve => setTimeout(resolve,50));
      return { inserted: !!document.querySelector('#tripDetails img[onload]'), executed: window.__auditMarkup === true };
    });
    await page.evaluate(() => App.modals.close('ticket'));
    // Second, final visual pass: explicitly initialize routes to diagnose startup order.
    await page.evaluate(() => { App.theme.applyTheme('dark'); return App.routeBrowser.displayRoutes(); });
    await page.setViewportSize({ width: 1440, height: 900 });
    results.probes.loadedRoutes = await page.locator('#routeCount').textContent();
    results.probes.actionCardStyles = await page.locator('.action-card p').first().evaluate(e => ({ foreground:getComputedStyle(e).color, background:getComputedStyle(e.closest('.action-card')).backgroundColor }));
    await page.screenshot({ path:path.join(out,'desktop-dark-loaded.png'), fullPage:true });
    await page.evaluate(() => App.theme.applyTheme('light'));
    await page.setViewportSize({ width:390,height:844 });
    results.probes.bannerButtonStyles = await page.locator('#guestLoginBtn').evaluate(e => ({ foreground:getComputedStyle(e).color, background:getComputedStyle(e).backgroundColor, backgroundImage:getComputedStyle(e).backgroundImage }));
    await page.screenshot({ path:path.join(out,'mobile-light-loaded.png'), fullPage:true });
    await page.setViewportSize({width:320,height:800});
    results.probes.narrowOverflowElements = await page.evaluate(() => [...document.querySelectorAll('body *')].filter(e=>{const r=e.getBoundingClientRect();return r.width && r.right>innerWidth+1 && getComputedStyle(e).position!=='fixed';}).slice(0,12).map(e=>({tag:e.tagName,id:e.id,class:e.className,width:e.getBoundingClientRect().width,right:e.getBoundingClientRect().right})));
    results.probes.darkBadgeToken = await page.evaluate(() => { App.theme.applyTheme('dark'); return {root:document.documentElement.className,dataTheme:document.documentElement.dataset.theme,badgeRulesMatch:!!document.querySelector('[data-theme="dark"] .badge')}; });
    maliciousRouteFixture = true;
    await page.evaluate(async () => { await testFetchRoutes(); await new Promise(resolve=>setTimeout(resolve,50)); });
    results.probes.storedRouteMarkupInjection = await page.evaluate(() => ({ inserted:!!document.querySelector('#routesResult img[onload]'), executed:window.__auditStoredMarkup===true }));
    fs.writeFileSync(path.join(out, 'browser-probes.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results, null, 2));
  } finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
})().catch(err => { console.error(err); server.close(); process.exitCode=1; });
