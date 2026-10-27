# Helper script consolidation

**Historical stage:** this document records the initial helper-only consolidation before the application repair. The current API, generated credentials, commands, and verification results are described in [README](../README.md), [scripts guide](../scripts/README.md), and [verification log](VERIFICATION.md). Later work adds one internal Operations module; there is still one public helper entrypoint. The original 16-test result below does not describe today's test harness.

Date: 2026-10-27. Scope: project CLI, seed, test, and debug helpers. Browser JavaScript and service implementations are unchanged.

## Decision

Use one PowerShell 7 entry point on all supported desktop/server operating systems. This fits the existing repository, where 18 of the 23 root helpers were already PowerShell, and avoids maintaining a second Bash HTTP/JSON/session implementation. Python is used only for the isolated helper regression harness; it is not required for normal CLI/seed/test/health commands.

The 23 root scripts have been replaced by `uth.ps1` plus four internal modules: Common, Cli, Seed, and Tests. That is **23 → 1 public entry points** and **23 → 5 helper implementation files**. There are no compatibility wrappers or archived copies in the working tree; Git retains the old versions. Fixture data is stored separately in JSON. One Python test file verifies the helper layer.

## Consolidated responsibilities

- One host/port configuration and UTF-8 JSON HTTP implementation replaces duplicated curl, Invoke-Expression, eval, status handling, and logging.
- One CLI contains the existing passenger and admin operations. Shared session/menu behavior replaces three overlapping PowerShell CLIs and two Bash CLIs. Actual server tokens remain in memory; IDs are not substituted for tokens.
- One seed command reuses matching demo records, uses valid service ticket types and matching payment amounts, and reports conflicts/failures.
- One test command selects the service and smoke/CRUD suite. Default smoke is read-only; CRUD fixtures are uniquely named and cleaned up in reverse order. Failures propagate to the process exit code.
- One-off registration, profile-update, purchase, and inspection scripts are covered by CLI operations or the shared scenarios.

Full commands and the old-to-new mapping are in [scripts/README.md](../scripts/README.md).

## Deliberate changes

PowerShell 7+ is now the one supported helper runtime; Windows PowerShell 5.1 and standalone Bash implementations are retired. HTTP failures are errors rather than arbitrary response bodies passed as success. Tokens/passwords are not printed by the shared request layer. The old fake admin bearer IDs, executable temp session files, unconditional green test summaries, and unused CleanStart option are removed.

Seed retains demo account/route definitions in `scripts/demo-data.json`, creates a date-relative trip window, and reuses matching ticket/payment/notification/disruption fixtures. Reruns on the same UTC day reuse the same window. This is not a destructive reset or a universal database migration tool.

The launcher defaults to help, has explicit memory-only passenger/admin menus, and exits correctly when Back/Exit is selected. Manual curl/API examples remain in README and the service test guides, with their helper commands updated.

## Validation

All **16 helper regression tests passed**, using PowerShell 7.6.5 and Python 3.14.6 on Windows. The harness runs a loopback fake API on an ephemeral port, covering all six CRUD workflows, reverse-order cleanup, injected request/cleanup failures, read-only smoke checks, HTTP JSON strings/arrays, quoting/Unicode, host routing, repeated/conflicting seeds, rejected admin login, payment success/failure, and menu exit behavior. It never uses the user's real API ports/database. All five PowerShell implementation files parsed; help, documentation references, historical probes, and Git whitespace checks were also checked. Linux/macOS execution was not exercised in this environment.

Live service integration remains subject to the backend issues and unavailable Docker engine recorded in the audit. Fake-API success establishes helper behavior, not that production service workflows or security findings are fixed. The [original audit](../audits/README.md) remains a historical snapshot at `7d56d4e`; its legacy helper probes now read that baseline from Git.

## Keep it small

Add new checks to Tests, user operations to Cli, transport/configuration to Common, and fixtures to the JSON file/Seed. Add a new module only for a distinct responsibility. New standalone scripts or shell-specific copies should not be the default for debugging another endpoint.
