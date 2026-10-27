# Browser UI audit

## Implementation integrity verdict

**Fail.** The interface has a recognizable transport structure, but startup, authentication, purchase, payment, notification, and search contracts are inconsistent with the services. Legacy student-management modules are loaded into the ticketing page, and some dashboard figures are placeholders presented as measured data. These are verified implementation defects, not judgments about visual taste.

Evidence includes desktop dark and mobile light browser captures, 320px layout measurements, local execution of actual renderers, and source review. Backend responses in browser probes were synthetic fixtures derived from service source; no live service integration is claimed. See [validation](06-VALIDATION.md) and [probe data](evidence/browser-probes.json).

## Audit health score

Scores are ordinal engineering judgments under the Impeccable playbook, not automated compliance percentages.

| Dimension | Score / 4 | Principal evidence |
|---|---:|---|
| Accessibility | 1 | Dialog focus/semantics missing; unreadable dark text/icons |
| Performance | 2 | Small native JS app, but CSS import chain and repeated full-list requests |
| Responsive design | 2 | 390px basic layout fits; header clips at 320px |
| Theming | 1 | Undefined text tokens and incompatible dark selectors |
| Implementation integrity | 1 | Multiple core flows use incompatible API contracts |
| **Total** | **7 / 20 — Poor** | Substantial functional and accessibility work remains |

Security defects are counted in SEC-09/SEC-10. Frontend issues below use P0–P3 user-impact priorities in addition to project-wide severity. P0 here means a core user task is blocked, not the highest security severity.

## UI-01 — High / P0: first load never fetches passenger routes

**Location:** `ui/index.html:902–910`; `menu.js:193–243`; `route-browser.js:18–30`; `api.js:1014–1035`.

With deferred classic scripts, menu initialization can run while later modules are still unavailable. It switches to passenger and calls route-browser only if already defined. Route-browser initialization attaches close handlers but never loads routes. Browser evidence shows zero automatic API requests and a permanent “Loading routes...” placeholder; explicitly calling `App.routeBrowser.displayRoutes()` loads the fixture immediately.

**Correction:** use one ordered application bootstrap that runs after all modules are registered. **Acceptance:** a fresh guest/passenger load requests routes once and reaches a data, empty, or recoverable error state. **Suggested command:** `$impeccable harden`.

## UI-02 — High / P0: browser API routes and payloads do not match services

**Location:** `api.js:22–47,341–365,405–411,822–885`; `ticketing.js:158–207`; `payment.js:10–19`; `notification.js:10–20`.

| Browser operation | Browser contract | Implemented service contract |
|---|---|---|
| Admin login | `{email,password}`, expects `{token,user}` | `{username,password}`, returns `{success,adminId,username,role}` |
| Route lookup | `/transport/route/{id}` | `/transport/routes/{id}` |
| Purchase | POST `/ticketing/purchase`, quantity/payment method, expects `ticketId` | POST `/ticketing/tickets`, requires passengerId/routeId/tripId/ticketType/price, returns `id` |
| Validate | POST `/ticketing/validate`, expects `valid` | PUT `/ticketing/tickets/{id}/validate`, returns `success` |
| Payment create | `/payment/process` | `/payment/payments` |
| Payment history/detail/refund | `/history`, `/transaction/{id}`, `/refund` | `/passengers/{id}/payments`, `/payments/{id}`, `/payments/{id}/refund` |
| Payment methods | `/payment/methods` | No resource |
| Notifications | `/list`, `/unread`, `/mark-read`, `/preferences` | `/users/{id}/notifications`, `/notifications/{id}/read`; no preferences resource |

Browser probes confirmed the admin request's wrong property and purchase's nonexistent path. This table is based on source comparison; a mocked 404 is not a live backend test. Some statistics paths do exist but their expected response fields still differ. Admin view initialization also calls the nonexistent `APIModule.isLoggedIn()` (`admin.js:719`), causing a TypeError before its normal setup.

Transport also has no explicit CORS configuration, unlike the other services. The browser sends `Content-Type: application/json` even on GET requests (`api.js:228–243`), triggering preflight across origins. The installed HTTP module's default allowed-origin list is empty. Cross-origin transport access needs an explicit allowed UI origin or a same-origin proxy; this deployment behavior was not live-tested. All clients also hardcode localhost HTTP ports, which do not point to the server when the page is opened on another machine.

**Correction:** establish a versioned API contract and a single typed/generated client; align server, browser, CLI, and tests together; configure deployment-specific origins or same-origin routing. **Acceptance:** real isolated end-to-end tests complete each operation with documented request/response shapes from the intended browser origin. **Suggested command:** `$impeccable harden`.

## UI-03 — High / P1: global search discards valid route and trip results

**Location:** `search.js:284–329,443–483`; compare `api.js:423–458,533–567`.

