# Repair tracker

Updated 2026-10-27. The original [audit](../audits/README.md) describes baseline commit `7d56d4e`; it remains historical evidence. This tracker records the replacement implementation and local verification, not ASVS or WCAG certification.

## Delivery and status meanings

Keep six Ballerina services, MongoDB, Kafka, plain browser JavaScript and the consolidated `uth.ps1` helper. Use a new authenticated demo database without deleting old volumes. Payments remain simulated and notifications remain in-app. [Architecture](ARCHITECTURE.md) records the reasons, advantages, drawbacks and alternatives; [verification](VERIFICATION.md) identifies exact checks and their limits.

- **Verified locally:** replacement behavior has source review and relevant passing local checks. This does not imply every execution path was tested.
- **Demo boundary:** the original exposure is reduced and the remaining limitation is explicitly within the approved local/demo scope.
- **Local gates pass; remote unverified:** tests/CI exist and local checks pass; no hosted CI run is claimed.

Evidence: **API** means real MongoDB/Kafka checks in [test_application.py](../tests/test_application.py); **browser** means [Playwright tests](../tests/browser/application.spec.js); **unit** means [native Ballerina tests](../core/tests/rules_test.bal); **helpers** means loopback fake-API [boundary tests](../tests/test_helpers.py). Compact scan/test evidence is under [repair evidence](../audits/repair-evidence/README.md). Mocked browser responses and clock-fixture changes are identified in the verification record.

## Security

| ID | Original issue | Disposition | Implementation and evidence |
|---|---|---|---|
| SEC-01 | authentication and authorization are absent from five services | Verified locally | Shared live-session, role and ownership checks in `core/auth.bal` and `core/api.bal`; real API authentication, role, assigned-operator and cross-user tests. |
| SEC-02 | a passenger can mark a ticket paid and change its quantity | Verified locally | Generic financial mutation removed; closed DTOs and named ticket/payment transitions. API rejects price, ride-count, role and payment-state forgery. |
| SEC-03 | caller-supplied payment value and ticket identity are trusted | Verified locally | Price derives from route fare/product and ownership from the session. All products, payment failure, ownership and retry API tests pass. |
| SEC-05 | a committed signing key permits passenger-token forgery | Verified locally | Signing-key authentication removed. Random opaque bearer sessions are stored as hashes; invalid-token/hash tests pass. The obsolete historical key grants no current access. |
| SEC-04 | passwords use plaintext or unsalted SHA-256 | Verified locally | Native Argon2id registration/login. Unit salted-hash checks and real database inspection pass; password whitespace is preserved. |
| SEC-06 | infrastructure is published without authentication or transport security | Demo boundary | Database-scoped MongoDB credentials, private broker/database ports and loopback-only gateway are verified. HTTP/private-network traffic remains plaintext; Internet TLS is outside this demo release. |
| SEC-07 | server-side abuse limits and domain validation are missing | Verified locally | Closed DTOs, input/body/type/range limits, bounded pagination, login limits and gateway request/concurrency limits. Real API invalid-input, missing-field and abuse-limit cases pass. |
| SEC-09 | stored and DOM HTML injection executes in browser renderers | Verified locally | Safe text/DOM construction, no HTML interpolation and restrictive same-origin CSP. Browser HTML-payload injection remains inert. |
| SEC-08 | sensitive data is logged and audit attribution is unreliable | Verified locally | Server-derived audit actors, protected audit reads, sanitized driver/HTTP errors, ignored generated secrets and disabled browser traces. Source review, role checks and helper redaction tests pass. |
| SEC-10 | token lifecycle and account deletion are incomplete | Verified locally | Idle/absolute expiry, logout, role/deactivation revocation and guarded profile deletion pass API checks. Browser clears local credentials on a simulated logout outage and reports uncertain server revocation. |

## Data and business rules

