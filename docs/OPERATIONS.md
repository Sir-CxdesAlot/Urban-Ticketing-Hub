# Local operation and recovery

## Build and readiness

Use `pwsh ./uth.ps1 setup`, `start`, `health`, and `seed`, in that order. The shared Dockerfile builds the generic Java adapter, packages/pushes the Ballerina core into the builder's local repository, then builds each service from its manifest and dependency lock. Runtime containers use Java 25 and an unprivileged account; they do not contain Maven or the Ballerina compiler.

MongoDB, Kafka, all six application services, and the gateway have real health checks. Startup waits for healthy dependencies and the helper waits for the entire stack. MongoDB initializes an authenticated single-node replica set; the application uses a separate read/write account scoped to `uth_demo_v2`. Database and broker ports are not published. The local gateway applies body/time/rate limits and security headers and serves the browser from the same origin as the API. Its upstream addresses refresh through Docker DNS, so replacing a service container cannot leave it using a stale IP address.

Use `docker compose ps` and targeted `docker compose logs SERVICE` for diagnostics. Treat logs and ignored credential files as sensitive. Do not paste secrets into issue reports. A failed readiness check is a failed helper process; it is not a successful release.

## Backup and restoration

`pwsh ./uth.ps1 backup` writes an ignored timestamped compressed archive under `.runtime/backups/`. It uses MongoDB's oplog capture so transactions spanning collections can be restored consistently. The archive contains authentication and personal data: restrict access, keep a secure external copy, and do not commit it.

`pwsh ./uth.ps1 restore-check -BackupPath PATH` creates a temporary MongoDB container without network access, copies the archive, restores with `--oplogReplay`, checks application records, and removes only that container. This proves restoration without overwriting live data. A restore or cleanup failure returns a failed command.

For actual disaster recovery: stop application writers, preserve the damaged volume for investigation, start a replacement MongoDB instance with the same supported version, restore the full archive with oplog replay, initialize its replica set and application connection settings, then run readiness and integration checks before allowing writes. Do not run `mongorestore --drop` against the active demo as a verification shortcut.

## Outbox and notifications

Business operations commit their state and outgoing events together. The ticketing worker expires unpaid holds and overdue unvalidated bookings independently of Kafka. The notification worker publishes pending events with broker acknowledgement. Publication failures retain the event and increment visible attempt information. Kafka consumers commit offsets only after notifications or quarantine records are durable. A retry can duplicate delivery attempts; event/recipient uniqueness prevents duplicate notifications.

Super administrators inspect pending events and failed deliveries in the staff workspace. Invalid messages are quarantined; inspect the stored reason and payload before retrying through the protected API. A malformed payload needs a corrected producer/schema or operator-directed data repair before retry can succeed; retry does not rewrite invalid data. A malformed message does not permanently block the Kafka partition. Never edit financial state in response to Kafka messages.

## Resource and security boundaries

The application containers have memory/CPU caps, a read-only root filesystem, temporary writable storage, dropped capabilities, and no-new-privileges. All nine containers rotate logs at 10 MiB with three files retained. The gateway listens on loopback only. MongoDB, Kafka, and storage share one host; losing that host interrupts service. A majority write on one MongoDB member is durable against a normal restart, not loss of its disk. Backups are recovery, not high availability.

HTTP and internal Kafka traffic are plaintext within this local deployment. Internet access requires a separately reviewed TLS/reverse-proxy setup, stronger identity controls, monitoring, and host/network hardening. This demo does not claim ASVS Level 2 conformity or production certification.

## Toolchain and dependency policy

Ballerina is pinned to 2201.14.1; the MongoDB Java driver is pinned to 5.13.0. Kafka uses the Ballerina 4.6.7 connector, whose client dependency is 3.9.2, with broker 4.4.0. Base images are pinned by digest. Small derived images patch Brotli/curl/Expat/LZ4, MongoDB's YAML helper, and the Go runtime embedded in gosu; downloaded replacements have checksums. The build uses dependency locks and retains the actual Ballerina locks inside each application image. Intentional upgrades regenerate and review locks, then rerun native, API, browser, and image checks. The archived audit's old Kafka 3.9.1 matches are not evidence about the replacement artifacts.

Run vulnerability checks against the final dependencies and images. A source scan or an unexecuted CI configuration is not evidence that the deployed image is free of advisories. Record exact versions, scan date, and unresolved matches in `REMEDIATION.md`.
