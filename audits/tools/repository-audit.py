"""Read-only baseline checks and inventories. Run from the repository root."""
import collections
import hashlib
import json
import pathlib
import re
import struct
import subprocess
import tomllib
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'audits' / 'evidence'
OUT.mkdir(exist_ok=True)
files = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', '7d56d4e'], cwd=ROOT, text=True).splitlines()
records, checks, endpoints, packages = [], [], [], {}
for name in files:
    p = ROOT / name
    # The audit is a historical snapshot; helpers can be moved or deleted later.
    raw = subprocess.check_output(['git', 'cat-file', '--filters', f'7d56d4e:{name}'], cwd=ROOT)
    suffix = p.suffix.lower()
    record = dict(path=name, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
    if suffix != '.gif':
        text = raw.decode('utf-8-sig')
        record['lines'] = len(text.splitlines())
        if suffix in ('.json', '.toml', '.svg'):
            try:
                if suffix == '.json': json.loads(text)
                elif suffix == '.toml':
                    obj = tomllib.loads(text)
                    if p.name == 'Dependencies.toml':
                        for pkg in obj.get('package', []):
                            packages.setdefault(f"{pkg['org']}/{pkg['name']}:{pkg['version']}", []).append(name.split('/')[0])
                else:
                    doc = ET.fromstring(text)
                    record['activeSvgContent'] = any(e.tag.split('}')[-1] in ('script', 'foreignObject') or any(k.lower().startswith('on') for k in e.attrib) for e in doc.iter())
                checks.append(dict(path=name, check='parse', passed=True))
            except Exception as e: checks.append(dict(path=name, check='parse', passed=False, error=str(e)))
        if suffix == '.js' or name.endswith('.js.old'):
            probe = subprocess.run(['node', '--check', '--input-type=commonjs'], input=text, text=True, encoding='utf-8', capture_output=True, timeout=20)
            checks.append(dict(path=name, check='JavaScript syntax', passed=probe.returncode == 0, error=probe.stderr.strip()))
        if suffix == '.bal':
            base = re.search(r'service\s+(/[^\s]+)\s+on', text).group(1)
            for i,line in enumerate(text.splitlines(),1):
                m = re.search(r'resource function\s+(\w+)\s+([^\(]+)\(', line)
                if m:
                    resource = re.sub(r'\[string (\w+)\]', r'{\1}', m[2].strip()).replace('\\-', '-').replace("'", '')
                    endpoints.append(dict(service=name.split('/')[0], method=m[1].upper(), path=base+'/'+resource, line=i, passengerJwt='authorization' in line))
    else:
        record['gifDimensions'] = list(struct.unpack('<HH',raw[6:10]))
    records.append(record)
result = dict(baseline='7d56d4e', fileCount=len(files), bytes=sum(x['bytes'] for x in records), extensions=dict(collections.Counter(pathlib.Path(n).suffix or '(none)' for n in files)), files=records, checks=checks, endpoints=endpoints, dependencies=packages)
(OUT/'repository-checks.json').write_text(json.dumps(result,indent=2), encoding='utf-8')
lines = ['# HTTP API inventory', '', 'Extracted from all six service source files at baseline `7d56d4e`. Auth below describes code in this repository; it does not assert a deployed gateway exists. Public route discovery and health may intentionally be public. Other missing protection is SEC-01.', '', '| Method | Resource | Source | Explicit passenger JWT validation |', '|---|---|---|---|']
for e in endpoints:
    source = f"{e['service']}/main.bal"
    lines.append(f"| {e['method']} | `{e['path']}` | [{source}:{e['line']}](../{source}#L{e['line']}) | {'Yes' if e['passengerJwt'] else 'No'} |")
lines += ['', f"Total: **{len(endpoints)} resources**. This inventory is static; no endpoints were exercised against a live database.", '', '## Event boundaries', '', '| Topic | Producer | Consumer | Contract concerns |', '|---|---|---|---|', '| `ticket.requests` | No active producer in service source | Ticketing | Duplicate delivery creates a new ticket; different path from passenger purchase |', '| `payments.processed` | Payment | Ticketing, notification | Ticketing uses `kafka:DEFAULT_URL`; no payment reconciliation or event deduplication |', '| `ticket.validations` | Ticketing | Notification | Write/publish is not atomic; duplicate delivery creates duplicate notices |', '| `schedule.updates` | Transport, admin | Notification | Admin status/deletion events omit fields required by the consumer |']
(ROOT/'audits'/'07-API-INVENTORY.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({ 'files':len(records), 'bytes':result['bytes'], 'checks':len(checks), 'failedChecks':[c for c in checks if not c['passed']], 'endpoints':len(endpoints), 'explicitJwtResources':sum(e['passengerJwt'] for e in endpoints), 'uniqueDependencyVersions':len(packages), 'gif':[r for r in records if 'gifDimensions' in r]},indent=2))
