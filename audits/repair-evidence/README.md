# Repair evidence — 2026-10-27

This directory records verification performed before the repair snapshot was committed on `the-ideal-version`. The parent audit reports describe historical baseline `7d56d4e` and are unchanged.

[verification-summary.json](verification-summary.json) contains sanitized test counts, exact scanned image IDs/timestamps, packaged lock comparisons, query-plan statistics, backup snapshot counts and finding dispositions. It contains no account credentials or session tokens. [VERIFICATION.md](../../docs/VERIFICATION.md) explains the checks, commands, mocked boundaries, failed-test corrections and unexecuted work. [REMEDIATION.md](../../docs/REMEDIATION.md) maps every original finding to implementation and evidence.

The 62-case total combines full runs with targeted additions; it does not claim a single full 33-case API/11-case browser rerun. Runtime scans use Trivy 0.76.1 at HIGH/CRITICAL, with no advisory suppressions. Zero reported matches are dated advisory evidence, not a security certification. The image IDs were compared with the actual local images after final container recreation.

Full generated reports/logs remain private and ignored under `.runtime/`; browser screenshots remain ignored under `test-results/`. Credentials and backups are deliberately excluded. Hosted CI has not run. The summary is a durable review record rather than a substitute for rerunning the documented commands after changes.
