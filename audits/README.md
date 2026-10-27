# Urban Ticketing Hub audit

Audit date: 2026-10-27 (Africa/Windhoek). Baseline: commit `7d56d4e`. Scope: every tracked project file, plus repository-level delivery gaps. This is an evidence-based engineering audit, not a certification or a production penetration test.

**Historical snapshot:** subsequent helper-script consolidation moves/removes some paths cited below. The findings and evidence describe `7d56d4e`, not a fresh assessment of the current tree. Historical helper probes read that Git baseline. See [the consolidation record](../docs/SCRIPT-CONSOLIDATION.md) for the new commands and changes; backend/frontend findings require their own remediation and revalidation.

**Result: 50 grouped findings — 4 critical, 25 high, 19 medium, 2 low.** All **142 tracked files** and **62 HTTP resources** are included in the coverage/inventory. The project has substantial demo scaffolding, but it is not ready for production accounts, financial operations, or public deployment.

The principal blockers are unauthenticated privileged services, a committed JWT signing key, caller-controlled ticket/payment entitlements, incompatible shared ticket schemas, nondurable payment/event processing, and broken client API contracts. Local probes additionally reproduced executable HTML injection, Bash command injection, a false-success API test summary, and accessibility/reflow failures.

## Framework

The primary framework is [OWASP ASVS 5.0.0](https://asvs.owasp.org/), targeting the security rigor of Level 2 because this application handles accounts, personal data, ticket entitlements, and payments. Findings map to ASVS chapters rather than claiming that every individual requirement has been tested. [OWASP API Security Top 10 (2023)](https://api-security.owasp.org/editions/2023/en/0x11-t10/) adds explicit checks for object/function authorization, resource consumption, business-flow abuse, and service trust.

Security alone cannot cover this request. The audit also uses:

- [NIST SSDF 1.1](https://csrc.nist.gov/pubs/sp/800/218/final) for source protection, reproducible builds, testing, dependencies, release practices, and vulnerability response.
- [WCAG 2.2 AA](https://www.w3.org/TR/WCAG22/) and the installed Impeccable audit playbook for browser accessibility, responsiveness, theming, performance, and implementation integrity.
- Project-specific quality checks for correctness, API compatibility, distributed state, MongoDB schemas/indexes, deployment, resilience, observability, maintainability, documentation, and CLI behavior.

## Evidence and severity

Every finding records source locations, impact, a concrete correction, and a verification criterion. **Critical** means broad compromise or direct financial/entitlement bypass; **High** means major security, correctness, or availability impact; **Medium** means bounded defects or important operational gaps; **Low** means maintenance or usability debt. Frontend findings also carry the playbook's P0–P3 user-impact priority.

Evidence labels distinguish **source-confirmed**, **locally reproduced**, and **unverified runtime/deployment behavior**. Missing infrastructure never counts as a passing test. No claim of ASVS or WCAG conformance is made. File review coverage is recorded separately from test coverage.

## Reports

| Report | Contents |
|---|---|
| [00 — Findings register](00-FINDINGS.md) | All 50 findings, sorted by severity |
| [01 — Security](01-SECURITY.md) | Identity, access, passwords, secrets, input, data and browser injection |
| [02 — Data and business logic](02-DATA-AND-BUSINESS-LOGIC.md) | MongoDB, tickets, money, inventory, events, time and queries |
| [03 — Frontend](03-FRONTEND.md) | User flows, contracts, accessibility, theming, reflow and performance; 7/20 health score |
| [04 — Deployment and dependencies](04-DEPLOYMENT-AND-DEPENDENCIES.md) | Toolchain, supply chain, container/configuration, resilience and operations |
| [05 — Clients, tests and documentation](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) | PowerShell/Bash behavior, failure reporting, setup and maintainability |
| [06 — Validation](06-VALIDATION.md) | Executed checks, build evidence, synthetic probes, screenshots and limitations |
| [07 — API inventory](07-API-INVENTORY.md) | Every HTTP resource and event boundary |
| [08 — File coverage](08-FILE-COVERAGE.md) | Every baseline file, method of review and finding references |
| [09 — Remediation](09-REMEDIATION.md) | Repair dependencies, suggested owners, acceptance gates and regression scenarios |
| [10 — Framework coverage](10-FRAMEWORK-COVERAGE.md) | ASVS chapter/requirement mappings, API Top 10, SSDF and scope decisions |
| [11 — Architecture and threats](11-ARCHITECTURE-AND-THREATS.md) | System diagram, trust boundaries, workflow trace, data classes and STRIDE cross-check |

## Scope constraints

Production source and data were not modified. No live CRUD/seed script was run against the user's services. Browser service traffic, shell curl, and the failing HTTP-test probe used isolated synthetic data/stubs.

Docker's Linux engine was unavailable, so live MongoDB/Kafka/Compose behavior, recovery/concurrency/load testing, and exact container scans remain unverified. All six services compiled on temporary copies with installed Ballerina 2201.13.5 after soft dependency re-resolution; locked builds on that newer toolchain failed dependency loading. Exact 2201.12.10 release builds remain unverified. All 19 active JS, 18 PowerShell, and 5 Bash files passed their syntax/parser checks; an unloaded `.old` controller did not. See report 06 for the precise boundaries.

## Completion

Repository, source, configuration, data, client, delivery, documentation, asset-structure, history-pattern, and targeted browser reviews are complete within the recorded scope. Reports include both positive evidence and unresolved assurance checks. Remediation is proposed separately and has not been applied.
