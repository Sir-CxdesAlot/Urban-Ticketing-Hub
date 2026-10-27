# Findings register

**50 grouped findings:** 4 critical, 25 high, 19 medium, 2 low. Severity reflects potential impact in the supplied design; source findings and conditional dependency matches are not all reproduced exploits. See each report for confidence and verification limits.

| ID | Severity | Finding | Report |
|---|---|---|---|
| SEC-01 | Critical | authentication and authorization are absent from five services | [01-SECURITY.md](01-SECURITY.md) |
| SEC-02 | Critical | a passenger can mark a ticket paid and change its quantity | [01-SECURITY.md](01-SECURITY.md) |
| SEC-03 | Critical | caller-supplied payment value and ticket identity are trusted | [01-SECURITY.md](01-SECURITY.md) |
| SEC-05 | Critical | a committed signing key permits passenger-token forgery | [01-SECURITY.md](01-SECURITY.md) |
| DATA-01 | High | two incompatible ticket models share one collection | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-02 | High | fresh MongoDB seeding violates its unique indexes | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-03 | High | the ticket payment consumer uses the wrong Kafka address | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-04 | High | timestamp representations break reads and reporting | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-05 | High | validation cannot consume a multi-ride ticket correctly and is non-atomic | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-06 | High | refunds can repeat without limit and do not revoke tickets | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-07 | High | financial/background work and event publication are not durable | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-08 | High | schedule event variants violate the consumer contract | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-09 | High | selling tickets never reserves transport capacity | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| OPS-01 | High | committed infrastructure versions are past their support windows | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-03 | High | startup ordering does not wait for dependency readiness | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-05 | High | the supplied deployment has single points of failure and no recovery procedure | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-08 | High | locked Kafka connector metadata references a vulnerable Java client | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| QA-01 | High | no repeatable release-quality test/CI gate exists | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-02 | High | API scripts can report success while operations fail | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-03 | High | Bash request helpers execute caller input as shell code | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-04 | High | CLI authentication has incompatible and false-success behavior | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| SEC-04 | High | passwords use plaintext or unsalted SHA-256 | [01-SECURITY.md](01-SECURITY.md) |
| SEC-06 | High | infrastructure is published without authentication or transport security | [01-SECURITY.md](01-SECURITY.md) |
| SEC-07 | High | server-side abuse limits and domain validation are missing | [01-SECURITY.md](01-SECURITY.md) |
| SEC-09 | High | stored and DOM HTML injection executes in browser renderers | [01-SECURITY.md](01-SECURITY.md) |
| UI-01 | High / P0 | first load never fetches passenger routes | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-02 | High / P0 | browser API routes and payloads do not match services | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-03 | High / P1 | global search discards valid route and trip results | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-04 | High / P1 | unknown role checks fail open and navigation bypasses its own gates | [03-FRONTEND.md](03-FRONTEND.md) |
| DATA-10 | Medium | trip delays replace times with non-time text | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-11 | Medium | shared broadcast notifications have shared read state | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| DATA-12 | Medium | unbounded queries and mismatched indexes impede scaling | [02-DATA-AND-BUSINESS-LOGIC.md](02-DATA-AND-BUSINESS-LOGIC.md) |
| OPS-02 | Medium | Docker builds discard the dependency lockfiles | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-04 | Medium | environment overrides use the wrong naming convention | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-06 | Medium | health and observability do not describe actual service readiness | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| OPS-07 | Medium | release hardening and browser hosting are unspecified | [04-DEPLOYMENT-AND-DEPENDENCIES.md](04-DEPLOYMENT-AND-DEPENDENCIES.md) |
| QA-05 | Medium | ticket/transport CLI flows violate their contracts or are placeholders | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-06 | Medium | scripts assume inconsistent shell tools and successful HTTP transport | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-07 | Medium | setup and operational documentation references missing files and wrong behavior | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| QA-08 | Medium | initialization/debug helpers generate inconsistent or sensitive test state | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| SEC-08 | Medium | sensitive data is logged and audit attribution is unreliable | [01-SECURITY.md](01-SECURITY.md) |
| SEC-10 | Medium | token lifecycle and account deletion are incomplete | [01-SECURITY.md](01-SECURITY.md) |
| UI-05 | Medium / P1 | modal keyboard interaction and semantics are incomplete | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-06 | Medium / P1 | theme drift causes failed contrast and inconsistent components | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-07 | Medium / P1 | the narrow header clips login and theme controls | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-08 | Medium / P1 | quick actions and guest visibility are incomplete | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-09 | Medium / P1 | dashboards display fabricated or incompatible metrics | [03-FRONTEND.md](03-FRONTEND.md) |
| UI-10 | Medium / P2 | client requests and rendering have avoidable performance/error debt | [03-FRONTEND.md](03-FRONTEND.md) |
| QA-09 | Low | legacy source and repository policy gaps add maintenance noise | [05-CLIENTS-TESTS-AND-DOCUMENTATION.md](05-CLIENTS-TESTS-AND-DOCUMENTATION.md) |
| UI-11 | Low / P2 | animation and maintenance scaffolding need consolidation | [03-FRONTEND.md](03-FRONTEND.md) |