| ID | Original issue | Disposition | Implementation and evidence |
|---|---|---|---|
| DATA-01 | two incompatible ticket models share one collection | Verified locally | One entitlement schema plus separate trip bookings. Purchase/pay/book/validate/refund and OpenAPI response checks pass; no legacy migration is attempted. |
| DATA-02 | fresh MongoDB seeding violates its unique indexes | Verified locally | Explicit authenticated seed, private generated credentials and stable request keys. Seed succeeds twice; isolated fresh authenticated database bootstrap passes. Helper dictionary-shape regression passes. |
| DATA-03 | the ticket payment consumer uses the wrong Kafka address | Verified locally | Financial activation is synchronous and transactional; only notification delivery depends on Kafka. Payment during broker outage and subsequent event recovery pass. |
| DATA-04 | timestamp representations break reads and reporting | Verified locally | UTC-normalized ISO timestamps and integer minor-unit money. Native normalization, real response contracts and report journeys pass. |
| DATA-05 | validation cannot consume a multi-ride ticket correctly and is non-atomic | Verified locally | Conditional transactions consume one reserved ride once. Repeated/concurrent validation, ten-ride exhaustion and monthly-pass API tests pass. |
| DATA-06 | refunds can repeat without limit and do not revoke tickets | Verified locally | One full atomic refund revokes the entitlement, cancels bookings and releases inventory. Concurrent/repeated refund and post-validation rejection tests pass. |
| DATA-07 | financial/background work and event publication are not durable | Verified locally | Official-driver transactions atomically persist state/audit/outbox; acknowledged publication and transactional deduplication. Worker restart before publication, replay, broker recovery and isolated oplog restoration pass. |
| DATA-08 | schedule event variants violate the consumer contract | Verified locally | One event shape includes event/trip/route IDs; validation and protected quarantine. Schedule delivery, malformed-message quarantine and progress to subsequent valid events pass. |
| DATA-09 | selling tickets never reserves transport capacity | Verified locally | Ten-minute holds, guarded seat counters, release on cancellation/refund and independent expiry. Last-seat race, duplicate checkout, outage hold expiry, missed-trip release and capacity guards pass. |
| DATA-10 | trip delays replace times with non-time text | Verified locally | Schedule edits require valid future UTC instants and bounded duration. API notification and manager browser schedule-edit cases pass. |
| DATA-11 | shared broadcast notifications have shared read state | Verified locally | Per-recipient notification records and event/recipient deduplication. API verifies that one recipient reading a broadcast does not change another recipient’s state. |
| DATA-12 | unbounded queries and mismatched indexes impede scaling | Verified locally | Default 20/max 100 lists, query-specific indexes, five-second budgets and page-before-join reads. Pagination, 2,000-route query plans, unmatched joins and unique foreign-key cardinality pass. Production load is not inferred. |

## Deployment and operation

| ID | Original issue | Disposition | Implementation and evidence |
|---|---|---|---|
| OPS-01 | committed infrastructure versions are past their support windows | Verified locally | Pinned Ballerina 2201.14.1/JDK 25, MongoDB 8.0, Kafka 4.4.0 and digest-pinned bases; narrow infrastructure patches. All nine final image IDs match passing high/critical scans. |
| OPS-03 | startup ordering does not wait for dependency readiness | Verified locally | Nine real container health checks, dependency gates and helper `start --wait`. Fresh bootstrap, final recreation/readiness and eight smoke checks pass; dynamic gateway DNS recovers replaced services. |
| OPS-05 | the supplied deployment has single points of failure and no recovery procedure | Demo boundary | Consistent compressed backup/oplog capture and isolated restoration succeed; clean bootstrap and restart recovery pass. The approved single-host deployment still has no high availability. |
| OPS-08 | locked Kafka connector metadata references a vulnerable Java client | Verified locally | Connector 4.6.7 packages client 3.9.2, confirmed inside the final JAR. Patched Kafka 4.4.0 and all nine runtime images report zero high/critical matches on the recorded scan date, with no advisory suppressions. |
| OPS-02 | Docker builds discard the dependency lockfiles | Verified locally | The shared Dockerfile consumes manifests/locks and retains actual service/core locks. All six packaged TOML lock pairs match repository sources. |
| OPS-04 | environment overrides use the wrong naming convention | Verified locally | Correct `BAL_CONFIG_VAR_UTH_CORE_*` and service configuration plus ignored generated secrets. Authenticated real-stack tests use the intended database and broker. |
| OPS-06 | health and observability do not describe actual service readiness | Verified locally | Database-aware health across six services, broker-aware notification health and real report aggregations. Final health/smoke, report journeys and outage recovery pass. |
| OPS-07 | release hardening and browser hosting are unspecified | Demo boundary | One same-origin loopback gateway, security headers/CSP, limits, application privilege/resource/filesystem restrictions and bounded logs. Internet hosting/TLS and production monitoring remain outside scope. |

## Clients, tests and documentation

