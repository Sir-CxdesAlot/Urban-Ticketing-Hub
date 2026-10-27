# Security audit

All findings below are source-confirmed unless another evidence label is stated. Source locations refer to baseline `7d56d4e`.

## SEC-01 — Critical: authentication and authorization are absent from five services

**Evidence:** `admin_service/main.bal:106–714`, `transport_service/main.bal:138–683`, `ticketing_service/main.bal:68–284`, `payment_service/main.bal:70–281`, and `notification_service/main.bal:66–293` expose HTTP resources without JWT validation, an authentication interceptor, or ownership/role checks. Compose publishes all six service ports directly. Admin login returns identity fields, not a session credential. `createdBy` is the literal `admin-user` at admin line 209.

**Impact:** anyone who can reach these ports can create/change/delete admin accounts, alter transport, access other passengers' tickets/payments/notifications, refund payments, forge broadcasts, and edit ticket entitlements. UI permission checks cannot protect these endpoints. This is one systemic finding with both function-level and object-level effects, not a separate finding for each resource.

**Framework:** ASVS V8 Authorization, V9 Self-contained Tokens; API1, API3, API5:2023.

**Correction:** establish server-verified passenger/staff identities; apply deny-by-default authorization to every nonpublic resource; derive owner IDs from validated credentials; scope staff to assigned operations. Keep public route discovery and health explicitly public. Restrict direct service access as defense in depth.

**Acceptance:** isolated contract tests prove missing/invalid credentials fail, each staff role has only its allowed operations, passenger A cannot access passenger B's objects, and payload owner/role changes cannot escalate privileges.

## SEC-02 — Critical: a passenger can mark a ticket paid and change its quantity

**Evidence:** `passenger_service/main.bal:710` accepts ticket updates; its status allowlist includes `PAID`, `VALIDATED`, `EXPIRED`, and `CREATED`; the update writes caller-provided `status` and `quantity` after an ownership filter. The independent ticketing update at `ticketing_service/main.bal:134` also allows `status`, `price`, `expiresAt`, and `ridesRemaining` without authorization.

**Impact:** ownership checks do not prevent self-service entitlement forgery. A passenger can bypass payment, reset state, and alter the number of rides. This remains a defect after SEC-01 is corrected.

**Framework:** ASVS V2 Validation and Business Logic, V8; API3, API6:2023.

**Correction:** make entitlement/payment fields server-owned; expose narrowly defined commands with a state-transition model, payment verification, and audited staff exceptions.

**Acceptance:** passenger updates cannot change financial/validation fields; invalid transitions fail without changing data; successful payment is the sole normal route to a paid entitlement.

## SEC-03 — Critical: caller-supplied payment value and ticket identity are trusted

**Evidence:** `payment_service/main.bal:32–46,83–107` accepts `ticketId`, `passengerId`, `amount`, method, and details, then persists them without loading the ticket, checking ownership, matching the fare, validating a positive amount, or checking a previous payment. `ticketing_service/main.bal:81–109` likewise accepts the ticket price. Its payment consumer (`:345–367`) sets ticket status from the event status and ticket ID alone.

**Impact:** zero/negative/incorrect amounts, another user's ticket ID, duplicate purchases, or a fabricated/replayed success event can affect entitlements and revenue records.

**Framework:** ASVS V2, V8, V15 Secure Coding and Architecture; API6, API10:2023.

**Correction:** calculate fares from an authoritative ticket/order; enforce ownership, currency, positive bounded amounts, payment-method rules, and an idempotency key. Authenticate payment events and bind the payment ID, order version, amount, currency, and successful provider settlement.

**Acceptance:** amount/owner tampering and replayed requests/events cannot issue or restore a ticket. Repeating the same payment request produces one financial operation.

## SEC-04 — High: passwords use plaintext or unsalted SHA-256

**Evidence:** admin credential matching at `admin_service/main.bal:129`, creation `:564`, and update `:674` store/compare plaintext. Passenger registration/login use `crypto:hashSha256` at `passenger_service/main.bal:166,234`. `init-mongo.js` seeds plaintext credentials.

**Impact:** database disclosure immediately exposes admin passwords and permits fast offline guessing of passenger passwords. Seeded passenger passwords also do not match the passenger login hash format.

**Framework:** ASVS V6 Authentication, V11 Cryptography.

**Correction:** use a supported adaptive salted password hash (for example Argon2id), migrate existing credentials, remove automatic known accounts from normal deployment, and provide a secure bootstrap/reset flow.

**Acceptance:** no plaintext/reusable unsalted hashes in storage; equal passwords have different stored hashes; old credentials are migrated or reset; sample credentials do not work in a production profile.

## SEC-05 — Critical: a committed signing key permits passenger-token forgery

**Evidence:** `passenger_service/main.bal:25` embeds the HMAC JWT secret and uses it for both issuance and validation (`:28–51`). The validator accepts the passenger issuer/audience; protected operations trust its subject.

**Impact:** possession of the repository is sufficient to forge passenger credentials for a chosen subject. Publicly known/demo keys are unsafe even when they look long.

**Framework:** ASVS V9, V11, V13 Configuration.

**Correction:** rotate this key; load a high-entropy secret from a secret store, or use asymmetric signing with constrained verification keys; define issuer/audience/algorithm/lifetime and rotation policy. Treat the committed key as exposed.

**Acceptance:** tokens signed with the old key fail; startup fails safely without configured credentials; no usable secret remains in committed configuration/history used for releases.

## SEC-06 — High: infrastructure is published without authentication or transport security

