# Data, business logic, and distributed-system audit

Evidence: source-confirmed, with local checks called out separately. Database/broker execution was unavailable; expected MongoDB behavior is supported by its official documentation.

## DATA-01 — High: two incompatible ticket models share one collection

**Location:** `passenger_service/main.bal:120–133,357–393,608–687`; `ticketing_service/main.bal:17–45,81–109,165–179`.

Passenger tickets contain `userId`, uppercase `SINGLE/MULTIPLE/PASS`, `quantity`, `purchaseDate`, and string `validUntil`. Ticketing tickets contain `passengerId`, lowercase `single/multiple/pass`, required `tripId`, `ridesRemaining`, and tuple-valued `createdAt/expiresAt`. Both write `tickets`. Passenger reads filter on `userId`, so ticketing-created purchases disappear from the passenger portal. Ticketing's typed reads cannot bind passenger documents missing required fields. Pricing and validity also diverge: passenger PASS is 30 days; ticketing pass is 90 days.

**Correction:** choose one authoritative ticket service and versioned schema; migrate existing documents; make passenger endpoints delegate to it. Define canonical owner, trip, price/currency, type, validity, and ride fields. **Acceptance:** create through every supported client, list as owner, pay, validate, cancel, and report the same ticket without conversion errors.

## DATA-02 — High: fresh MongoDB seeding violates its unique indexes

**Location:** `init-mongo.js:15–26` and the sample route/user/trip insert blocks.