| ID | Original issue | Disposition | Implementation and evidence |
|---|---|---|---|
| QA-01 | no repeatable release-quality test/CI gate exists | Local gates pass; remote unverified | The pinned workflow covers native/helper/API/browser/contract/scan/restore gates and parses locally. Corresponding checks ran locally; no push or hosted CI run occurred. |
| QA-02 | API scripts can report success while operations fail | Verified locally | HTTP status, assertions and cleanup propagate failures. Negative helper tests and observed failing unittest/Playwright runs verify failure exits; corrected targeted reruns pass. |
| QA-03 | Bash request helpers execute caller input as shell code | Verified locally | Duplicated Bash/eval helpers removed. One structured PowerShell HTTP boundary; UTF-8/quoting and bearer-header tests pass. |
| QA-04 | CLI authentication has incompatible and false-success behavior | Verified locally | Unified real bearer login, memory-only session and explicit unknown-role rejection. Scripted prompt input drives real CLI journeys for all four roles. |
| QA-05 | ticket/transport CLI flows violate their contracts or are placeholders | Verified locally | Purchase/payment, booking, validation, CRUD, report, account and delivery menus use current APIs. Real CLI passenger purchase, operator validation, manager edit and administrator access/audit journeys pass; browser/API checks cover other actions. |
| QA-06 | scripts assume inconsistent shell tools and successful HTTP transport | Verified locally | PowerShell 7.2 entrypoint and five internal modules; resolve the Docker executable to avoid stale WSL aliases. Parsing, helper boundaries, start/seed/backup/restore and real CLI journeys pass. |
| QA-07 | setup and operational documentation references missing files and wrong behavior | Verified locally | Current README, operations, architecture, helper and administrative guides; validated 49-operation OpenAPI covers all six services. Real API assertions check response schemas. |
| QA-08 | initialization/debug helpers generate inconsistent or sensitive test state | Verified locally | Scattered debug scripts removed; repeatable explicit seed, ignored generated credentials and unique fixtures. Repeat seed, fresh bootstrap and fixture cleanup pass. |
| QA-09 | legacy source and repository policy gaps add maintenance noise | Verified locally | Obsolete frontend modules/styles/root helpers removed; central ignore/line-ending policies and CI added. Parse/syntax/diff checks pass; historical audit is preserved. |

## Frontend

| ID | Original issue | Disposition | Implementation and evidence |
|---|---|---|---|
| UI-01 | first load never fetches passenger routes | Verified locally | Explicit session restore/module initialization followed by public route loading. Real browser startup passes. |
| UI-02 | browser API routes and payloads do not match services | Verified locally | One same-origin API client and current documented DTOs. Passenger purchase/refund, three staff-role screens and manager transport CRUD pass against real services. |
| UI-03 | global search discards valid route and trip results | Verified locally | Server prefix search across normalized route name/origin/destination, escaped queries and pagination. Results beyond the first page and representative indexed queries pass. |
| UI-04 | unknown role checks fail open and navigation bypasses its own gates | Verified locally | Explicit known-role navigation plus server permissions/ownership. Mocked unknown-role browser case and real API/CLI role tests pass. |
| UI-05 | modal keyboard interaction and semantics are incomplete | Verified locally | Native dialog, labels, initial/return focus, Escape and skip link. Browser keyboard cases pass; this is sampled accessibility coverage. |
| UI-06 | theme drift causes failed contrast and inconsistent components | Verified locally | Shared CSS tokens retain blue dark/warm light themes, corrected control borders and dark logo. Four route theme/viewport axe checks and two visual review rounds pass; no complete manual WCAG claim. |
| UI-07 | the narrow header clips login and theme controls | Verified locally | Wrapping header/navigation and responsive layout fit 320px in both themes without horizontal overflow. A separate 200% text-enlargement browser check passes. |
| UI-08 | quick actions and guest visibility are incomplete | Verified locally | Public routes/trips and task-oriented passenger/staff controls replace placeholders. Real browser and all-role CLI journeys pass. |
| UI-09 | dashboards display fabricated or incompatible metrics | Verified locally | Diagnostic cards removed from travel workflows; staff reports use actual server aggregation. Manager browser/CLI report journeys pass. |
| UI-10 | client requests and rendering have avoidable performance/error debt | Verified locally | Bounded joined display pages, explicit initialization, stable request keys, render/pagination generations and readable retry errors. Late-response and service-error browser tests pass. |
| UI-11 | animation and maintenance scaffolding need consolidation | Verified locally | One CSS entrypoint, five native browser modules and conditional reduced motion. Reduced-motion computed-style and syntax checks pass; old scaffolding removed. |

## Remaining boundaries

All **50** baseline findings have a disposition above. SEC-06, OPS-05 and OPS-07 retain approved demo boundaries; QA-01 retains unexecuted hosted CI. Full manual accessibility/screen-reader assessment and production load/availability/TLS testing remain unverified. These are not inferred from the local checks. See the verification record for coverage, fault injection, raw local logs and scan limitations.