**Evidence:** `docker-compose.yml` publishes MongoDB 27017, Kafka 9092/29092, ZooKeeper 22181, and Kafka UI 9000 without loopback host bindings or a production override. Mongo has no authentication configuration; Kafka uses PLAINTEXT; service listeners are HTTP. These are deployment facts, not proof of public Internet exposure on the user's network.

**Impact:** machines that can reach the host's published ports may read/change business data or inject events, bypassing application controls. Browser credentials and personal data travel unencrypted outside a trusted local setup.

**Framework:** ASVS V12 Secure Communication, V13, V14 Data Protection; API8:2023.

**Correction:** isolate data/event ports, bind optional local tools to loopback, enable authenticated least-privilege database/broker users and encrypted channels, and terminate HTTPS at a controlled ingress. Separate demo and production deployment profiles.

**Acceptance:** external port checks expose only intended ingress; unauthenticated database/broker/UI access fails; valid TLS is enforced across the deployment's trust boundaries.

## SEC-07 — High: server-side abuse limits and domain validation are missing

**Evidence:** service inputs are mainly structurally typed. There are no server login throttles, account lockout controls, operation quotas, pagination limits, or configured request-size limits in this repository. Transport accepts negative fares/capacity and arbitrary statuses; ticketing accepts arbitrary ticket types/prices; payment accepts arbitrary methods/amounts. Passenger registration checks nonempty fields only. Client-side security settings cannot enforce these policies against direct HTTP requests.

**Impact:** brute-force attacks, account/notification/payment spam, invalid business state, and expensive unbounded reads are possible. This refers to absent application policy, not a claim that the Ballerina HTTP runtime has no default limits.

**Framework:** ASVS V2, V4 API and Web Service, V6; API2, API4, API6:2023.

**Correction:** centralize server input constraints and normalized identities; apply per-principal/IP throttling, bounded payloads and page sizes, and domain-specific invariants. Avoid browser-only enforcement.

**Acceptance:** negative/oversized/unknown-enum inputs fail with 4xx; repeated login/payment/notification abuse is bounded; list endpoints have capped pagination.

## SEC-08 — Medium: sensitive data is logged and audit attribution is unreliable

**Evidence:** passenger registration logs email, phone, and names (`passenger_service/main.bal:151–154`); login logs the password hash (`:241`). Notification output includes recipient, body, and arbitrary metadata (`notification_service/main.bal:296–309`). Admin changes use no verified actor. The browser audit module uses client-controlled storage.

**Impact:** logs disclose personal data and credential-derived material, while operators cannot rely on them to attribute privileged changes.

**Framework:** ASVS V14, V16 Security Logging and Error Handling.

**Correction:** remove password/hash/token logging, minimize/redact personal data, and record protected server audit events with actor, target, action, result, correlation ID, and a retention/access policy.

**Acceptance:** representative registration/login/payment/notification logs contain no credentials; privileged operations generate server-side audit records that a browser cannot rewrite.

## SEC-09 — High: stored and DOM HTML injection executes in browser renderers

**Evidence:** `ui/scripts/modules/transport.js:59–76` places route names/locations directly into innerHTML; routes can be created through the transport service. `controller.js:283–291` interpolates trip details into HTML. Ticketing, admin, payment, notification, and search templates repeat unescaped interpolation; search's no-results message includes the raw query (`search.js:596–612`). Some other renderers escape correctly, so this is inconsistent application rather than absence of all encoding.

**Locally reproduced:** a harmless data-image onload marker executed in both the actual trip-details renderer and transport route-results renderer. The route renderer consumed a synthetic API fixture containing the marker. This proves the sink executes API-supplied markup; persisting the fixture through a real Mongo-backed API was not tested. See `evidence/browser-probes.json`.

**Impact:** malicious route/admin/notification/text content can execute script with the UI origin's privileges, read localStorage bearer tokens, and invoke the APIs as a user. No hosting configuration in this repository establishes a compensating CSP.

**Framework:** ASVS V1 Encoding and Sanitization, V3 Web Frontend Security, V14 Data Protection.

**Correction:** use DOM textContent/attribute setters or consistent context-aware encoding; use a maintained sanitizer only where rich text is explicitly required. Add a restrictive CSP and remove inline handlers to support it. Do not treat input filtering or CSP as a substitute for safe sinks.

**Acceptance:** hostile stored values, query text, error messages, and identifiers render as inert text across every renderer; no event attribute/script executes; a release-origin CSP check passes.

## SEC-10 — Medium: token lifecycle and account deletion are incomplete

**Evidence:** `ui/scripts/modules/api.js:174–179,204–215,333–335` trusts persisted localStorage session state and implements logout by deleting client storage. Passenger JWTs live for 3600 seconds (`passenger_service/main.bal:34`). Account deletion (`:553–599`) deletes only the user record; ticket writes/listing validate the token subject without checking that the user still exists (`:608–628,357–382`). There is no revocation/token-version mechanism or data-retention/deletion workflow for linked tickets, payments, and notifications.

**Impact:** a stolen/copied token can remain usable until expiry after logout or account deletion; deleted accounts can still create tickets through subject-only paths. Related personal/business data remains without an explicit retention policy. This is an engineering/data-lifecycle gap, not a legal-compliance conclusion.

**Framework:** ASVS V7 Session Management, V9, V14.

**Correction:** define server-side logout/revocation or short-lived credential/version semantics, invalidate deleted/disabled users, minimize browser token persistence, and implement a documented linked-data retention/anonymization policy.

**Acceptance:** a token copied before logout/deletion behaves according to the documented invalidation policy, disabled users cannot create entitlements, and linked records follow explicit retention rules without breaking financial reconciliation.
