# File coverage ledger

Baseline `7d56d4e`: **142 / 142 tracked files included**, 951,079 bytes. This is a review/inventory ledger, not a statement that every line or runtime state has a proven passing test. Findings are grouped by root cause rather than repeated once per file. Full SHA-256 hashes, sizes and parse results are in [repository evidence](evidence/repository-checks.json).

All source/configuration files were included in static checks and domain review. Styles/assets have the narrower methods below; visual art ownership and every possible style/state combination are not verified. The audit does not read private files outside the project as project content. Git internals were limited to baseline/history metadata and a narrow secret triage.

| File | Bytes | Review method | Findings / disposition |
|---|---:|---|---|
| [ADMIN-API-TESTS.md](../ADMIN-API-TESTS.md) | 4,045 | Setup, API and workflow claim cross-check | QA-07 |
| [LICENSE](../LICENSE) | 1,082 | License text review | MIT present; provenance/transitive assurance open |
| [NOTIFICATION-API-TESTS.md](../NOTIFICATION-API-TESTS.md) | 4,164 | Setup, API and workflow claim cross-check | QA-07 |
| [README.md](../README.md) | 26,120 | Setup, API and workflow claim cross-check | QA-07 |
| [admin-cli.ps1](../admin-cli.ps1) | 20,829 | PowerShell parser; request/response, failure and side-effect review | QA-04,06 |
| [admin-cli.sh](../admin-cli.sh) | 6,750 | bash -n; request/auth/session/error review | QA-03–06 |
| [admin_service/.devcontainer.json](../admin_service/.devcontainer.json) | 157 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [admin_service/.gitignore](../admin_service/.gitignore) | 479 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [admin_service/Ballerina.toml](../admin_service/Ballerina.toml) | 147 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [admin_service/Config.toml](../admin_service/Config.toml) | 184 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [admin_service/Dependencies.toml](../admin_service/Dependencies.toml) | 9,143 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [admin_service/Dockerfile](../admin_service/Dockerfile) | 434 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [admin_service/main.bal](../admin_service/main.bal) | 30,477 | Resource, model, validation, query, auth and event review; build on copy | SEC-01,04,07; DATA-04,07,08,12; UI-09; OPS-06 |
| [admin_service/test_admin.json](../admin_service/test_admin.json) | 106 | JSON parse; fixture credential/schema review | SEC-04; QA-08 |
| [attempt_buy_direct.ps1](../attempt_buy_direct.ps1) | 1,406 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [data-init.ps1](../data-init.ps1) | 31,671 | PowerShell parser; request/response, failure and side-effect review | QA-06,08; DATA-01 |
| [debug_cli_passenger_view.ps1](../debug_cli_passenger_view.ps1) | 616 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [debug_passenger_flow.ps1](../debug_passenger_flow.ps1) | 1,388 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [docker-compose.yml](../docker-compose.yml) | 4,511 | Compose config validation; topology, configuration and failure review | SEC-06; OPS-01–07 |
| [init-mongo.js](../init-mongo.js) | 7,866 | JS syntax; seed/index/schema/credential review | SEC-04; DATA-02,12 |
| [notification_service/.devcontainer.json](../notification_service/.devcontainer.json) | 157 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [notification_service/.gitignore](../notification_service/.gitignore) | 479 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [notification_service/Ballerina.toml](../notification_service/Ballerina.toml) | 154 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [notification_service/Config.toml](../notification_service/Config.toml) | 191 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [notification_service/Dependencies.toml](../notification_service/Dependencies.toml) | 9,277 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [notification_service/Dockerfile](../notification_service/Dockerfile) | 441 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [notification_service/main.bal](../notification_service/main.bal) | 19,788 | Resource, model, validation, query, auth and event review; build on copy | SEC-01,08; DATA-08,11,12 |
| [passenger-cli.ps1](../passenger-cli.ps1) | 17,911 | PowerShell parser; request/response, failure and side-effect review | QA-05,06 |
| [passenger-cli.sh](../passenger-cli.sh) | 5,349 | bash -n; request/auth/session/error review | QA-03–06 |
| [passenger_service/.devcontainer.json](../passenger_service/.devcontainer.json) | 157 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [passenger_service/.gitignore](../passenger_service/.gitignore) | 479 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [passenger_service/Ballerina.toml](../passenger_service/Ballerina.toml) | 151 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [passenger_service/Config.toml](../passenger_service/Config.toml) | 150 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [passenger_service/Dependencies.toml](../passenger_service/Dependencies.toml) | 8,286 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [passenger_service/Dockerfile](../passenger_service/Dockerfile) | 438 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [passenger_service/main.bal](../passenger_service/main.bal) | 35,984 | Resource, model, validation, query, auth and event review; build on copy | SEC-02,04,05,07,08,10; DATA-01,04,09,12 |
| [payment_service/.devcontainer.json](../payment_service/.devcontainer.json) | 157 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [payment_service/.gitignore](../payment_service/.gitignore) | 479 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [payment_service/Ballerina.toml](../payment_service/Ballerina.toml) | 149 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [payment_service/Config.toml](../payment_service/Config.toml) | 186 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [payment_service/Dependencies.toml](../payment_service/Dependencies.toml) | 9,594 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [payment_service/Dockerfile](../payment_service/Dockerfile) | 436 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [payment_service/main.bal](../payment_service/main.bal) | 12,596 | Resource, model, validation, query, auth and event review; build on copy | SEC-01,03,07; DATA-04,06,07,12; OPS-06 |
| [register-test-user.ps1](../register-test-user.ps1) | 802 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [run_buy_ticket_noninteractive.ps1](../run_buy_ticket_noninteractive.ps1) | 4,498 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [run_debug_inspect.ps1](../run_debug_inspect.ps1) | 3,119 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [test-admin-apis.ps1](../test-admin-apis.ps1) | 9,287 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-admin-apis.sh](../test-admin-apis.sh) | 7,069 | bash -n; request/auth/session/error review | QA-01–03,06 |
| [test-apis.ps1](../test-apis.ps1) | 11,056 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-notification-apis.ps1](../test-notification-apis.ps1) | 6,424 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-notification-apis.sh](../test-notification-apis.sh) | 5,021 | bash -n; request/auth/session/error review | QA-01–03,06 |
| [test-passenger-apis.ps1](../test-passenger-apis.ps1) | 7,752 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-passenger-apis.sh](../test-passenger-apis.sh) | 6,057 | bash -n; request/auth/session/error review | QA-01–03,06 |
| [test-payment-apis.ps1](../test-payment-apis.ps1) | 4,005 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-put-profile.ps1](../test-put-profile.ps1) | 1,314 | PowerShell parser; request/response, failure and side-effect review | QA-08; credential/log/mutation/portability review |
| [test-ticketing-apis.ps1](../test-ticketing-apis.ps1) | 3,297 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [test-transport-apis.ps1](../test-transport-apis.ps1) | 6,090 | PowerShell parser; request/response, failure and side-effect review | QA-01,02,06; live CRUD not executed |
| [ticketing_service/.devcontainer.json](../ticketing_service/.devcontainer.json) | 155 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [ticketing_service/.gitignore](../ticketing_service/.gitignore) | 479 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [ticketing_service/Ballerina.toml](../ticketing_service/Ballerina.toml) | 151 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [ticketing_service/Config.toml](../ticketing_service/Config.toml) | 188 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [ticketing_service/Dependencies.toml](../ticketing_service/Dependencies.toml) | 9,155 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [ticketing_service/Dockerfile](../ticketing_service/Dockerfile) | 438 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [ticketing_service/main.bal](../ticketing_service/main.bal) | 15,027 | Resource, model, validation, query, auth and event review; build on copy | SEC-01–03,07; DATA-01,03–05,07,09,12 |
| [transport_service/.devcontainer.json](../transport_service/.devcontainer.json) | 157 | JSON parse; runtime pin consistency | OPS-02; no separate defect |
| [transport_service/.gitignore](../transport_service/.gitignore) | 481 | Generated artifact/config policy review | QA-09; no secret-ignore rule |
| [transport_service/Ballerina.toml](../transport_service/Ballerina.toml) | 151 | TOML parse; toolchain/observability consistency | OPS-02,06 |
| [transport_service/Config.toml](../transport_service/Config.toml) | 190 | TOML parse; runtime-variable and Compose comparison | OPS-04; SEC-06 |
| [transport_service/Dependencies.toml](../transport_service/Dependencies.toml) | 9,155 | TOML parse; package inventory; build/resolution comparison | OPS-02,08; exact artifact scan open |
| [transport_service/Dockerfile](../transport_service/Dockerfile) | 438 | Build-input, port, runtime and hardening review | OPS-02,03,07 |
| [transport_service/main.bal](../transport_service/main.bal) | 28,438 | Resource, model, validation, query, auth and event review; build on copy | SEC-01,07; DATA-08–10,12; UI-02; OPS-04,06 |
| [ui/gif/dogrunning.gif](../ui/gif/dogrunning.gif) | 33,770 | Binary signature/dimensions/hash; reference review | 600×600, 33,770 bytes; dormant legacy image; provenance open |
| [ui/icons/bell.svg](../ui/icons/bell.svg) | 306 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/bus.svg](../ui/icons/bus.svg) | 521 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/check.svg](../ui/icons/check.svg) | 311 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/chevron-bottom.svg](../ui/icons/chevron-bottom.svg) | 311 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/clear.svg](../ui/icons/clear.svg) | 379 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/credit-card.svg](../ui/icons/credit-card.svg) | 280 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/delete-profile.svg](../ui/icons/delete-profile.svg) | 586 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/edit-profile.svg](../ui/icons/edit-profile.svg) | 632 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/error.svg](../ui/icons/error.svg) | 607 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/externallink.svg](../ui/icons/externallink.svg) | 369 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/favicon.svg](../ui/icons/favicon.svg) | 2,465 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/info.svg](../ui/icons/info.svg) | 1,887 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/loading-spinner.svg](../ui/icons/loading-spinner.svg) | 507 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/logo.svg](../ui/icons/logo.svg) | 2,371 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/menu.svg](../ui/icons/menu.svg) | 333 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/moon.svg](../ui/icons/moon.svg) | 13,777 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/remove-profile.svg](../ui/icons/remove-profile.svg) | 451 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/search.svg](../ui/icons/search.svg) | 459 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/settings.svg](../ui/icons/settings.svg) | 1,132 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/sun.svg](../ui/icons/sun.svg) | 1,747 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/ticket.svg](../ui/icons/ticket.svg) | 403 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/trash.svg](../ui/icons/trash.svg) | 877 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/user.svg](../ui/icons/user.svg) | 296 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/icons/warning.svg](../ui/icons/warning.svg) | 1,399 | XML parse; script/foreignObject/event-handler check; references inventoried | No active-content match; artwork provenance not verified |
| [ui/index.html](../ui/index.html) | 53,322 | Markup/script-order/label review; Chromium render and interaction probes | UI-01,02,05–09 |
| [ui/scripts/modules/admin.js](../ui/scripts/modules/admin.js) | 34,789 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02,09,10 |
| [ui/scripts/modules/api.js](../ui/scripts/modules/api.js) | 38,979 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09,10; UI-01–04,09,10 |
| [ui/scripts/modules/controller.js](../ui/scripts/modules/controller.js) | 15,850 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02,05,08,09 |
| [ui/scripts/modules/controller.js.old](../ui/scripts/modules/controller.js.old) | 19,392 | Reference, content and syntax check | QA-09; invalid unloaded backup |
| [ui/scripts/modules/masonry.js](../ui/scripts/modules/masonry.js) | 7,797 | JS syntax; module API/DOM/dataflow review; browser load | UI-10,11; repeated layout/resize work |
| [ui/scripts/modules/menu.js](../ui/scripts/modules/menu.js) | 9,038 | JS syntax; module API/DOM/dataflow review; browser load | UI-01,04,08 |
| [ui/scripts/modules/notification.js](../ui/scripts/modules/notification.js) | 23,966 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02,09 |
| [ui/scripts/modules/payment.js](../ui/scripts/modules/payment.js) | 22,586 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02,09 |
| [ui/scripts/modules/permissions.js](../ui/scripts/modules/permissions.js) | 8,916 | JS syntax; module API/DOM/dataflow review; browser load | UI-04,08 |
| [ui/scripts/modules/render.js](../ui/scripts/modules/render.js) | 3,990 | JS syntax; module API/DOM/dataflow review; browser load | QA-09; legacy students |
| [ui/scripts/modules/route-browser.js](../ui/scripts/modules/route-browser.js) | 19,367 | JS syntax; module API/DOM/dataflow review; browser load | UI-01,05,06,10 |
| [ui/scripts/modules/search.js](../ui/scripts/modules/search.js) | 19,178 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-03,06,10 |
| [ui/scripts/modules/security.js](../ui/scripts/modules/security.js) | 14,756 | JS syntax; module API/DOM/dataflow review; browser load | SEC-07,08,10; browser-only controls |
| [ui/scripts/modules/storage.js](../ui/scripts/modules/storage.js) | 882 | JS syntax; module API/DOM/dataflow review; browser load | QA-09; legacy students |
| [ui/scripts/modules/testing.js](../ui/scripts/modules/testing.js) | 16,603 | JS syntax; module API/DOM/dataflow review; browser load | QA-01; UI-11; session-dependent tests |
| [ui/scripts/modules/theme.js](../ui/scripts/modules/theme.js) | 1,163 | JS syntax; module API/DOM/dataflow review; browser load | UI-06; selector/token integration |
| [ui/scripts/modules/ticketing.js](../ui/scripts/modules/ticketing.js) | 20,757 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02,09 |
| [ui/scripts/modules/transport.js](../ui/scripts/modules/transport.js) | 13,236 | JS syntax; module API/DOM/dataflow review; browser load | SEC-09; UI-02 |
| [ui/scripts/modules/utils.js](../ui/scripts/modules/utils.js) | 4,070 | JS syntax; module API/DOM/dataflow review; browser load | Shared escaping/URL helpers present; retain safe patterns |
| [ui/styles/base/global.css](../ui/styles/base/global.css) | 564 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/base/variables.css](../ui/styles/base/variables.css) | 1,053 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/admin.css](../ui/styles/components/admin.css) | 13,336 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/alerts.css](../ui/styles/components/alerts.css) | 298 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/buttons.css](../ui/styles/components/buttons.css) | 1,630 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/cards.css](../ui/styles/components/cards.css) | 3,278 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/custom-select.css](../ui/styles/components/custom-select.css) | 1,668 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/footer.css](../ui/styles/components/footer.css) | 570 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/forms.css](../ui/styles/components/forms.css) | 2,208 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/header.css](../ui/styles/components/header.css) | 3,154 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/menu.css](../ui/styles/components/menu.css) | 7,082 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/modal.css](../ui/styles/components/modal.css) | 11,006 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/route-browser.css](../ui/styles/components/route-browser.css) | 3,257 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/search-results.css](../ui/styles/components/search-results.css) | 7,746 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/search.css](../ui/styles/components/search.css) | 2,676 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/components/table.css](../ui/styles/components/table.css) | 2,181 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/layout/sections.css](../ui/styles/layout/sections.css) | 6,461 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/linkstyles.css](../ui/styles/linkstyles.css) | 968 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/responsive.css](../ui/styles/responsive.css) | 1,679 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/themes/darkstyle.css](../ui/styles/themes/darkstyle.css) | 1,420 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/themes/lightstyle.css](../ui/styles/themes/lightstyle.css) | 3,002 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/utilities/a11y.css](../ui/styles/utilities/a11y.css) | 227 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/utilities/effects.css](../ui/styles/utilities/effects.css) | 422 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/utilities/icons.css](../ui/styles/utilities/icons.css) | 296 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [ui/styles/utilities/text.css](../ui/styles/utilities/text.css) | 95 | Whole-file token/import scan; browser stylesheet load; selected visual/state inspection | UI-06,07,10,11 as applicable; not every state measured |
| [urban-ticketing-cli.ps1](../urban-ticketing-cli.ps1) | 45,031 | PowerShell parser; request/response, failure and side-effect review | QA-04–06 |

## Repository-wide and historical scope

- No baseline untracked project content was present; only the new `audits/` tree was added. Generated `.git/` implementation data and compiler caches are not application source.
- 29 local commits and 154 text blob versions were checked with four secret-pattern families; the known JWT key appears in two blob versions. No other match under those patterns is a clean-history guarantee.
- CI, security policy, migrations, backup/restore, release artifact scans, deployment ingress, and supported setup instructions were assessed as repository-level gaps.
- The audit files, synthetic fixtures, scripts, screenshots and logs created during this task are new review artifacts, excluded from the 142-file baseline count.
