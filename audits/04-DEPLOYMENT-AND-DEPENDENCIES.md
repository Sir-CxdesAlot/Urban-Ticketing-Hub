# Deployment, dependencies, and operations audit

All locations refer to baseline `7d56d4e`. Repository omissions describe the supplied deployment, not unknown infrastructure outside this repository.

## OPS-01 — High: committed infrastructure versions are past their support windows

**Evidence:** `docker-compose.yml:4,17,46` uses Confluent Kafka/ZooKeeper 7.4.0 and MongoDB 6.0. As of the audit date, MongoDB 6.0 reached end of life on 2025-07-31, and Confluent 7.4's standard/platinum windows ended on 2025-05-03 / 2026-05-03. Confluent 7.4 corresponds to Kafka 3.4, whereas README claims Kafka 4.1.0. These lifecycle conclusions are supported by [MongoDB's schedule](https://www.mongodb.com/legal/support-policy/lifecycles) and [Confluent's version table](https://docs.confluent.io/platform/7.4/installation/versions-interoperability.html).

**Impact:** the deployment misses supported maintenance/security coverage and documentation misrepresents its broker. Lifecycle risk is not a claim that a particular CVE is exploitable.

**Correction:** choose supported compatible versions, test driver/broker compatibility and data upgrades, then pin validated image digests and establish an update owner. **Acceptance:** fresh install plus upgrade/rollback testing passes on supported versions; image/SBOM scans cover the exact release artifacts.

## OPS-02 — Medium: Docker builds discard the dependency lockfiles

**Evidence:** all six Dockerfiles copy `Ballerina.toml`, `Config.toml`, and `main.bal`, then run `bal build`. None copies `Dependencies.toml` or requests sticky resolution. All six manifests pin Ballerina 2201.12.10; six devcontainers match that runtime. The baseline contains 41 unique Ballerina package/version pairs, including `ballerinax/kafka:4.6.1`, `mongodb:5.2.2`, `confluent.cavroserdes:1.0.2`, and `confluent.cregistry:0.4.1`.

**Impact:** Docker may resolve different libraries from the reviewed source lockfiles, and rebuilding a tag later can change the artifact. The local audit demonstrated the distinction: sticky builds with a newer installed runtime failed to load old BIR dependencies; soft resolution produced all six JARs after changing only temporary copies.

**Correction:** define one supported toolchain and dependency policy; copy and honor locks in reproducible builds; emit an SBOM and artifact hashes, and test upgrades explicitly. **Acceptance:** two clean builds resolve the same approved dependencies; release metadata ties source commit, image digest, SBOM, toolchain, and test results together.

## OPS-03 — High: startup ordering does not wait for dependency readiness

**Evidence:** `docker-compose.yml` uses short `depends_on` entries without health checks/readiness conditions. Clients/producers/listeners are initialized with `check new` at module initialization. Only MongoDB declares a restart policy; application services do not. Service health endpoints are not wired to Compose health checks.

**Impact:** starting containers in dependency order does not ensure MongoDB/Kafka is ready. A transient startup failure may terminate a service with no application restart/retry policy. Failure is source-derived and was not reproduced against Docker because its engine was unavailable.

**Correction:** implement health-based startup dependencies, bounded retry/backoff for transient failures, explicit restart behavior, and graceful shutdown. **Acceptance:** repeated clean starts and delayed database/broker startup converge without manual restarts; failed dependencies cause appropriate readiness failures.

## OPS-04 — Medium: environment overrides use the wrong naming convention

**Evidence:** Compose exports `mongoHost`, `mongoPort`, `databaseName`, and `kafkaBootstrapServers`; README documents a third set (`MONGO_HOST`, etc.). Ballerina uses `BAL_CONFIG_VAR_*` for individual configurable values. Passenger constructs MongoDB with hardcoded host/port (`passenger_service/main.bal:15–21`) despite declaring configurable variables.

The committed Config.toml values happen to match the Compose network, masking the ignored overrides in this one environment. [Official Ballerina configuration documentation](https://ballerina.io/learn/provide-values-to-configurable-variables/) establishes the naming convention.

**Correction:** use supported configuration names consistently, remove hardcoded passenger connectivity, validate required settings at startup, and document local/container profiles. **Acceptance:** override host, port, database, and broker to distinct test values and observe every client/listener use them.

## OPS-05 — High: the supplied deployment has single points of failure and no recovery procedure

**Evidence:** Compose has one MongoDB instance, one broker, replication factor 1, and transaction/offset replication settings of 1. Kafka/ZooKeeper have no explicitly managed persistent volumes; MongoDB has one named volume. No backup/restore script, migration runner, retention policy, RPO/RTO target, or disaster-recovery procedure exists in the tracked tree.

**Impact:** host/storage loss or container replacement can interrupt service and risk event/data loss. An automatically created image volume, if present, is not a documented durable storage/recovery strategy. This layout may be adequate for a classroom demo but does not establish production reliability.

**Correction:** distinguish demo topology from production requirements; provide managed durable storage, tested database backups/restores, broker retention/replication, migration controls, and recovery ownership. **Acceptance:** restore a known dataset into an isolated environment and verify ticket/payment reconciliation within stated recovery objectives.

## OPS-06 — Medium: health and observability do not describe actual service readiness

**Evidence:** transport health returns a constant (`transport_service/main.bal:680`); other health checks count entire collections and do not check Kafka consumers. Admin dashboard always returns OPERATIONAL (`admin_service/main.bal:522`). Manifests include observability but no collector, dashboards, alert rules, correlation IDs, or documented SLOs are configured. Several errors collapse to successful empty/default statistics (`payment_service/main.bal:228–238`).

**Impact:** outages/backlogs can look healthy or like zero business activity, and investigations cannot reliably correlate a purchase through its services.

**Correction:** separate liveness/readiness, check required dependencies cheaply, export queue lag/error/latency metrics, propagate correlation IDs, and alert on stuck payments and event failures. **Acceptance:** dependency outages and failed workers produce accurate readiness and actionable alerts rather than OPERATIONAL or fabricated zeros.

## OPS-07 — Medium: release hardening and browser hosting are unspecified

**Evidence:** Dockerfiles build and run with the full build image, lack a multi-stage/minimal runtime, and do not set application-level user/security policy. Effective inherited image user was not inspected. `--platform=$BUILDPLATFORM` makes the build architecture the image choice; cross-target compatibility is untested. Compose provides no resource caps, read-only filesystem/capability restrictions, or browser/HTTPS ingress service. Passenger's Dockerfile EXPOSE 8081 disagrees with its actual 8080 listener, although Compose correctly maps host 8081 to container 8080.

**Impact:** deployment assumptions are implicit, resource exhaustion is less contained, and the browser has no documented release path. The EXPOSE mismatch is metadata drift, not proof the current Compose port mapping is broken.

**Correction:** define and test a minimal runtime and least-privilege container policy; set resource budgets; provide a static UI server/ingress with security headers and environment-specific API routing. Align exposed-port metadata. **Acceptance:** release images run under the intended nonprivileged identity on supported target architectures and the served UI works over the intended origin/HTTPS setup.

## OPS-08 — High: locked Kafka connector metadata references a vulnerable Java client

**Evidence:** the project's lockfiles select `ballerinax/kafka:4.6.1`. Its [vendor-tagged manifest](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-kafka/v4.6.1/ballerina/Ballerina.toml) declares `org.apache.kafka:kafka-clients:3.9.1`. An OSV batch lookup for ten declared Java coordinates in the Kafka/MongoDB connector tags returned two advisories for that client: CVE-2026-35554 (producer race permitting message corruption/misrouting) and CVE-2026-33558 (sensitive Kafka request/response logging when DEBUG is enabled). Both have fixes in the 3.9.2 line; see the reviewed [producer advisory](https://github.com/advisories/GHSA-5qcv-4rpc-jp93), [logging advisory](https://github.com/advisories/GHSA-wf66-mphr-4c4r), and [lookup evidence](evidence/dependency-lookups.json).

**Impact and confidence:** this is a confirmed advisory match against vendor source metadata for a locked dependency, not a proof of exploitation or a scan of the deployed JAR. The DEBUG issue is conditional; DEBUG configuration enabling it was not established. Docker ignores these lockfiles (OPS-02), so actual release contents may differ. The producer issue matters to payment/notification event integrity, but its triggering timing was not reproduced.

**Correction:** upgrade the connector to a compatible release that embeds patched client libraries, fix reproducible resolution, and scan the resulting artifact plus its full transitive/runtime/container dependencies. Avoid DEBUG exposure of sensitive broker operations. **Acceptance:** the exact release SBOM contains no affected Kafka client version; relevant regression and integration tests pass; documented exceptions have owner/expiry and reachability evidence.

## Dependency and licensing assurance

The audit parsed all six lockfiles and captured package versions in [repository-checks.json](evidence/repository-checks.json). The repository is MIT-licensed; the single GIF and 24 SVGs have no embedded executable script/foreignObject/event handlers in the XML checks. Asset ownership/provenance and transitive distribution license obligations cannot be established from this repository alone.

The browser has no npm package tree, so `npm audit` would not scan this project's Ballerina/Java/container dependencies. All-version CVE clearance is **not established**. Exact container image contents were unavailable with Docker down; soft-resolved local JARs are not substitutes for the pinned release artifacts. Vendor metadata and any vulnerability lookups are recorded separately in validation. Add artifact-specific SCA, secret scanning, container scanning, dependency update automation, an SBOM, and license/NOTICE verification to the release gate (NIST SSDF PS.1, PS.3, PW.4, RV.1).

## Positive evidence

- All service/devcontainer manifests state an explicit Ballerina distribution and all services have dependency lockfiles.
- Compose defines a named network and a persistent MongoDB data volume; seed script is mounted read-only.
- Database indexes and health routes exist, giving a useful basis for stronger migrations and readiness checks.
- The frontend uses local assets; no third-party tracking/CDN script was found in its entry point.
