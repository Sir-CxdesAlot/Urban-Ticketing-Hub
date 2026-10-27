# Prioritized remediation plan

This audit changes documentation and adds isolated probes only. The work below is proposed remediation, not a claim that defects have been fixed. Suggested owners are engineering roles, not assignments to named people. Each finding's report contains its acceptance criteria.

## 1. Establish a trustworthy baseline and contain exposure

**Owners:** backend lead and build/release owner.

- Fix test failure propagation (QA-02), preserve the audit regression cases, and establish an isolated test environment (QA-01).
- Rotate the committed passenger signing key, stop shipping known privileged demo accounts, and constrain database/broker/service management access (SEC-04–06).
- Remove Bash eval/executable session files and unsafe HTML sinks immediately (QA-03, SEC-09).
- Set the supported runtime/resolution policy and make the build consume its lockfiles (OPS-02). Capture exact artifact SBOM/digests before dependency changes.

**Gate:** failed checks produce a failed release result; old tokens/known accounts no longer work; unauthorized hosts cannot reach data/control ports; marker payloads remain inert.

## 2. Make identity and business authority server-owned

**Owners:** backend/security engineers.

- Implement consistent passenger/staff credentials, deny-by-default role/object/property checks, and session invalidation (SEC-01, SEC-10).
- Remove user control over payment/validation/price/ride fields; derive owners from credentials and fares from orders (SEC-02–03).
- Enforce server input/abuse controls and protected server audit logs (SEC-07–08).
- Define one canonical versioned ticket/order/date/identifier model; migrate the collection and repair fixtures (DATA-01–04).

**Dependencies:** choose the canonical API/data model before independently patching browser and CLI payloads. Authentication alone does not repair entitlement forgery.

**Gate:** cross-user/role/property-tampering tests fail safely; all supported paths create/list/pay/validate the same ticket; clean-volume bootstrap and migration tests pass.

## 3. Make money, inventory, and events durable

**Owners:** payments, transport, and event-processing engineers.

- Implement idempotent payment/refund and atomic entitlement/reservation state machines (DATA-05–07, DATA-09).
- Correct broker configuration, event schemas, consumer deduplication, poison-event handling, outbox/reconciliation, and monotonic transitions (DATA-03, DATA-07–08).
- Correct transport time handling and per-user broadcast receipts (DATA-10–11).
- Add bounded pagination, indexes, aggregation, and consistent stream cleanup (DATA-12).

**Gate:** concurrency/replay/out-of-order/crash tests preserve balances, seat counts, ride counts, and notifications; refunds cannot repeat or leave usable refunded entitlements.

## 4. Deliver a supported, observable release

**Owners:** platform/release owner.

- Upgrade unsupported infrastructure and affected Kafka client dependencies, then scan the exact final images (OPS-01, OPS-08).
- Add readiness/retry/restart, correct environment overrides, persistence/backup/restore, health/metrics/alerts, and a hardened deployment with a UI origin (OPS-03–07).
- Test exact toolchain/images on supported target platforms; document demo versus production profiles and recovery objectives.

**Gate:** repeated fresh starts converge; supported artifacts pass scans; restore and outage drills meet documented targets; monitoring reports actual faults and stuck processing.

## 5. Complete every client flow and accessibility pass

**Owners:** frontend and CLI engineers.

- Repair bootstrap, API paths/payloads, search, admin initialization, role/navigation checks, and quick actions (UI-01–04, UI-08; QA-04–05).
- Fix dialogs, field/status announcements, theme tokens/contrast, and 320px reflow (UI-05–07).
- Replace invented metrics/delivery claims with verified information, and improve cancellation/error/performance/motion behavior (UI-09–11).
- Standardize shell/tool support, deterministic fixtures, and shipped instructions; remove legacy code (QA-06–09).

**Gate:** real isolated browser and CLI tests complete register/login/search/book/pay/validate/refund/history/logout; all staff roles are tested; keyboard/screen-reader/theme/reflow checks pass; clean-checkout documentation works.

## Release decision

The current repository is suitable for further demo development, with its documented limitations visible. It is **not ready for production accounts, financial operations, or a public deployment**. Close the critical/high findings first and complete the explicitly unverified release checks. Remaining medium/low findings need an owner and a recorded disposition; an attractive UI or green smoke-test banner is not a release gate.

## Minimum regression scenarios

| Area | Required scenario |
|---|---|
| Authentication | Wrong/missing/expired/old-key tokens; logout; disabled/deleted account; throttled guessing |
| Authorization | Every role/resource pair; cross-user IDs; forged owner/price/status/role properties |
| Ticketing | Canonical-schema reads; normal single/multi/pass consumption; expiry; repeat/concurrent use |
| Payments | Fare mismatch; duplicate/retried request; repeated/negative refund; settlement reconciliation |
| Transport | Last-seat race; cancelled/past trip; delay across day boundary; reservation expiry/release |
| Events | Wrong broker; malformed event; replay; out-of-order result; crash after write/before publish |
| Persistence | Empty-volume initialization; repeat seed; schema migration; restore and rollback |
| Browser | Startup; search; staff login/admin view; every task action; stale/failed network; inert hostile text |
| Accessibility | Keyboard/screen reader; focus/dialog/errors; both themes; 320px/zoom; reduced motion |
| Delivery | Exact runtime/lockfiles/images; vulnerabilities/licenses/secrets; readiness/alerts; clean setup guide |
