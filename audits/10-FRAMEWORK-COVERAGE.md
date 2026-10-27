# Framework coverage and assurance map

The primary baseline is the official [OWASP ASVS 5.0.0 release](https://github.com/OWASP/ASVS/tree/v5.0.0/5.0), published in May 2025. Its official CSV was inspected to verify chapter names and requirement IDs. The recommended release target is Level 2, appropriate to this application's personal data and financial/entitlement integrity. The review is a comprehensive repository audit with targeted local validation, **not a completed ASVS L2 conformity assessment**.

The standard has 345 requirements: 70 introduced at L1, 183 at L2, and 92 at L3. An L2 assessment includes the L1 and L2 requirements (253 before applicability decisions). This audit does not divide findings by that total to produce a misleading compliance percentage.

## ASVS chapter disposition

“Defects confirmed” means the cited controls have problems; it does not mean every requirement in that chapter failed. “Not implemented” is a scope decision for an optional feature, not a missing-feature security finding.

| Chapter | L1 + L2 requirements | Disposition and evidence |
|---|---:|---|
| V1 Encoding and Sanitization | 27 | Defects confirmed: executable HTML sinks and Bash eval (SEC-09, QA-03). Structured Mongo query values are positive evidence; exhaustive injection testing remains open. |
| V2 Validation and Business Logic | 11 | Defects confirmed: caller-controlled entitlements/payments, state/atomicity/refund/inventory gaps (SEC-02–03, SEC-07, DATA-05–09). |
| V3 Web Frontend Security | 19 | Defects confirmed: raw sinks, origin/configuration and sensitive browser state; serving headers not established (SEC-09–10, UI-02). Live release headers/cache/origin controls remain unverified. |
| V4 API and Web Service | 10 | Defects confirmed: incompatible contracts and unbounded resources (UI-02, DATA-12). GraphQL/WebSocket features are not implemented; protocol-level gateway/fuzz tests remain open. |
| V5 File Handling | 9 | User-upload/download/archive-processing features not implemented. Static local assets were structurally checked; production static hosting is unverified. |
| V6 Authentication | 35 | Defects confirmed: absent staff session, weak/plaintext passwords and no server abuse policy (SEC-01,04,07). MFA/recovery/authenticator flows are absent; their applicability requires a defined authentication policy. |
| V7 Session Management | 18 | Defects confirmed: client-only logout and deleted-user token lifecycle (SEC-10). Full concurrent-session, fixation, expiry and transport assessment remains open. |
| V8 Authorization | 7 | Defects confirmed: missing function/object/property restrictions and client-only capabilities (SEC-01–03, UI-04). No server role matrix can be certified. |
| V9 Self-contained Tokens | 7 | Issuance/validation code and issuer/audience checks present; committed signing key compromises trust (SEC-05). Algorithm confusion/claim/lifetime/rotation tests remain open. |
| V10 OAuth and OIDC | 29 | OAuth/OIDC not implemented; custom JWT issuance is not an OAuth flow. These optional-feature controls are outside the current feature scope. |
| V11 Cryptography | 14 | Defects confirmed: unsalted fast password hashing/plaintext storage and embedded signing key (SEC-04–05). Runtime crypto-provider/key-store assurance remains open. |
| V12 Secure Communication | 9 | Defects confirmed in supplied topology: HTTP/plaintext data/broker connections (SEC-06). External TLS termination/certificate configuration was unavailable. |
| V13 Configuration | 13 | Defects confirmed: exposed unauthenticated backend components and ineffective config overrides (SEC-06, OPS-04); deployment hardening unverified (OPS-07). |
| V14 Data Protection | 9 | Defects confirmed: logging, access and retention/lifecycle gaps (SEC-01,08–10). Privacy policy, encryption-at-rest and external hosting assurance remain open. |
| V15 Secure Coding and Architecture | 13 | Defects confirmed: shared-schema drift, nondurable workflow coordination, affected dependency metadata and release gaps (DATA-01,07; OPS-02,08). Architecture/threat model captured in report 11. |
| V16 Security Logging and Error Handling | 16 | Defects confirmed: credential-derived logs, untrusted audit attribution, masked errors/fabricated health (SEC-08, DATA-12, OPS-06, UI-09). Central log protection/retention remains unverified. |
| V17 WebRTC | 7 | WebRTC/signaling/media features not implemented. Outside current feature scope. |

## Selected exact requirement mappings

Descriptions below are short audit topic labels, not copied requirement text. IDs were checked against the official v5.0.0 CSV.

| ASVS requirement | Audit topic | Finding / evidence |
|---|---|---|
| V1.2.1 | Context-specific output encoding | SEC-09, locally reproduced script execution |
| V1.2.5 | OS command injection protection | QA-03, locally reproduced eval marker |
| V2.2.1 | Business input validation | SEC-07, source constraints absent |
| V2.3.1 | Required business-flow order | SEC-02–03, DATA-07 |
| V2.3.2 | Business limits | DATA-06, repeated-refund source path |
| V2.3.3 | All-or-nothing business operations | DATA-05–09, split reads/writes/events |
| V2.4.1 | Anti-automation controls | SEC-07, application policy absent |
| V3.4.3 | CSP | SEC-09 / OPS-07: serving policy not established; deployed response unverified |
| V6.1.1, V6.3.1 | Documented and enforced login abuse controls | SEC-07, browser-only lockout |
| V7.4.1, V7.4.2 | Logout and deleted-account invalidation | SEC-10, no backend invalidation |
| V8.2.1 | Function authorization | SEC-01 |
| V8.2.2 | Object authorization | SEC-01; passenger owner filters are positive but incomplete system coverage |
| V8.2.3 | Property authorization | SEC-02–03 |
| V8.3.1 | Trusted authorization enforcement | SEC-01, UI-04 |
| V9.1.1 | Token integrity verification | Passenger validates MAC; SEC-05 makes its embedded key untrustworthy |
| V11.4.2 | Password derivation | SEC-04 |
| V13.2.1, V13.2.2 | Service identity and least privilege | SEC-06 |
| V16.2.5 | Sensitive log handling | SEC-08 |

## OWASP API Security Top 10 cross-check

| 2023 risk | Disposition |
|---|---|
| API1 Broken Object Level Authorization | Confirmed across ticket/payment/notification resources (SEC-01) |
| API2 Broken Authentication | Confirmed missing staff credentials, weak password/session/abuse design (SEC-01,04,05,07,10) |
| API3 Broken Object Property Level Authorization | Confirmed price/status/entitlement tampering (SEC-02–03) |
| API4 Unrestricted Resource Consumption | Unbounded reads/creation; no app quotas/pagination (SEC-07, DATA-12) |
| API5 Broken Function Level Authorization | Privileged admin/transport/financial functions unprotected (SEC-01) |
| API6 Unrestricted Access to Sensitive Business Flows | Payment/refund/validation/reservation abuse (SEC-02–03, DATA-05–09) |
| API7 Server Side Request Forgery | No client-controlled URL-fetching feature found in the reviewed service paths. Not an SSRF clearance of dependencies or external deployment. |
| API8 Security Misconfiguration | Published unprotected data/control ports, ineffective config, missing release hardening (SEC-06, OPS-04,07) |
| API9 Improper Inventory Management | 62-resource inventory now supplied; documentation/client contracts drift (UI-02, QA-07) |
| API10 Unsafe Consumption of APIs | Trusted caller/event data without ownership/value/state reconciliation (SEC-03, DATA-07–08) |

## NIST SSDF cross-check

| Practice group | Repository evidence and gaps |
|---|---|
| Prepare the Organization (PO) | No security requirements/role matrix, CI quality gate, release criteria or supported environment policy; audit now records evidence and proposed gates (QA-01, QA-07, OPS-02). |
| Protect the Software (PS) | Secret in source/history, no artifact provenance/SBOM/verified release archive or signature policy (SEC-05, OPS-02). Remote branch/access protections were not inspected. |
| Produce Well-Secured Software (PW) | Canonical contracts, authentication, business integrity, safe sinks, test quality, dependency/update and deployment gaps documented across reports. |
| Respond to Vulnerabilities (RV) | No tracked disclosure/security contact or vulnerability triage/remediation policy; specific dependency matches and repair order supplied (OPS-08, QA-09). Organizational response outside the repository is unverified. |

## Accessibility and quality scope

The frontend report uses the Impeccable technical audit's five dimensions and WCAG 2.2 AA. Confirmed contrast/reflow/dialog issues are separated from preferences such as 44px touch targets, decorative stripe/bounce warnings, and unmeasured performance claims. A full screen-reader/cross-browser/zoom/state verification remains required. ISO or ASVS certification and production penetration testing were not performed.
