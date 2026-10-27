# Verification record

Date: **2026-10-27**, Windows host with Docker Engine 29.9.2, PowerShell 7.6.5, Python 3.14.6 and Node 24. The application uses Ballerina 2201.14.1, JDK 25, the official MongoDB Java driver 5.13.0, authenticated MongoDB 8.0 and Kafka 4.4.0.

These checks ran before the repair snapshot was committed on **`the-ideal-version`**; baseline commit `7d56d4e` describes the original application. The historical audit is unchanged. The audit framework uses OWASP ASVS/API security, dependency checks and WCAG accessibility checks as review guidance; this is not a certification or proof that no defects remain.

## Executed checks

| Check | Result | Actual boundary / local raw evidence |
|---|---|---|
| Native Ballerina | 10 passed, 0 failed/skipped | Real hashing and pure business/validation helpers; no database. `.runtime/final-unit-tests.log`, 2.38s. |
| Python helper boundary | 8 passed | Ephemeral loopback fake API; HTTP/status/redaction, selection, read-only smoke, CLI exit, UTF-8/bearer and pagination shapes. `.runtime/final-helper-tests.log`, 9.292s. |
| Real application integration | 30-case suite passed | Real gateway, six services, replica set and Kafka; 810.259s. `.runtime/final-api-tests.log`. |
| Clean database bootstrap | Additional case passed | Disposable authenticated isolated replica set with the actual init script; app-user write succeeds; container/anonymous volumes cleaned. `.runtime/bootstrap-test.log`, 46.095s. |
| Four-role CLI journeys | Additional case passed | Only prompt input is scripted; actual CLI module, real passwords, sessions and HTTP operations. Passenger checkout/payment, assigned-operator validation, manager route edit/report, super-admin access/account/audit. `.runtime/final-cli-tests.log`. |
| Representative queries/joins | Additional case passed | 2,000 temporary valid routes, actual indexed prefix-search query, one document examined/returned, duplicate ID rejected, multiple trips retain their one matching route. `.runtime/final-query-tests.log`, 56.922s; `.runtime/final-query-plan.json`. Own query fixtures removed with asserted cleanup. |
| Browser suite | 9 cases passed | Real passenger purchase/refund and staff screens/manager CRUD; four theme/viewport axe checks, keyboard dialog, inert HTML, API failure, unknown role and stale response. Some error cases deliberately mock responses. `.runtime/final-browser-tests.log`, 25.6s. |
| Browser offline sign-out | Additional case passed | Real sign-in then mocked logout 503; local token cleared and server-revocation uncertainty reported. `.runtime/offline-signout-test.log`, 4.8s. |
| Browser text/motion/keyboard | Additional case passed | 200% CSS text enlargement, reduced-motion computed style, skip link and dialog initial/return focus. `.runtime/final-accessibility-test.log`, 4.8s. |
| Final readiness/smoke | 9 containers healthy; 8 checks passed | After final container recreation/log limits, six dependency routes plus public route/trip lists. `.runtime/final-readiness.log`, `.runtime/final-smoke.log`. |
| Seed repeatability | Passed twice | Real authenticated APIs; generated credentials reused, financial state preserved. Later-day trip window is additive. |
| Backup/restoration | Passed | Compressed oplog archive restored into temporary network-isolated replica set; verified 19 accounts and 43 bookings at that snapshot. Live database untouched; created container removed. `.runtime/final-restore.log`. |
| Build/locks | Passed | Six images built; all six packaged service/core lock pairs match repository TOML. `.runtime/final-lock-verification.json`. Kafka client metadata inside final notification JAR reports **3.9.2**. |
| Contracts/static checks | Passed | OpenAPI validates (39 paths, 49 operations); API assertions validate documented response shapes. PowerShell entrypoint/five modules parse, browser modules pass Node syntax, Python compiles, CI YAML parses, `git diff --check` passes. |
| npm audit | 0 reported vulnerabilities | Pinned development package lock; not a substitute for the runtime scans below. |

There are **62 distinct passing test cases** across native (10), fake-helper (8), real integration (33) and browser (11) checks. The integration and browser totals combine the original full runs with subsequent targeted additions; a single full 33-case/11-case run was **not** performed. The CI/discovery commands now select those additional cases automatically. Health checks, backup restoration and scans are additional evidence, not counted as test cases.

## Security, concurrency and recovery coverage

The real API suite checks all four roles, ownership/cross-user access, forbidden financial input, missing fields and pagination bounds, password hashing, whitespace preservation, login limits, logout, role changes, deactivation and idle/absolute session expiry. Clock-boundary checks change only their own database fixture timestamps; they do not wait eight hours or change the host clock.

