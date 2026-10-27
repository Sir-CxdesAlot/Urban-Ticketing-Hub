# Clients, tests, documentation, and maintainability audit

## QA-01 — High: no repeatable release-quality test/CI gate exists

**Evidence:** no tracked CI configuration, Ballerina test directory, frontend test-runner configuration, API specification, automated coverage report, or release pipeline. Existing scripts exercise happy-path CRUD against live localhost services; `ui/scripts/modules/testing.js` mainly checks role tables and function presence in the browser. Several tests change roles without setting/restoring the associated authentication state robustly.

**Impact:** authorization bypasses, cross-service schema drift, payment replay/refunds, concurrency, and broken browser routes are not caught before release. File review and syntax checking are not code/test coverage measurements.

**Correction:** create a hermetic test environment with contracts and meaningful negative, concurrency, replay, schema, lifecycle, and browser tests. Gate releases on the supported pinned runtime and exact images, plus security/accessibility checks. **Acceptance:** CI fails on regressions represented by this audit and publishes actual results; no test relies on a developer's existing database/session.

## QA-02 — High: API scripts can report success while operations fail

**Evidence:** `test-apis.ps1:243–263` prints an unconditional green success summary; its helper returns failure objects that callers log without propagating. A local probe replaced `Invoke-RestMethod` with a throwing function: all health checks and workflows failed, the script still said the APIs were working correctly, and the process exited 0. See [probe log](evidence/test-script-probe.log).

Other CRUD scripts often only print errors after the initial health/create check. Notification health returns a JSON string, while `test-notification-apis.ps1:92` compares the raw curl body against an unquoted string, creating another source-level false failure. Bash scripts use grep/regex against compact JSON and often do not inspect HTTP status. Ticketing/payment validation/refund failures are treated as informational rather than establishing the intended lifecycle. Passenger tests deliberately mark a ticket PAID as the user, thereby approving SEC-02 instead of detecting it.

**Correction:** accumulate assertion failures and exit nonzero; parse JSON structurally; assert transport status, response schema, and domain result; await eventual processing with a deadline; clean up in finally/traps. **Acceptance:** inject a failure at every step and verify a failed test result/nonzero exit; valid pretty-printed JSON works; unauthorized state changes are rejected by tests.

## QA-03 — High: Bash request helpers execute caller input as shell code

**Evidence:** `admin-cli.sh:26–30` and `passenger-cli.sh:29–33` build an `eval curl` command from URL, body, and token strings. The Bash admin/notification test helpers also use eval for constructed curl commands. A safe local probe loaded only the two CLI helpers and replaced curl with a function; a URL containing `; printf AUDIT_EVAL_MARKER` executed that marker in both helpers. No HTTP calls occurred.

**Impact:** URL/body values containing shell syntax can run commands as the CLI user. Separately, hand-built JSON fails for ordinary apostrophes/quotes. The fallback `&& ... || ...` can repeat a request when the first branch fails. Session files use predictable `/tmp/*-session-${USER}.txt` paths, are written without restrictive permissions/atomic creation, and are sourced as executable shell code.

**Correction:** use argument arrays without eval, JSON encoding, explicit HTTP status/error handling, and non-executable session data in a private directory. **Acceptance:** quotes/semicolons/command syntax remain inert data, only one request is attempted, session files have owner-only access and cannot inject commands.

## QA-04 — High: CLI authentication has incompatible and false-success behavior

**Evidence:** `admin-cli.ps1:127–135` marks LoggedIn true after any successfully returned HTTP response, including backend `{success:false}`; it expects nonexistent `token/admin` fields. Bash admin login (`admin-cli.sh:39`) requires a token the service never returns. Unified CLI (`urban-ticketing-cli.ps1:451–485`) treats an admin ID or literal `LOCAL_AUTH_NO_TOKEN` as a bearer credential. Bash registration (`passenger-cli.sh:43`) expects a token although registration returns a UserResponse only.

**Impact:** valid admin logins fail in some clients, invalid credentials appear logged in in another, and identifiers are mistaken for credentials. SEC-01 describes why the server currently allows later unauthenticated calls.

**Correction:** define one genuine server authentication protocol and align all clients; require explicit success plus valid credentials and clear stale state on failure. **Acceptance:** wrong passwords always fail and valid login works consistently without synthetic tokens/IDs.

## QA-05 — Medium: ticket/transport CLI flows violate their contracts or are placeholders

**Evidence:** `passenger-cli.ps1:358–377` only explains how to buy through another tool. Bash passenger tickets (`passenger-cli.sh:73–76`) calls `/ticketing/tickets/my`, which is not an ownership-list resource. Unified purchase (`urban-ticketing-cli.ps1:294–414`) permits SINGLE/RETURN/MONTHLY_PASS while passenger accepts SINGLE/MULTIPLE/PASS; its MULTIPLE branch is unreachable. It sends `trips?routeId=...` although that resource only filters by `status`; route-scoped trips have a separate endpoint. Bash admin route creation omits required `intermediateStops` and disruption creation omits required `startTime` (`admin-cli.sh:57,82`).

