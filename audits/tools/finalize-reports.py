"""Generate audit coverage and finding indexes from recorded evidence."""
from pathlib import Path
import collections
import csv
import json
import os
import re

root = Path(__file__).resolve().parents[2]
audit = root / 'audits'
data = json.loads((audit/'evidence/repository-checks.json').read_text(encoding='utf-8'))

def review_for(name):
    p=Path(name)
    if name.endswith('/main.bal'):
        details={
            'passenger_service':'SEC-02,04,05,07,08,10; DATA-01,04,09,12',
            'transport_service':'SEC-01,07; DATA-08–10,12; UI-02; OPS-04,06',
            'ticketing_service':'SEC-01–03,07; DATA-01,03–05,07,09,12',
            'payment_service':'SEC-01,03,07; DATA-04,06,07,12; OPS-06',
            'notification_service':'SEC-01,08; DATA-08,11,12',
            'admin_service':'SEC-01,04,07; DATA-04,07,08,12; UI-09; OPS-06'}
        return 'Resource, model, validation, query, auth and event review; build on copy', details[p.parts[0]]
    if p.name=='Dependencies.toml': return 'TOML parse; package inventory; build/resolution comparison', 'OPS-02,08; exact artifact scan open'
    if p.name=='Ballerina.toml': return 'TOML parse; toolchain/observability consistency', 'OPS-02,06'
    if p.name=='Config.toml': return 'TOML parse; runtime-variable and Compose comparison', 'OPS-04; SEC-06'
    if p.name=='Dockerfile': return 'Build-input, port, runtime and hardening review', 'OPS-02,03,07'
    if p.name=='.devcontainer.json': return 'JSON parse; runtime pin consistency', 'OPS-02; no separate defect'
    if p.name=='.gitignore': return 'Generated artifact/config policy review', 'QA-09; no secret-ignore rule'
    if name=='docker-compose.yml': return 'Compose config validation; topology, configuration and failure review', 'SEC-06; OPS-01–07'
    if name=='init-mongo.js': return 'JS syntax; seed/index/schema/credential review', 'SEC-04; DATA-02,12'
    if name=='LICENSE': return 'License text review', 'MIT present; provenance/transitive assurance open'
    if p.suffix=='.md': return 'Setup, API and workflow claim cross-check', 'QA-07'
    if name=='ui/index.html': return 'Markup/script-order/label review; Chromium render and interaction probes', 'UI-01,02,05–09'
    if p.suffix=='.css':
        return 'Whole-file token/import scan; browser stylesheet load; selected visual/state inspection', 'UI-06,07,10,11 as applicable; not every state measured'
    if p.suffix=='.svg': return 'XML parse; script/foreignObject/event-handler check; references inventoried', 'No active-content match; artwork provenance not verified'
    if p.suffix=='.gif': return 'Binary signature/dimensions/hash; reference review', '600×600, 33,770 bytes; dormant legacy image; provenance open'
    if name.endswith('.js.old'): return 'Reference, content and syntax check', 'QA-09; invalid unloaded backup'
    if p.suffix=='.js':
        refs={
            'api.js':'SEC-09,10; UI-01–04,09,10',
            'admin.js':'SEC-09; UI-02,09,10',
            'controller.js':'SEC-09; UI-02,05,08,09',
            'masonry.js':'UI-10,11; repeated layout/resize work',
            'menu.js':'UI-01,04,08',
            'notification.js':'SEC-09; UI-02,09',
            'payment.js':'SEC-09; UI-02,09',
            'permissions.js':'UI-04,08',
            'render.js':'QA-09; legacy students',
            'route-browser.js':'UI-01,05,06,10',
            'search.js':'SEC-09; UI-03,06,10',
            'security.js':'SEC-07,08,10; browser-only controls',
            'storage.js':'QA-09; legacy students',
            'testing.js':'QA-01; UI-11; session-dependent tests',
            'theme.js':'UI-06; selector/token integration',
            'ticketing.js':'SEC-09; UI-02,09',
            'transport.js':'SEC-09; UI-02',
            'utils.js':'Shared escaping/URL helpers present; retain safe patterns'}
        return 'JS syntax; module API/DOM/dataflow review; browser load', refs.get(p.name,'No separate defect')
    if p.suffix=='.ps1':
        if p.name=='admin-cli.ps1': refs='QA-04,06'
        elif p.name=='passenger-cli.ps1':refs='QA-05,06'
        elif p.name=='urban-ticketing-cli.ps1':refs='QA-04–06'
        elif p.name=='data-init.ps1':refs='QA-06,08; DATA-01'
        elif p.name.startswith('test-') and p.name!='test-put-profile.ps1':refs='QA-01,02,06; live CRUD not executed'
        else:refs='QA-08; credential/log/mutation/portability review'
        return 'PowerShell parser; request/response, failure and side-effect review',refs
    if p.suffix=='.sh':return 'bash -n; request/auth/session/error review',('QA-03–06' if 'cli' in name else 'QA-01–03,06')
    if p.suffix=='.json':return 'JSON parse; fixture credential/schema review','SEC-04; QA-08'
    return 'Inventory and reference review','See domain reports'