Product checks cover all three server-calculated prices, first bookings, subsequent pack/pass bookings, route restrictions, single-trip rebooking restriction, ten-ride exhaustion, monthly expiry, failed payment, cancellation, one full unused refund and rejection after validation. Parallel requests test the last seat, matching and conflicting checkout/payment retries, repeated validation and repeated refunds.

Recovery checks stop Kafka while committing a payment and expiring an unpaid hold, then verify eventual delivery after restart. Another check stops the notification worker, commits an outbox event, restarts the worker and verifies one notification; replayed duplicates stay deduplicated. A malformed Kafka record is quarantined and a later valid record still progresses. Service recreation preserves the server session and the gateway recovers the new container address. Expired confirmed/unvalidated bookings release reserved rides independently of Kafka.

The left outer trip/route join retains an unmatched trip. Several trips sharing one route retain separate result rows. Unique indexed route IDs reject duplicate foreign records, so multiple route matches are invalid rather than a supported join multiplicity. Index plans demonstrate tested queries at demo-sized volume; they do not establish all-query throughput or production scaling.

## Dependency and image scans

Trivy **0.76.1** scanned the final six application images plus the three patched MongoDB/Kafka/gateway images. **All nine report zero HIGH or CRITICAL vulnerabilities** on this date. Every scan's image ID was compared to the current local image ID after the final container recreation. No vulnerability ignore/suppression file was added.

[Saved scan summary](../audits/repair-evidence/verification-summary.json) records exact image IDs, scan timestamps, scanner version and severity threshold. Full local reports are `.runtime/final-scan-uth-demo-v2-*.json`. They remain ignored because bulky generated reports are not source documentation.

A source scan including development dependencies also passes at HIGH/CRITICAL for the Maven and npm dependency files. It excludes downloaded/generated `.tools`, private/generated `.runtime` and historical `audits`. Python verification tools have pinned direct versions; application dependency/build evidence comes from the actual runtime images and packaged locks.

The initial scan found vulnerable bundled infrastructure libraries and the older Go runtime inside gosu. Narrow derived images update those libraries, and unchanged upstream gosu 1.20 source is built using pinned Go 1.27.3. MongoDB's YAML helper, Kafka LZ4, Brotli/curl/Expat replacements and remote source downloads use explicit versions/checksums. See [operations](OPERATIONS.md) and [Docker sources](../deploy/). A zero-match scan is time-bound advisory evidence, not a guarantee of absence of vulnerabilities or a full container configuration assessment.

## Review-driven corrections

Real execution found and repaired seed dictionary enumeration, stale gateway addresses after service recreation, unsupported Ballerina string splitting, missing-field panics, password whitespace mismatch, unsafe worker failure propagation, delayed-response rendering and local offline sign-out behavior. Capacity/account version guards and independent expiry protect concurrency and broker outages.

Verification defects were corrected too: an ambiguous browser selector, invalid non-UUID volume-test fixtures and Windows decoding of Unicode MongoDB query-plan output. Those failed runs were not counted as successful suite runs. Targeted corrections passed without weakening the response contract or index assertions. Cleanup failures continue to fail tests.

Two batched visual-review rounds checked the retained dark/light identity at desktop and 320px. Functional accessibility checks add keyboard focus, 200% text scaling and reduced motion; axe reports no violations on the four tested route-page theme/viewport combinations.

## Unexecuted or outside scope

- Hosted GitHub Actions has **not run**: the workflow is written and parses, and its corresponding checks were executed locally. No push/PR was requested.
- Full manual WCAG 2.2 AA evaluation, screen-reader/browser matrix, every staff form with axe, and native browser-toolbar zoom are unverified. The checks above are sampled keyboard/layout/axe/200% CSS-text tests.
- Production load/soak benchmarks, multi-host failure, high availability, Internet TLS/MFA, real payments and external email/SMS are outside the approved demo release. Internal local traffic is plaintext.
- Legacy-data migration is intentionally omitted. Existing legacy volumes were preserved. Backup restoration verifies the saved snapshot in isolation, not a destructive restore of the running database.
- No claim is made that every ASVS control or every possible code branch was exercised.

## Reproduce

Start and seed using the [README](../README.md), install pinned test dependencies, then run:

```powershell
python -m unittest discover -s tests -p test_helpers.py -v
pwsh ./uth.ps1 test -Suite unit
python -m unittest discover -s tests -p test_application.py -v
npx playwright test
python -m openapi_spec_validator docs/openapi.json
npm audit --audit-level=high
pwsh ./uth.ps1 backup
pwsh ./uth.ps1 restore-check -BackupPath PATH_TO_ARCHIVE
```

For native tests, use Ballerina 2201.14.1 and build the Java adapter first. Integration checks briefly stop/restart this demo's Kafka and notification containers and recreate its passenger service. They never delete the existing application volumes. Raw reports, credentials and backups stay ignored under `.runtime`; share only sanitized summaries.