**Correction:** retain one maintained client model, normalize IDs/types, use the correct route-scoped resource, and complete or remove advertised placeholders. **Acceptance:** each CLI independently completes register/login/discovery/purchase/payment/history workflows against an isolated environment.

## QA-06 — Medium: scripts assume inconsistent shell tools and successful HTTP transport

**Evidence:** `data-init.ps1:110–134` and several test scripts invoke unqualified `curl`; Windows PowerShell 5.1 may resolve it to Invoke-WebRequest instead of curl.exe. Some other scripts explicitly use curl.exe. Most curl helpers omit `--fail-with-body`, status capture, and connection/overall timeouts; stderr is discarded. `$Verbose` logs can print passwords/tokens/bodies. Bash JSON extraction often assumes exact whitespace and depends on jq/python without consistent prerequisite checks.

**Correction:** specify supported PowerShell/Bash versions and tools, use structured native HTTP clients or explicit curl executable/status handling, enforce timeouts, and redact logs. **Acceptance:** supported Windows/Linux/macOS environments fail early on missing prerequisites, preserve actionable errors, and correctly reject HTTP 4xx/5xx responses without leaking credentials.

## QA-07 — Medium: setup and operational documentation references missing files and wrong behavior

**Evidence:** README's primary instructions refer to absent `setup.ps1/.sh`, `start.ps1/.sh`, `initialize-test-data.ps1/.sh`, `test-apis.sh`, and `status-monitor.ps1`; it uses placeholder repository URLs and `cd assignment2`. The actual initializer is `data-init.ps1`. Runtime configuration names differ from both Compose and Ballerina requirements (OPS-04). README claims Kafka 4.1.0 while Compose supplies Confluent 7.4/Kafka 3.4. It describes production/notification/monitoring behavior beyond the console simulation. API guides refer to the same missing initialization/start scripts; ADMIN-API-TESTS says all successful operations return `success:true`, although list/create/dashboard resources have different response shapes.

**Correction:** document only shipped commands and actual contracts; add UI serving instructions, explicit demo limitations, isolated testing, supported toolchain, migration/restore instructions, and a security/release owner. **Acceptance:** a new user can follow the guide on a clean checkout with no undocumented files or environment assumptions.

## QA-08 — Medium: initialization/debug helpers generate inconsistent or sensitive test state

**Evidence:** `data-init.ps1:504–525` sends uppercase SINGLE/RETURN/MONTHLY_PASS to the lowercase ticketing model. Unknown types receive neither configured expiry nor the intended multiple/pass ride allocation. Payments are generated independently with random amounts (`:551–566`), not the ticket's fare. The `CleanStart` switch is declared but never used. Repeated runs append trips/tickets/payments/notifications. Debug helpers use fixed account identifiers, print raw tokens, and some select the first trip without a supported route filter. `debug_cli_passenger_view.ps1:8` dot-sources a hardcoded different user's Windows path. `test-put-profile.ps1` changes the shared demo account rather than restoring it.

**Correction:** build deterministic, namespaced fixtures with cleanup and canonical contracts, make initialization idempotent or label it explicitly append-only, implement/remove CleanStart, and parameterize debug targets while redacting secrets. **Acceptance:** reruns have predictable counts, no unrelated user data is changed, and logs contain no usable tokens.

## QA-09 — Low: legacy source and repository policy gaps add maintenance noise

**Evidence:** production HTML loads student-management `storage.js`/`render.js` despite no matching student surface. `controller.js.old` is unreferenced and fails JavaScript syntax checking. Services duplicate configuration/CRUD/error handling and inconsistent open/closed records. There is no root ignore policy, editor/line-ending policy, documented security contact, threat model, dependency update policy, or contribution/build quality guide. `LICENSE` supplies an MIT license, but asset origin and release NOTICE obligations are not documented.

**Correction:** remove verified-unused code, preserve history through Git, consolidate shared contracts/configuration carefully, and add minimal documented repository/security/release conventions. **Acceptance:** production loading has no unused student/testing modules, no invalid backup source is mistaken for active code, and contributors have one reproducible build/test path.

## Positive evidence

- Dedicated CRUD scripts exist for every service and Bash alternatives exist for passenger/admin/notification testing.
- All 18 PowerShell scripts parse, and all five Bash scripts pass `bash -n`.
- All 19 active JavaScript files pass `node --check`; the lone syntax failure is an unloaded `.old` backup.
- The code uses structured payload records and includes ownership predicates in passenger operations, useful foundations for contract and negative tests.
- No destructive CRUD/seed script was run against the user's services or database during the audit.