Search helpers return arrays, but the global search adapter requires `.data`, so it discards route/trip results. It passes a `query` property that those helpers do not filter on. Result renderers expect `origin/destination`, `routeId/id`, and `tripId/id`, whereas transport provides `startLocation/endLocation` and `_id` in list projections. Schedule searching separately fetches trips again. Users can receive empty or unusable search results despite matching data.

**Correction:** normalize one search result model and apply query filtering explicitly; preserve usable IDs. **Acceptance:** search by route name, stop, trip time, and ticket ID returns the correct selectable results and ignores stale responses. **Suggested command:** `$impeccable harden`.

## UI-04 — High / P1: unknown role checks fail open and navigation bypasses its own gates

**Location:** `api.js:161–170,910–1007`; `menu.js:32–52,113–180,225–243`; `permissions.js:14–18`.

Unknown `requiredRole` defaults to level 0. Admin helper calls check the undefined role `OPERATOR`; local probes show both guest and passenger pass `hasMinimumRole('OPERATOR')`. Service access is used to hide menu items, but `switchService()` and hash changes do not enforce it. Local storage can also replace the whole session and role. These frontend bugs expose inappropriate UI; SEC-01 is the separate, more serious missing server enforcement.

**Correction:** reject unknown roles, check service access on every transition, validate restored session state, and use server-authorized capabilities. **Acceptance:** invalid roles fail closed and direct hashes cannot open disallowed views; the server still rejects direct unauthorized requests. **Suggested command:** `$impeccable harden`.

## UI-05 — Medium / P1: modal keyboard interaction and semantics are incomplete

**Location:** login/register/ticket/route-trip markup in `ui/index.html`; `controller.js:45–59`; `route-browser.js:153–205`.

Dialogs use generic divs without dialog role, modal state, or labelled-by linkage. Opening login leaves focus on the header's login button; Escape does not close it. There is no focus containment, background inertness, or reliable focus restoration. Errors are exposed visually without consistently linked field descriptions/live announcements.

**Standard:** WCAG 2.2 2.4.3, 4.1.2, and 4.1.3; keyboard behavior requires manual assistive-technology confirmation. Escape is a dialog usability convention, not by itself a blanket WCAG failure.

**Correction:** use native `<dialog>` or an accessible modal implementation with labelled title, initial/return focus, dismissal, inert background, and associated errors. **Acceptance:** complete login, registration, and purchase using keyboard/screen reader without escaping into background controls. **Suggested command:** `$impeccable harden`.

## UI-06 — Medium / P1: theme drift causes failed contrast and inconsistent components

**Location:** `menu.css:269–273`; `cards.css:60–78`; `theme.js:6–9`; all theme/base tokens; `route-browser.css:66–72`.

Action-card descriptions use undefined `--text-secondary`; their computed color is black in dark mode. Against the dark base this is approximately 1.1:1, far below normal-text AA contrast. Dark SVG menu/ticket/profile icons also disappear into dark backgrounds. CSS uses undefined `--text-primary`, `--text-secondary`, and `--hover-bg` in several components. Badge dark rules require `[data-theme="dark"]`, but theme code applies `.dark`; browser evidence confirms no matching dark badge selector. Light route cards also retain overly dark panel styling, visible in the capture.

**Standard:** WCAG 1.4.3 and 1.4.11 for the confirmed text/icon examples; no claim that every color combination was measured.

A whole-file token scan found 40 unresolved uses without fallbacks across 14 token names, including a separate undefined `--color-*` family in search results (see `evidence/css-token-check.json`).

**Correction:** standardize tokens/selectors, set form/button foregrounds deliberately, and adapt SVG fills to currentColor or theme-safe assets. **Acceptance:** both themes meet text/nontext contrast across normal, hover, focus, disabled, error, and dynamic states. **Suggested command:** `$impeccable colorize`.

## UI-07 — Medium / P1: the narrow header clips login and theme controls

**Location:** `header.css:7–10,31–35`; `responsive.css:16–20`; `global.css:12`.

At a 320px viewport, document width grows to 370px. The login control's right edge is approximately 370px; overflow hiding clips it. At 390px the basic page has no horizontal overflow, but the header search field becomes too narrow to use comfortably. Desktop screenshots and one mobile width cannot establish responsive conformance for every service view.

**Standard:** WCAG 1.4.10 reflow. The playbook's 44px target preference is stricter than WCAG 2.2's 24px minimum with exceptions; 40px header controls are not automatically a WCAG failure.

**Correction:** give the mobile search an intentional separate row/expanded mode and permit header wrapping without clipping controls. **Acceptance:** all essential controls remain visible/usable at 320 CSS px and 200% text scaling, with every service/modal checked. **Suggested command:** `$impeccable adapt`.

## UI-08 — Medium / P1: quick actions and guest visibility are incomplete

**Location:** `ui/index.html:127–153`; `permissions.js:54–75,139–155,226–229`; `menu.css:202–214`; `menu.js:184–188,215–218`.

