# Urban Ticketing Hub

A university/demo transport ticketing application for Windhoek. Find trips, reserve seats, buy route-specific tickets, validate bookings, and manage transport. Payments are simulated; notifications are in-app.

The application keeps six Ballerina services, MongoDB, Kafka, and plain HTML/CSS/JavaScript. [Architecture and decisions](docs/ARCHITECTURE.md) explains why, advantages, drawbacks, implemented concepts, database joins, and complexity assumptions. [Repair status](docs/REMEDIATION.md) distinguishes implemented changes from verified behavior. The original [audit](audits/README.md) is historical evidence.

## Run the demo

Install Docker Desktop with Linux containers and PowerShell 7.2 or later. Use a shell in this repository:

```powershell
pwsh ./uth.ps1 setup
pwsh ./uth.ps1 start
pwsh ./uth.ps1 health
pwsh ./uth.ps1 seed
```

Open **http://localhost:8080**. The first build downloads the pinned toolchain and dependencies and takes several minutes. `start` waits for dependency, application, and gateway health checks before reporting success. `health` repeats the six application checks. Use the HTTP address so the browser and API share one origin.

`setup` generates random local secrets in ignored `.env` and `.runtime/mongo-key` files. The bootstrap administrator's email and password are in `.env`. `seed` generates separate passenger, operator, and manager credentials in ignored `.runtime/demo-credentials.json`; it prints the path, not the passwords. Use the same sign-in form for every role.

Existing secrets are preserved. Seeding reuses accounts, routes, same-day scheduled fixtures, and operation keys; it does not reset passwords or delete data. A new seed day adds future trips. Example travel data is in `scripts/demo-data.json` and contains no account passwords.

The new Compose project uses `uth-demo-v2` volumes and database `uth_demo_v2`. It does not remove the old database volume. Only the gateway is published, on loopback port 8080. MongoDB, Kafka, and the six services are internal.

## Commands

One cross-platform helper replaces the old root scripts:

```powershell
pwsh ./uth.ps1                     # help
pwsh ./uth.ps1 cli                 # interactive passenger/staff client
pwsh ./uth.ps1 test                # read-only public/readiness smoke checks
pwsh ./uth.ps1 test -Suite unit    # Ballerina business/security boundary tests
pwsh ./uth.ps1 test -Suite integration
pwsh ./uth.ps1 test -Suite browser
pwsh ./uth.ps1 backup
pwsh ./uth.ps1 restore-check -BackupPath .runtime/backups/ARCHIVE.archive.gz
pwsh ./uth.ps1 stop                # stop the new stack; preserve volumes
```

`-BaseUrl http://localhost:8080` selects a different gateway origin. Supplying an origin without a nondefault port retains the old helper's direct-port routing for explicitly configured development environments; the default Compose deployment does not publish those ports. `test -Suite crud` is a compatibility alias for the real integration suite. Service selection applies to health checks; integration tests intentionally cover cross-service workflows.

The browser and integration suites require a running seeded application. Native tests require Ballerina **2201.14.1** and JDK **25**; the Java adapter compiles with Maven **3.9.16** at Java release 21 and runs on Java 25. To build locally, run Maven, then `bal pack` and `bal push --repository local` inside `core`, then `bal build` in each service. Docker performs these steps automatically.

```powershell
npm ci
python -m pip install -r requirements-dev.txt
npx playwright install chromium
python -m unittest discover -s tests -p test_helpers.py -v
python -m unittest discover -s tests -p test_application.py -v
npx playwright test
```

Tests use uniquely named fixtures. Cleanup cancels their trips, retires their routes, and deactivates their accounts; retained financial/audit records remain attributable. A cleanup failure fails the suite. The integration suite briefly stops and restarts this demo's Kafka service to verify recovery.

## Travel and staff rules

| Ticket | Travel rights | Price |
|---|---|---|
| `SINGLE` | One selected trip | One route fare |
| `TEN_RIDE` | Ten rides on one route, valid 30 days | Eight fares |
| `MONTHLY` | Unlimited rides on one route for 30 days | Twenty fares |

Purchase includes a ten-minute unpaid seat hold for the first trip. Payment confirms the booking. Later pack/pass bookings reserve another seat and, for a pack, one available ride. Cancelling releases the reservation. Validation consumes one ride exactly once; it opens 30 minutes before departure and closes two hours after arrival. Validation does not make an occupied seat available for resale.

Unvalidated bookings expire after their validation window or ticket validity ends and release their reserved ride. A single-trip ticket can rebook only its original trip. Prices, eligibility, and expiry are enforced by the server.

A full refund is available once before any ride has been validated. It revokes the ticket and cancels its active bookings. A passenger can hold at most 100 active bookings; trips contain 1–200 seats. A route must have no scheduled future trips before it can be retired. Deleting a passenger profile requires cancelling or completing active bookings, then removes profile details and revokes access while preserving attributable financial records.

Passengers access their own records. Operators validate bookings for assigned trips. Transport managers manage routes/trips, announcements, and reports. Super administrators also manage staff/account access and inspect audit/delivery records. Unknown roles are denied. Role changes, deactivation, and logout invalidate existing sessions on the server.

## API and implementation

[OpenAPI contract](docs/openapi.json) describes the six namespaces behind `/api/v1/`: `passenger`, `transport`, `ticketing`, `payment`, `notification`, and `admin`. Login returns `{token, user}`. Authenticated requests use `Authorization: Bearer TOKEN`. Tokens are random; their hashes are stored server-side. Idle expiry is 30 minutes; absolute expiry is eight hours.

Lists return `{items, limit, offset, total}` with default limit 20 and maximum 100. Amounts use integer NAD minor units (`850` means NAD 8.50), IDs use UUID strings, and timestamps use UTC ISO 8601. Failures return `{error: {code, message}}`; credentials and driver errors are never returned. Purchase, booking, payment, and refund requests require a unique `requestKey`; retries must reuse it with the same input.

`core/` contains shared Ballerina authentication, validation, and business functions. `database/` is a generic official-driver adapter for MongoDB operations and transactions. Service entrypoints expose only their namespace. Transactions protect inventory, entitlements, payments, validation, refunds, audit, and outgoing events. Kafka publication and notification consumption are at least once with durable deduplication.

## Recovery and limitations

Backups include the oplog. `restore-check` restores into a temporary network-isolated container and verifies application records, then removes that container. It never overwrites the running database. See [operations](docs/OPERATIONS.md) for recovery and diagnostics.

This single-machine demo has no high availability. Its loopback HTTP gateway and private container network are a local trust boundary, not Internet TLS or protection against a compromised host. Real payment processing, email/SMS delivery, MFA, and Internet production deployment are outside this release. Backups contain sensitive data and must stay private. Verification gaps are listed in the repair tracker.