Unique non-sparse indexes require unique values even when a field is missing. All five route fixtures lack both `id` and `routeNumber`; the second route conflicts with the first. User fixtures and generated trips likewise omit unique `id`. Ordered inserts can leave partially seeded collections. A subsequent container restart with a persisted volume is not a migration/repair mechanism. [MongoDB documents the missing/null single-field unique-index rule](https://www.mongodb.com/docs/manual/core/index-unique/).

Seeded passenger credentials are plaintext, incompatible with passenger login's SHA-256 comparison; their required application IDs are absent. Admin seeds precede routes, so partial initialization can leave known privileged accounts while later data is missing.

**Correction:** separate opt-in demo fixtures from idempotent migrations; assign stable IDs, use the same password provisioning and data contracts as services, and validate all unique keys before insert. **Acceptance:** initialize an empty isolated volume, rerun initialization, restart, and verify expected counts, uniqueness, login, route lookup, and trips. Record this as a source-confirmed initialization defect, not a live Mongo test result.

## DATA-03 — High: the ticket payment consumer uses the wrong Kafka address

**Location:** `ticketing_service/main.bal:340`; compare its configured ticket-request listener `:287` and `Config.toml:7`.

The payment listener uses `kafka:DEFAULT_URL` instead of `kafkaBootstrapServers`. In Compose the broker is `kafka:9092`; localhost inside a service container refers to that service container. Payment events therefore cannot be assumed to reach ticketing, even if the payment producer and notification consumer work.

**Correction:** use validated shared broker configuration for every listener/producer. **Acceptance:** in the real Compose network a successful payment causes the matching ticket to become PAID; broker outage and recovery do not lose the transition.

## DATA-04 — High: timestamp representations break reads and reporting

**Location:** `payment_service/main.bal:26–27,93,304–306`; `ticketing_service/main.bal:25–27,92,227`; `admin_service/main.bal:426–446`; `transport_service/main.bal:158–159,464–465`.

`time:Utc` values are written as tuples in ticketing/payment creation, then `processedAt` and `validatedAt` are overwritten with ISO strings while typed records still declare `time:Utc`. Admin reports compare `createdAt` against ISO strings even though ticket/payment creation stores tuples, producing incorrect date-range results. Passenger tickets do not have that `createdAt` field at all. Transport uses tuple `.toString()` in some fields, while seeded trips contain only `HH:mm`; browser code assumes parseable dates.

**Correction:** use one documented persistence/wire date format, with explicit boundary conversion and migration. **Acceptance:** create, process, fetch, validate, and date-filter records across all services with no binding failures; timezone and boundary-date cases give correct results.

## DATA-05 — High: validation cannot consume a multi-ride ticket correctly and is non-atomic

**Location:** `ticketing_service/main.bal:183–255`.

Every validation requires status PAID, then writes VALIDATED. A multi/pass ticket with remaining rides therefore fails its next normal validation. The read/check/update is separate, and the write filter is only `id`, so concurrent requests or other writers can validate stale state and overwrite ride counts. Ballerina's current non-isolated resource serialization is not a cross-instance/database concurrency guarantee.

**Correction:** distinguish usable entitlement state from a validation history; atomically check paid state, expiry, and remaining rides and decrement once. Deduplicate validator request IDs. **Acceptance:** repeat and concurrent validation consumes exactly the intended rides; exhausted/expired/unpaid tickets fail; a single ticket cannot be double-used across instances.

## DATA-06 — High: refunds can repeat without limit and do not revoke tickets

**Location:** `payment_service/main.bal:242–279`.

Each refund of a SUCCESS payment inserts another negative SUCCESS payment. The original is never marked refunded and has no unique refund relationship. Sequential requests repeat indefinitely. Refunding a negative refund record can also create a positive record. No refund event revokes or adjusts ticket entitlement.

**Correction:** implement an atomic, idempotent refund state machine with a unique original-payment relationship, bounded refundable balance, immutable ledger entries, provider confirmation, and ticket reconciliation. **Acceptance:** retries and concurrent refunds yield at most the allowed amount; refunding a refund fails; ticket rights reflect the final refund policy.

## DATA-07 — High: financial/background work and event publication are not durable

**Location:** `payment_service/main.bal:100–105,284–344`; `ticketing_service/main.bal:238–252,292–368`; `admin_service/main.bal:216–234`; `transport_service/main.bal:632–654`.

Payment launches an unobserved in-process future after saving PENDING; a crash can leave payments pending permanently. Database changes and Kafka sends are separate operations. Publication failures can leave committed state with a failed HTTP response, encouraging duplicate retries. Consumers insert fresh IDs without event deduplication, and payment events can reset validated/expired tickets to PAID or CREATED without a guarded transition. No outbox, inbox, reconciliation worker, or dead-letter handling is present.

**Correction:** use a transactional outbox (or equivalent durable coordination), an idempotent worker and consumer inbox, versioned state transitions, and reconciliation. **Acceptance:** crash at each write/publish boundary, replay messages, reorder payment results, and supply malformed events; no entitlement is restored incorrectly, no work disappears, and poison events are visible and recoverable.

## DATA-08 — High: schedule event variants violate the consumer contract

**Location:** `admin_service/main.bal:282–297,347–356,378–386`; `notification_service/main.bal:324–342`.

The dedicated disruption-status endpoint publishes no update event. General status updates publish `disruptionId/status/updateType` without `routeId`; deletion omits `routeId` too. Notification's consumer unconditionally extracts `routeId`. Consequently these variants cannot be processed by that consumer's contract. Initial disruption events also use a generic schedule path rather than preserving a distinct disruption notification type.

**Correction:** define explicit event variants and required fields, validate before publish, and handle each variant deliberately. **Acceptance:** creation, edit, dedicated status change, resolution, and deletion each generate the intended notification exactly once; malformed variants are quarantined.

## DATA-09 — High: selling tickets never reserves transport capacity

**Location:** both ticket creation paths (`passenger_service/main.bal:608`, `ticketing_service/main.bal:81`), payment processing, and `transport_service/main.bal:451–465,518–535`.

Ticket creation does not load/check the referenced route/trip or reserve/decrement a seat. The passenger path has no `tripId`. Trip capacity is independent caller-editable state. A browser's availability display cannot prevent overselling or purchases for nonexistent, cancelled, inactive, or past trips.

**Correction:** define inventory ownership and an atomic reservation/expiry/confirmation/release protocol. Enforce route/trip existence, sale status, capacity bounds, departure policy, and fare. **Acceptance:** concurrent purchases for one remaining seat produce at most one reservation; failure/cancellation releases it exactly once; invalid trips cannot be sold.

## DATA-10 — Medium: trip delays replace times with non-time text

**Location:** `transport_service/main.bal:604–607,624–629`; client date parsing in `api.js:545–547,658–665` and `route-browser.js:437–461`.

A delay prepends `Updated: ` instead of adding minutes to a timestamp. Repeated delays prepend again. Dates then become unparseable and upcoming/date searches become incorrect. Trip creation also ignores accepted `availableSeats/status`, and route creation ignores accepted `isActive` and forces true (`transport_service/main.bal:157,461–463`).

**Correction:** validate structured datetimes and compute revised times; either honor permitted input fields or remove them from the contract. **Acceptance:** multiple delays, overnight trips, cancelled trips, and inactive route creation preserve valid times and the documented state.

## DATA-11 — Medium: shared broadcast notifications have shared read state

**Location:** `notification_service/main.bal:117–151,345–354`.

Broadcasts have `recipientId: ALL`, but marking read changes the single notification document's global status. One reader marks it read for every recipient. Statistics are global rather than per user; SENT is set before console-only delivery, and DELIVERED has no actual delivery path.

**Correction:** keep broadcast content separate from per-recipient delivery/read receipts; define truthful simulated vs delivered status. **Acceptance:** reading as user A leaves user B unread; delivery metrics describe actual delivery attempts and acknowledgements.

## DATA-12 — Medium: unbounded queries and mismatched indexes impede scaling

**Location:** list resources across services; `payment_service/main.bal:111–122,211–227`; `init-mongo.js:34–40`; `passenger_service/main.bal:382`.

Lists materialize complete results without page bounds or stable ordering. Statistics repeatedly scan collections; several passenger/transport streams are not explicitly closed on all paths. The tickets index covers `passengerId`, but passenger queries use `userId`; no matching compound owner/date indexes or pagination are defined. Health calls count all records in several services.

**Correction:** introduce capped cursor pagination, server aggregation and appropriate compound indexes; close streams on all paths; use cheap dependency checks. **Acceptance:** explain plans and bounded-load tests show indexed owner/date access and predictable memory/latency as data grows.

## Positive evidence and checked non-findings

- Passenger reads/updates/deletes use the validated JWT subject and ownership filters; the concern is incomplete identity/state policy, not a missing ownership predicate on those paths.
- Mongo updates use the connector's typed `set` key. That is intentional connector syntax, not an erroneous missing `$` prefix.
- Ticket expiry compares `utcDiffSeconds(expiresAt, now) <= 0`, which has the correct argument direction. It is not reported as an expiry-sign bug.
- Services generally use UUID business IDs and several unique/query indexes. Those practices should be retained while fixing inconsistent identifiers and fixtures.
