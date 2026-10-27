"""Loopback-only helper boundary tests; real application checks are in test_application.py."""
import json
from pathlib import Path
import shutil
import subprocess
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
PWSH = shutil.which('pwsh')


class FakeApi(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self): self.dispatch()
    def do_POST(self): self.dispatch()

    def dispatch(self):
        self.server.calls.append((self.command, self.path, self.headers.get('Authorization')))
        status = 503 if self.server.fail else 200
        body = {'error': {'message': 'PRIVATE_VALUE_MUST_NOT_APPEAR'}} if self.server.fail else {'status': 'ready'}
        if not self.server.fail and self.path.endswith('/inspect'):
            body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        elif not self.server.fail and '/routes' in self.path:
            body = {'items': [], 'limit': 20, 'offset': 0, 'total': 0}
        elif not self.server.fail and '/trips' in self.path:
            body = {'items': [{'id': 'one'}], 'limit': 20, 'offset': 0, 'total': 1}
        elif not self.server.fail and '/accounts' in self.path:
            body = {'items': [{'id': 'one', 'email': 'fixture@example.test'}], 'limit': 100, 'offset': 0, 'total': 1}
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(body, ensure_ascii=False).encode())


@unittest.skipUnless(PWSH, 'PowerShell 7 is required')
class HelperTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), FakeApi)
        self.server.fail = False
        self.server.calls = []
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.origin = f'http://127.0.0.1:{self.server.server_port}'
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    def run_helper(self, *args, stdin=None):
        return subprocess.run([PWSH, '-NoProfile', '-File', 'uth.ps1', *args], cwd=ROOT,
                              input=stdin, capture_output=True, text=True, encoding='utf-8', timeout=40)

    def test_health_checks_all_services(self):
        result = self.run_helper('health', '-BaseUrl', self.origin)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.server.calls), 6)

    def test_health_failure_propagates_without_response_body(self):
        self.server.fail = True
        result = self.run_helper('health', '-BaseUrl', self.origin)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('PRIVATE_VALUE', result.stdout + result.stderr)

    def test_service_selection(self):
        result = self.run_helper('health', '-Service', 'payment', '-BaseUrl', self.origin)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[1] for c in self.server.calls], ['/api/v1/payment/health'])

    def test_smoke_is_read_only(self):
        result = self.run_helper('test', '-BaseUrl', self.origin)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(call[0] == 'GET' for call in self.server.calls))

    def test_cli_can_exit(self):
        result = self.run_helper('cli', '-BaseUrl', self.origin, stdin='0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.server.calls)

    def test_rejects_invalid_origin(self):
        result = self.run_helper('health', '-BaseUrl', 'http://user:secret@localhost/path')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.server.calls)

    def test_utf8_json_and_bearer_header(self):
        script = r"""Import-Module ./scripts/lib/Common.psm1 -DisableNameChecking
$ctx=New-UthContext -BaseUrl $args[0]
$body='{"name":"Jaden\u2019s \u201cticket\u201d \u2014 Windhoek"}' | ConvertFrom-Json -AsHashtable
$result=Invoke-UthRequest -Context $ctx -Service passenger -Path /inspect -Method POST -Token 'sample-token' -Body $body
$result.Data | ConvertTo-Json -Compress
"""
        result = subprocess.run([PWSH, '-NoProfile', '-CommandWithArgs', script, self.origin], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Jaden’s', result.stdout)
        self.assertEqual(self.server.calls[0][2], 'Bearer sample-token')

    def test_paginated_items_remain_dictionaries(self):
        script = """Import-Module ./scripts/lib/Common.psm1 -DisableNameChecking
$ctx=New-UthContext -BaseUrl $args[0]
$items=@(Get-UthItems -Context $ctx -Service admin -Path /accounts)
if($items.Count -ne 1 -or $items[0] -isnot [Collections.IDictionary] -or $items[0]['email'] -ne 'fixture@example.test') { throw 'Pagination changed the item shape.' }
"""
        result = subprocess.run([PWSH, '-NoProfile', '-CommandWithArgs', script, self.origin], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__': unittest.main()
