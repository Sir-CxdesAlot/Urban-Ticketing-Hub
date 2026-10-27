# Validation evidence and limitations

Date: 2026-10-27, Africa/Windhoek. Baseline: `7d56d4e`. Original tracked files were left unchanged. Added audit scripts/evidence live under `audits/`; service build artifacts were generated in temporary copies outside the repository.

## Checks actually executed

| Check | Result | Meaning / limit |
|---|---|---|
| Baseline inventory | 142 tracked files, 951,079 bytes | Every baseline file included in [coverage ledger](08-FILE-COVERAGE.md); binary art has metadata/structure coverage only |
| Static API extraction | 62 HTTP resources; 7 explicitly validate passenger JWT | Source inventory, not requests to live services |
| JavaScript syntax | 19/19 active `.js` files passed | `controller.js.old` fails syntax; not loaded by index |
| PowerShell parser | 18/18 scripts passed | Parsing does not validate HTTP contracts or runtime tool resolution |
| Bash syntax | 5/5 scripts passed `bash -n` using Git Bash | Does not validate curl/JSON/auth semantics |
| TOML / JSON / SVG parsing | All 18 TOML, 7 JSON, and 24 SVG files passed | SVGs have no script/foreignObject/event-handler attributes in the checked tree; provenance/rendering edge cases not certified |
| Compose configuration | `docker compose config --quiet` passed | Structural validation only; not container startup |
| Locked build on installed runtime | Six sticky builds failed dependency loading | Installed 2201.13.5 versus project 2201.12.10; not a source compile-failure finding |
| Soft build on installed runtime | Six JARs generated | `--offline --locking-mode=soft` on copies changed resolution; does not validate the locked Docker release |
| Exact runtime installation | `bal dist pull 2201.12.10` refused write access to Program Files | No toolchain settings were changed; exact-runtime build remains unverified |
| Browser execution | No uncaught errors on initial guest page | Other views have known source-confirmed failures; no blanket no-errors claim |
| Startup routes | Zero initial service requests; loading never resolved | Explicit route-browser call then loaded one fixture; confirms initialization-order problem |
| Browser contract probes | Admin sent `email`; purchase used `/ticketing/purchase` | Fixtures modeled source contracts; their 400/404 outcomes are not live backend responses |
| Browser role probe | Guest and passenger passed `hasMinimumRole('OPERATOR')` | Undefined required role falls back to level 0 |
| HTML injection probes | Both transport API-result and trip-details markers executed | Local fixture/data-image markers; no external request/exfiltration or real stored database payload |
| Modal probe | Login retained header focus; no dialog metadata; Escape did not close | Reproduced actual UI behavior |
| Layout probes | 390px basic layout fits; 320px scroll width 370px | Login extends to roughly x=370px and clips; not all-view responsive conformance |
| Dark-theme probe | Action description computes black; dark badge selector does not match | Confirmed token/selector mismatch, corroborated by screenshots |
| API test fail injection | Every request failed; summary claimed success; exit 0 | Stubbed native cmdlet, no real HTTP calls |
| Bash eval probe | Both CLI helpers executed `AUDIT_EVAL_MARKER` | curl was stubbed; only printf ran |
| Dependency advisory lookup | 10 Maven coordinates from two locked connectors' vendor tags; 2 Kafka-client advisories | Partial source-metadata scan, not full release/container SCA |
| History secret triage | 29 local commits, 154 text blobs, known signing key in 2 blob versions | Four regex families only; not a comprehensive secret scan or historical semantic audit |
| Impeccable detector | Executed against HTML, JS, CSS | Warnings verified/contextualized; decorative patterns are not automatically defects |

## Build evidence

The installed runtime was Ballerina 2201.13.5; Node 24.18.0 and Python 3.14.6 were available. Each service was copied into a fresh temporary audit directory before building. Sticky logs contain dependency/BIR resolution errors; the wrapper reported exit 0 despite those messages, so the audit used diagnostics and artifact existence rather than trusting the wrapper exit alone.

Representative locked-build messages include `cannot resolve module ballerina/time:2.7.0` and `cannot resolve module ballerina/time:2.8.3`. After soft resolution, every service reached `Generating executable`. Five emitted transitive-dependency age warnings; passenger did not. Compiler hints identify non-isolated resource/listener methods, limiting request concurrency in the current implementation. This is meaningful performance evidence, but no throughput benchmark was run. Source methods should be made isolated only after shared-state safety and atomic business operations are established.

[Machine build results and complete logs](evidence/build-results.json) preserve toolchain, resolution mode, warnings, and artifact hashes. No lockfile in the user's project was rewritten.

## Browser evidence

The harness served `ui/` from a loopback-only temporary HTTP server and intercepted all localhost service traffic. It closed its server/browser afterward. Fixtures used synthetic identities and dates, no real credentials. Initial and explicitly loaded route states were captured in two inspection rounds:

- [Desktop, initial dark](evidence/desktop-dark.png)
- [Mobile, initial light](evidence/mobile-light.png)
- [Desktop, route fixture loaded](evidence/desktop-dark-loaded.png)
- [Mobile, route fixture loaded](evidence/mobile-light-loaded.png)
- [Complete probes](evidence/browser-probes.json)

`browser-audit.cjs` can reproduce both initial and loaded states; rerunning it overwrites the evidence files. Synthetic tests prove frontend behavior and contract mismatches, not successful real service integration.

## Reproduction commands

Run from the repository root; use the installed Playwright module path for the last command.

```powershell
python audits/tools/repository-audit.py
docker compose config --quiet
pwsh -NoProfile -File audits/tools/test-script-probe.ps1
& 'C:/Program Files/Git/bin/bash.exe' audits/tools/shell-probe.sh admin-cli.sh
& 'C:/Program Files/Git/bin/bash.exe' audits/tools/shell-probe.sh passenger-cli.sh
node audits/tools/browser-audit.cjs '<absolute path to playwright package>'
```

To reproduce builds, copy each service into a fresh disposable directory, run `bal build --offline --sticky`, then use another copy with `bal build --offline --locking-mode=soft` for the explicitly different newer-runtime check. The pinned 2201.12.10 toolchain and exact release images must still be tested independently.

## Important unverified areas

Docker's Linux engine was unavailable (`dockerDesktopLinuxEngine` pipe missing). Therefore fresh-volume Mongo initialization, real API integration, Kafka delivery/replay/offset behavior, migrations, capacity races, refund concurrency, crash recovery, restore tests, exact image contents/users, load/soak/fault testing, and TLS/network exposure were not executed. Source-confirmed defects in those areas remain findings, not passing tests.

Manual assistive-technology testing, all-view/zoom/browser coverage, a complete per-requirement ASVS Level 2 verification, external deployment/identity configuration, and complete transitive CVE/license/secret clearance remain open assurance work. These limitations are explicit so that the audit cannot be mistaken for a deployment certification.