The four quick actions have `data-action` values with no implementing action dispatcher. Some guest prompts work, but logged-in My Profile/My Tickets actions have no corresponding view/handler. Permission-hidden action cards still have an author `display:flex` rule that can override native `[hidden]`; the guest screenshot shows the restricted cards. Each permission refresh attaches another guest prompt listener. Login also invokes menu's obsolete “not implemented, use CLI” alert before the actual modal handler.

**Correction:** wire each action to a real task, honor hidden states explicitly, attach idempotent handlers, and remove conflicting login behavior. **Acceptance:** each visible action completes its advertised task once; inaccessible controls are absent from layout/focus; login opens one coherent flow. **Suggested command:** `$impeccable harden`.

## UI-09 — Medium / P1: dashboards display fabricated or incompatible metrics

**Location:** `admin.js:28–73,253–285,322–382`; `api.js:961–1007`; `admin_service/main.bal:459–471,522`; `controller.js:247–254`.

Admin health returns a string, while the UI iterates it as a service map. Revenue UI uses `day/week/month` values while service logic expects `daily/weekly/monthly`, falling back silently. Missing metrics are shown as zero, 99.9% uptime, or current timestamps. Disruptions are substituted for activity logs; route/ticket-type report statistics are literal zeros. Purchase success text promises an email although notification delivery is console-only. These displays can mislead an operator even when requests succeed.

**Correction:** match actual reporting contracts, display unavailable data as unavailable, implement real audit/health/analytics endpoints, and label simulation accurately. **Acceptance:** seeded known totals and controlled outages yield correct displays; no invented uptime, delivery, or report values appear. **Suggested command:** `$impeccable clarify`.

## UI-10 — Medium / P2: client requests and rendering have avoidable performance/error debt

**Location:** `linkstyles.css`; `api.js:225–275,390–397,512–516,1029`; `search.js:208–277`; `masonry.js:125–146`; `route-browser.js:389–398`.

The stylesheet entry imports 23 files, with another stylesheet linked separately. Search issues overlapping full-list requests and has no response generation/abort guard. API reads collapse failures into empty arrays, disguising outages as no data. Some requests lack timeouts/cancellation; polling is not visibility-aware. Admin explicitly selects manual grid masonry; it alternates layout reads and writes per card and re-registers resize handlers on repeated initialization. No dropped-frame claim is made. Purchase selects the first `[data-trip-id]`, which is the card wrapper before its button, then replaces the card's innerHTML while trying to disable the button.

**Correction:** reuse shared paginated data, cancel stale searches, distinguish error/empty states, consolidate production assets, batch layout reads/writes, and target the purchase button explicitly. **Acceptance:** throttled-network tests do not show stale data, destroyed cards, duplicate requests, or false empty states. **Suggested command:** `$impeccable optimize`.

## UI-11 — Low / P2: animation and maintenance scaffolding need consolidation

**Location:** `modal.css:143,242`; `route-browser.css:14,57,140–149`; `masonry.js`; `render.js`; `storage.js`; `testing.js`; `controller.js.old`.

The reduced-motion rule in `utilities/effects.css` covers only `.btn` transitions/active transforms; action-card, modal, route-card, and spinner motion remains. Modal effects animate width/height and looping loading indicators run indefinitely while pending. The detector also flags decorative stripes and bounce easing. Those aesthetic warnings are not treated as independent technical vulnerabilities. Legacy student rendering/storage, an unloaded syntactically invalid `.old` controller, and browser test scaffolding add maintenance cost. Several browser permission tests change role without setting `loggedIn`, so their outcomes depend on the current session.

**Correction:** add an intentional reduced-motion alternative, remove unused legacy code, move test tooling out of production loading, and isolate test state. **Acceptance:** reduced-motion users retain useful feedback without unnecessary motion; production loads only required modules; browser tests are deterministic. **Suggested command:** `$impeccable optimize`.

## Positive findings and remaining checks

- Native semantic buttons, many explicit labels, decorative-image alt handling, and a main landmark are present.
- The sampled DOM has no duplicate IDs, unlabeled inputs, broken images, or empty accessible button names. These spot checks do not replace a full accessibility tree/screen-reader audit.
- Basic 390px layout stacks content; both themes have a substantial token foundation.
- The app uses native JS and local assets without a large frontend package dependency tree.
- Some renderers already escape text correctly; the shared `App.utils.esc` pattern can be applied consistently.
- Manual screen-reader testing, all-view keyboard traversal, 200% text sizing, all theme/state contrast pairs, slow-device performance, and cross-browser testing remain unverified.

## Frontend action order

1. `$impeccable harden`: repair UI-01–05 and UI-08, after backend security/contracts are settled.
2. `$impeccable clarify`: UI-09, truthful operational and payment copy.
3. `$impeccable colorize` and `$impeccable adapt`: UI-06–07.
4. `$impeccable optimize`: UI-10–11.
5. `$impeccable polish`: finish after functional and accessibility checks pass.

These can be addressed one at a time or in the dependency order above. Re-run `$impeccable audit` after fixes to compare the evidence and score.