lines=['# File coverage ledger','','Baseline `7d56d4e`: **142 / 142 tracked files included**, 951,079 bytes. This is a review/inventory ledger, not a statement that every line or runtime state has a proven passing test. Findings are grouped by root cause rather than repeated once per file. Full SHA-256 hashes, sizes and parse results are in [repository evidence](evidence/repository-checks.json).','','All source/configuration files were included in static checks and domain review. Styles/assets have the narrower methods below; visual art ownership and every possible style/state combination are not verified. The audit does not read private files outside the project as project content. Git internals were limited to baseline/history metadata and a narrow secret triage.','','| File | Bytes | Review method | Findings / disposition |','|---|---:|---|---|']
for record in data['files']:
    name=record['path'];method,refs=review_for(name)
    lines.append(f"| [{name}](../{name}) | {record['bytes']:,} | {method} | {refs} |")
lines += ['','## Repository-wide and historical scope','','- No baseline untracked project content was present; only the new `audits/` tree was added. Generated `.git/` implementation data and compiler caches are not application source.','- 29 local commits and 154 text blob versions were checked with four secret-pattern families; the known JWT key appears in two blob versions. No other match under those patterns is a clean-history guarantee.','- CI, security policy, migrations, backup/restore, release artifact scans, deployment ingress, and supported setup instructions were assessed as repository-level gaps.','- The audit files, synthetic fixtures, scripts, screenshots and logs created during this task are new review artifacts, excluded from the 142-file baseline count.']
(audit/'08-FILE-COVERAGE.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

findings=[]
for p in sorted(audit.glob('0[1-5]-*.md')):
    for match in re.finditer(r'^## ((?:SEC|DATA|UI|OPS|QA)-\d+) — (Critical|High|Medium|Low)(?: / (P\d))?: (.+)$',p.read_text(encoding='utf-8'),re.M):
        findings.append(dict(id=match[1],severity=match[2],uiPriority=match[3],title=match[4],report=p.name))
counts=collections.Counter(f['severity'] for f in findings)
(audit/'evidence/findings.json').write_text(json.dumps({'counts':dict(counts),'findings':findings},indent=2),encoding='utf-8')
index=['# Findings register','',f"**{len(findings)} grouped findings:** "+', '.join(f'{counts[s]} {s.lower()}' for s in ['Critical','High','Medium','Low'])+'. Severity reflects potential impact in the supplied design; source findings and conditional dependency matches are not all reproduced exploits. See each report for confidence and verification limits.','','| ID | Severity | Finding | Report |','|---|---|---|---|']
for f in sorted(findings,key=lambda f:(['Critical','High','Medium','Low'].index(f['severity']),f['id'])):
    priority=f" / {f['uiPriority']}" if f['uiPriority'] else ''
    index.append(f"| {f['id']} | {f['severity']}{priority} | {f['title']} | [{f['report']}]({f['report']}) |")
(audit/'00-FINDINGS.md').write_text('\n'.join(index)+'\n',encoding='utf-8')
print(json.dumps({'findings':len(findings),'severity':dict(counts),'coverageRows':len(data['files'])},indent=2))
