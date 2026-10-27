# One helper entrypoint

Use PowerShell **7.2 or later** and `pwsh ./uth.ps1 help`. There is one public script; HTTP handling, menus, fixtures, tests, and operations live in five small internal modules. The earlier [consolidation record](../docs/SCRIPT-CONSOLIDATION.md) explains the removal of 23 root scripts.

## Commands

| Command | Purpose |
|---|---|
| `setup` | Generate ignored local secrets without replacing existing values |
| `start` / `stop` | Build/start or stop this demo's Compose project; preserve volumes |
| `build` | Build application and patched infrastructure images |
| `cli` | Passenger/staff menus using actual server sessions |
| `seed` | Reuse/create demo fixtures through the real authenticated APIs |
| `health` | Check all six actual dependency-readiness endpoints |
| `test` | Read-only readiness and public route/trip checks |
| `test -Suite unit` | Native Ballerina tests; Docker is not required |
| `test -Suite integration` | Real API, authorization, transaction and recovery tests |
| `test -Suite browser` | Playwright workflows, keyboard, layout and accessibility checks |
| `backup` | Save a consistent compressed archive with oplog capture |
| `restore-check -BackupPath PATH` | Restore into a disposable isolated replica set |

The default origin is `http://localhost:8080`. `-Service` restricts readiness/smoke selection; integration tests cover the complete workflow. `-Suite crud` remains an alias for integration tests. `-Role` is a menu preference, never a server permission. Request/assertion/cleanup failures produce a failed process exit code.

## Runtime and data

Native unit tests require Ballerina 2201.14.1 and the built Java adapter. Docker builds the pinned toolchain automatically for normal application startup. PowerShell 7.2 is the minimum because secret generation uses modern .NET cryptographic APIs. Operations resolve the Docker executable directly, so a user-profile alias that redirects `docker` to an old WSL installation cannot break the helper.

`seed` creates or reuses one operator, a second operator, one manager, five passengers, five routes, 25 date-relative trips, and three ticket-product fixtures. The bootstrap administrator is initialized using generated `.env` credentials. Passenger/staff passwords are generated once into ignored `.runtime/demo-credentials.json`; no passwords are committed or printed. Existing account passwords and ticket states are preserved. A later UTC day adds a new future trip window.

Run health checks before seeding. The default database is `uth_demo_v2` in new named volumes; there is no reset/drop option. Existing legacy volumes are not migrated or removed.

## Verification boundaries

`tests/test_helpers.py` uses only an ephemeral loopback fake API. It verifies HTTP failure propagation, selection, read-only smoke, menu exit, UTF-8/quoting, bearer headers, and dictionary shapes across pagination. It cannot verify MongoDB or Kafka.

`tests/test_application.py` uses the real stack, validates documented response shapes, and creates uniquely named fixtures. It checks permissions, prices, retries, seat/ride/refund concurrency, expiry, joins/indexes, notifications, and broker/worker recovery. Cleanup cancels only its own trips, retires its routes, and deactivates its accounts; retained audit/payment records remain attributable. Cleanup failure fails the suite. Its outage checks briefly stop and restart this demo's Kafka/notification service.

Browser reports retain screenshots rather than network traces, which could contain credentials. Read [current verification results](../docs/VERIFICATION.md) before treating any check as evidence about the application.
