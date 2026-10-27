"""Real MongoDB/Kafka application checks. Start and seed the demo before running.

Tests create uniquely named fixtures and deactivate/cancel/retire only those fixtures.
Clock-boundary tests change their own database records, never the machine clock.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
BASE = os.environ.get('UTH_TEST_BASE_URL', 'http://localhost:8080')
CONTRACT = json.loads((ROOT / 'docs/openapi.json').read_text())
VALIDATORS = {}


def validate_response(service, path, method, status, data):
    name = 'Error'
    if status == 200:
        full = '/api/v1/' + service + urllib.parse.urlsplit(path).path
        for template, methods in CONTRACT['paths'].items():
            expected, actual = template.split('/'), full.split('/')
            if len(expected) == len(actual) and all(a == b or a == '{id}' for a, b in zip(expected, actual)):
                name = methods[method.lower()]['responses']['200']['content']['application/json']['schema']['$ref'].rsplit('/', 1)[-1]
                break
        else: raise AssertionError('Successful response has no documented contract: ' + full)
    if name not in VALIDATORS:
        VALIDATORS[name] = Draft202012Validator({'$ref': '#/components/schemas/' + name,
            'components': CONTRACT['components']}, format_checker=FormatChecker())
    errors = list(VALIDATORS[name].iter_errors(data))
    if errors:
        # Do not include response values: login responses contain sensitive bearer tokens.
        raise AssertionError('Response violates ' + name + ' at ' + '/'.join(map(str, errors[0].path)))


def api(service, path, method='GET', body=None, token=''):
    headers = {'Accept': 'application/json'}
    if token: headers['Authorization'] = 'Bearer ' + token
    if body is not None: headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(BASE + '/api/v1/' + service + path,
        data=None if body is None else json.dumps(body).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as failure:
        with failure:
            try: data = json.load(failure)
            except ValueError: data = {}
            return failure.code, data


def mongo(script):
    command = ['docker', 'compose', 'exec', '-T', 'mongodb', 'sh', '-c',
        'mongosh --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --file /dev/stdin']
    result = subprocess.run(command, input='const d=db.getSiblingDB("uth_demo_v2");\n' + script,
                            text=True, encoding='utf-8', capture_output=True, cwd=ROOT, timeout=30)
    if result.returncode: raise AssertionError('Database fixture/query-plan operation failed.')
    return result.stdout.strip()


def instant(minutes=10):
    return (datetime.now(timezone.utc) + timedelta(minutes=minutes)).isoformat()


class ApplicationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (ROOT / '.env').exists(): raise unittest.SkipTest('Run uth.ps1 setup and start first.')
        cls.created_accounts, cls.created_routes, cls.created_trips, cls.created_tickets = [], [], [], []
        environment = dict(line.split('=', 1) for line in (ROOT / '.env').read_text(encoding='utf-8-sig').splitlines() if '=' in line and not line.startswith('#'))
        status, login = api('passenger', '/login', 'POST', {'email': environment['UTH_ADMIN_EMAIL'], 'password': environment['UTH_ADMIN_PASSWORD']})
        if status != 200: raise AssertionError(f'Administrator login failed: HTTP {status}.')
        cls.admin = login['token']
        cls.addClassCleanup(cls.cleanup_fixtures)
        cls.passenger = cls.new_account('PASSENGER')
        cls.other = cls.new_account('PASSENGER')
        cls.operator = cls.new_account('ROUTE_OPERATOR')
        cls.other_operator = cls.new_account('ROUTE_OPERATOR')
        cls.manager = cls.new_account('TRANSPORT_MANAGER')

    @classmethod
    def must(cls, service, path, method='GET', body=None, token='', expected=200):
        status, data = api(service, path, method, body, token)
        if status != expected:
            message = data.get('error', {}).get('message', 'Unexpected response')
            raise AssertionError(f'{method} {service}{path}: HTTP {status}; expected {expected}: {message}')
        validate_response(service, path, method, status, data)
        return data

    @classmethod
    def new_account(cls, role, password=None):
        password = password or secrets.token_hex(18)
        body = {'email': 'test-' + uuid.uuid4().hex + '@example.test', 'password': password,
                'firstName': 'Test', 'lastName': 'Fixture', 'phone': '+264810000000'}
        if role == 'PASSENGER': account = cls.must('passenger', '/register', 'POST', body)
        else: account = cls.must('admin', '/accounts', 'POST', {**body, 'role': role}, cls.admin)
        cls.created_accounts.append(account)
        login = cls.must('passenger', '/login', 'POST', {'email': body['email'], 'password': password})
        return {**account, 'token': login['token'], 'password': password}

    @classmethod
    def trip(cls, capacity=40, route=None, operator=None):
        if route is None:
            route = cls.must('transport', '/routes', 'POST', {'name': 'Test ' + uuid.uuid4().hex,
                'startLocation': 'A', 'endLocation': 'B', 'intermediateStops': [], 'transportType': 'BUS', 'baseFareMinor': 1250}, cls.admin)
            cls.created_routes.append(route)
        trip = cls.must('transport', '/trips', 'POST', {'routeId': route['id'], 'operatorId': (operator or cls.operator)['id'],
            'capacity': capacity, 'departureTime': instant(10), 'arrivalTime': instant(70)}, cls.admin)
        cls.created_trips.append(trip)
        return route, trip

    @classmethod
    def checkout(cls, trip, product='SINGLE', user=None, key=None):
        user = user or cls.passenger
        result = cls.must('ticketing', '/checkout', 'POST', {'tripId': trip['id'], 'ticketType': product,
            'requestKey': key or str(uuid.uuid4())}, user['token'])
        cls.created_tickets.append((result['ticket'], user))
        return result

    @classmethod
    def paid(cls, trip, product='SINGLE', user=None):
        user = user or cls.passenger
        result = cls.checkout(trip, product, user)
        cls.must('payment', '/payments', 'POST', {'ticketId': result['ticket']['id'], 'requestKey': str(uuid.uuid4())}, user['token'])
        return result

    @classmethod
    def cleanup_fixtures(cls):
        failures = []
        # Release only the IDs created by this run; failed cleanup is a failed test suite.
        for trip in reversed(cls.created_trips):
            status, _ = api('transport', '/trips/' + trip['id'] + '/cancel', 'POST', {}, cls.admin)
            if status != 200: failures.append('trip ' + trip['id'])
        for route in reversed(cls.created_routes):
            status, _ = api('transport', '/routes/' + route['id'], 'DELETE', token=cls.admin)
            if status != 200: failures.append('route ' + route['id'])
        for account in cls.created_accounts:
            status, _ = api('admin', '/accounts/' + account['id'], 'PUT', {'active': False}, cls.admin)
            if status != 200: failures.append('account ' + account['id'])
        if failures: raise AssertionError('Fixture cleanup failed: ' + ', '.join(failures))

    def test_security_authentication_and_roles(self):
        self.must('passenger', '/me', expected=401)
        self.must('admin', '/accounts', token=self.passenger['token'], expected=403)
        self.must('admin', '/accounts', token=self.manager['token'], expected=403)
        self.must('admin', '/reports', token=self.operator['token'], expected=403)
        self.must('admin', '/reports', token=self.manager['token'])
        self.must('notification', '/broadcasts', 'POST', {'message': 'Forbidden'}, self.passenger['token'], 403)

    def test_security_rejects_role_and_price_forgery(self):
        self.must('passenger', '/register', 'POST', {'email': 'bad@example.test', 'password': 'A long password!', 'role': 'SUPER_ADMIN'}, expected=400)
        _, trip = self.trip()
        for field in ['amountMinor', 'status', 'userId', 'usedRides', 'validUntil']:
            self.must('ticketing', '/checkout', 'POST', {'tripId': trip['id'], 'ticketType': 'SINGLE',
                'requestKey': str(uuid.uuid4()), field: 'forged'}, self.passenger['token'], 400)
        purchase = self.checkout(trip)
        self.must('payment', '/payments', 'POST', {'ticketId': purchase['ticket']['id'], 'requestKey': str(uuid.uuid4()), 'amountMinor': 1}, self.passenger['token'], 400)
        self.must('ticketing', '/tickets/' + purchase['ticket']['id'], 'PUT', {'status': 'ACTIVE'}, self.passenger['token'], 404)

    def test_security_cross_user_access(self):
        _, trip = self.trip()
        purchase = self.paid(trip)
        self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=self.other['token'], expected=403)
        self.must('ticketing', '/bookings/' + purchase['booking']['id'], token=self.other['token'], expected=403)
        self.must('payment', '/refunds', 'POST', {'ticketId': purchase['ticket']['id'], 'requestKey': str(uuid.uuid4())}, self.other['token'], 403)

    def test_profile_and_request_limits(self):
        user = self.new_account('PASSENGER')
        profile = self.must('passenger', '/me', 'PUT', {'firstName': 'Quoted “name”', 'phone': '+264810000001'}, user['token'])
        self.assertEqual(profile['firstName'], 'Quoted “name”')
        self.must('passenger', '/me', 'PUT', {'role': 'SUPER_ADMIN'}, user['token'], 400)
        self.must('passenger', '/register', 'POST', {'large': 'x' * 20000}, expected=413)

    def test_notification_receipts_are_per_recipient(self):
        queued = self.must('notification', '/broadcasts', 'POST', {'message': 'Integration announcement ' + uuid.uuid4().hex}, self.admin)
        deadline = time.time() + 30
        while time.time() < deadline:
            records = json.loads(mongo('print(JSON.stringify(d.notifications.find({eventId:' + json.dumps(queued['id']) + ',userId:{$in:' + json.dumps([self.passenger['id'], self.other['id']]) + '}},{_id:0}).toArray()));'))
            if len(records) == 2: break
            time.sleep(1)
        else: self.fail('Broadcast was not delivered independently to both passengers.')
        own = next(item for item in records if item['userId'] == self.passenger['id'])
        other = next(item for item in records if item['userId'] == self.other['id'])
        self.must('notification', '/notifications/' + own['id'] + '/read', 'POST', {}, self.passenger['token'])
        self.must('notification', '/notifications/' + other['id'] + '/read', 'POST', {}, self.passenger['token'], 403)
        self.assertFalse(json.loads(mongo('print(JSON.stringify(d.notifications.findOne({id:' + json.dumps(other['id']) + '},{_id:0})));'))['read'])
        self.must('notification', '/notifications/' + own['id'], 'DELETE', token=self.passenger['token'])

    def test_security_logout_deactivation_and_hashes(self):
        user = self.new_account('PASSENGER')
        profile = self.must('passenger', '/me', token=user['token'])
        self.assertFalse({'passwordHash', 'authVersion', 'sessionId'} & profile.keys())
        token_hash = hashlib.sha256(user['token'].encode()).hexdigest()
        stored = json.loads(mongo('print(JSON.stringify(d.sessions.findOne({userId:' + json.dumps(user['id']) + '},{_id:0,tokenHash:1})));'))
        self.assertEqual(stored['tokenHash'], token_hash)
        self.must('passenger', '/logout', 'POST', {}, user['token'])
        self.must('passenger', '/me', token=user['token'], expected=401)
        login = self.must('passenger', '/login', 'POST', {'email': user['email'], 'password': user['password']})
        self.must('passenger', '/me', 'DELETE', token=login['token'])
        self.must('passenger', '/me', token=login['token'], expected=401)

    def test_security_session_expiry(self):
        for field, age in [('lastSeen', 1801), ('createdAt', 28801)]:
            user = self.new_account('PASSENGER')
            mongo('d.sessions.updateMany({userId:' + json.dumps(user['id']) + '},{$set:{' + field + ':' + str(int(time.time()) - age) + '}});')
            self.must('passenger', '/me', token=user['token'], expected=401)

    def test_security_password_whitespace_is_preserved(self):
        user = self.new_account('PASSENGER', '  A password with spaces!  ')
        self.must('passenger', '/login', 'POST', {'email': user['email'], 'password': user['password'].strip()}, expected=401)
        self.must('passenger', '/me', token=user['token'])

    def test_security_role_change_revokes_existing_session(self):
        user = self.new_account('ROUTE_OPERATOR')
        self.must('admin', '/accounts/' + user['id'], 'PUT', {'role': 'TRANSPORT_MANAGER'}, self.admin)
        self.must('passenger', '/me', token=user['token'], expected=401)

    def test_search_covers_all_pages_and_escapes_query_values(self):
        route, _ = self.trip()
        query = urllib.parse.urlencode({'q': route['name']})
        page = self.must('transport', '/routes?' + query)
        self.assertEqual([item['id'] for item in page['items']], [route['id']])
        self.assertEqual(self.must('transport', '/routes?q=%24where')['items'], [])

    def test_security_login_rate_limit(self):
        email = 'rate-' + uuid.uuid4().hex + '@example.test'
        for _ in range(10): self.must('passenger', '/login', 'POST', {'email': email, 'password': 'Wrong password value'}, expected=401)
        self.must('passenger', '/login', 'POST', {'email': email, 'password': 'Wrong password value'}, expected=429)

    def test_products_and_server_prices(self):
        for product, amount, rides in [('SINGLE', 1250, 1), ('TEN_RIDE', 10000, 10), ('MONTHLY', 25000, -1)]:
            _, trip = self.trip()
            ticket = self.checkout(trip, product)['ticket']
            self.assertEqual((ticket['amountMinor'], ticket['totalRides']), (amount, rides))
            self.assertIsInstance(ticket['amountMinor'], int)

    def test_concurrency_last_seat(self):
        _, trip = self.trip(capacity=1)
        def attempt(user):
            return api('ticketing', '/checkout', 'POST', {'tripId': trip['id'], 'ticketType': 'SINGLE', 'requestKey': str(uuid.uuid4())}, user['token'])
        with ThreadPoolExecutor(max_workers=8) as pool:
            responses = list(pool.map(attempt, [self.passenger, self.other] * 4))
        self.assertEqual(sum(status == 200 for status, _ in responses), 1)
        self.assertTrue(all(status in [200, 409] for status, _ in responses))
        actual = self.must('transport', '/trips/' + trip['id'])
        self.assertEqual(actual['reservedSeats'], 1)

    def test_concurrency_checkout_and_payment_idempotency(self):
        _, trip = self.trip()
        body = {'tripId': trip['id'], 'ticketType': 'SINGLE', 'requestKey': str(uuid.uuid4())}
        with ThreadPoolExecutor(max_workers=5) as pool:
            results = list(pool.map(lambda _: api('ticketing', '/checkout', 'POST', body, self.passenger['token']), range(5)))
        self.assertTrue(all(status == 200 for status, _ in results), [s for s, _ in results])
        self.assertEqual(len({data['ticket']['id'] for _, data in results}), 1)
        ticket_id = results[0][1]['ticket']['id']
        self.must('ticketing', '/checkout', 'POST', {**body, 'ticketType': 'TEN_RIDE'}, self.passenger['token'], 409)
        pay_body = {'ticketId': ticket_id, 'requestKey': str(uuid.uuid4())}
        with ThreadPoolExecutor(max_workers=5) as pool:
            results = list(pool.map(lambda _: api('payment', '/payments', 'POST', pay_body, self.passenger['token']), range(5)))
        self.assertTrue(all(status == 200 for status, _ in results), [s for s, _ in results])
        self.assertEqual(len({data['id'] for _, data in results}), 1)
        self.must('payment', '/payments', 'POST', {'ticketId': ticket_id, 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_concurrency_validation_consumes_one_ride(self):
        _, trip = self.trip()
        purchase = self.paid(trip, 'TEN_RIDE')
        path = '/bookings/' + purchase['booking']['id'] + '/validate'
        self.must('ticketing', path, 'POST', {}, self.other_operator['token'], 403)
        with ThreadPoolExecutor(max_workers=5) as pool:
            responses = list(pool.map(lambda _: api('ticketing', path, 'POST', {}, self.operator['token']), range(5)))
        self.assertTrue(all(status == 200 for status, _ in responses), [s for s, _ in responses])
        ticket = self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=self.passenger['token'])
        self.assertEqual((ticket['usedRides'], ticket['reservedRides']), (1, 0))
        self.must('payment', '/refunds', 'POST', {'ticketId': ticket['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_concurrency_refund_revokes_and_releases(self):
        _, trip = self.trip()
        purchase = self.paid(trip)
        body = {'ticketId': purchase['ticket']['id'], 'requestKey': str(uuid.uuid4())}
        with ThreadPoolExecutor(max_workers=5) as pool:
            responses = list(pool.map(lambda _: api('payment', '/refunds', 'POST', body, self.passenger['token']), range(5)))
        self.assertTrue(all(status == 200 for status, _ in responses), [s for s, _ in responses])
        self.assertEqual(self.must('transport', '/trips/' + trip['id'])['reservedSeats'], 0)
        self.assertEqual(self.must('ticketing', '/tickets/' + body['ticketId'], token=self.passenger['token'])['status'], 'REFUNDED')
        self.must('payment', '/refunds', 'POST', {**body, 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_cancel_releases_seat_and_ride(self):
        _, trip = self.trip()
        purchase = self.paid(trip, 'TEN_RIDE')
        path = '/bookings/' + purchase['booking']['id'] + '/cancel'
        self.must('ticketing', path, 'POST', {}, self.passenger['token'])
        self.must('ticketing', path, 'POST', {}, self.passenger['token'])
        self.assertEqual(self.must('transport', '/trips/' + trip['id'])['reservedSeats'], 0)
        self.assertEqual(self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=self.passenger['token'])['reservedRides'], 0)

    def test_failed_payment_does_not_activate_ticket(self):
        _, trip = self.trip()
        purchase = self.checkout(trip)
        payment = self.must('payment', '/payments', 'POST', {'ticketId': purchase['ticket']['id'], 'outcome': 'FAILED', 'requestKey': str(uuid.uuid4())}, self.passenger['token'])
        self.assertEqual(payment['status'], 'FAILED')
        self.assertEqual(self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=self.passenger['token'])['status'], 'PENDING')

    def test_expired_hold_releases_capacity(self):
        _, trip = self.trip(capacity=1)
        purchase = self.checkout(trip)
        mongo('d.bookings.updateOne({id:' + json.dumps(purchase['booking']['id']) + '},{$set:{holdUntil:0}});')
        deadline = time.time() + 30
        while time.time() < deadline:
            if self.must('transport', '/trips/' + trip['id'])['reservedSeats'] == 0: break
            time.sleep(1)
        else: self.fail('Expired hold did not release its seat.')
        self.must('payment', '/payments', 'POST', {'ticketId': purchase['ticket']['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_unvalidated_past_booking_releases_reserved_ride(self):
        user = self.new_account('PASSENGER')
        _, trip = self.trip()
        purchase = self.paid(trip, 'TEN_RIDE', user)
        mongo('d.trips.updateOne({id:' + json.dumps(trip['id']) + '},{$set:{departureTime:"2000-01-01T00:00:00.000Z",arrivalTime:"2000-01-01T01:00:00.000Z"},$inc:{version:1}});')
        deadline = time.time() + 20
        while time.time() < deadline:
            booking = self.must('ticketing', '/bookings/' + purchase['booking']['id'], token=user['token'])
            if booking['status'] == 'EXPIRED': break
            time.sleep(1)
        else: self.fail('An unvalidated past booking remained active indefinitely.')
        ticket = self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=user['token'])
        self.assertEqual((ticket['usedRides'], ticket['reservedRides']), (0, 0))
        self.must('passenger', '/me', 'DELETE', token=user['token'])

    def test_single_ticket_cannot_switch_trips(self):
        route, trip = self.trip()
        purchase = self.paid(trip)
        self.must('ticketing', '/bookings/' + purchase['booking']['id'] + '/cancel', 'POST', {}, self.passenger['token'])
        _, other_trip = self.trip(route=route)
        self.must('ticketing', '/bookings', 'POST', {'ticketId': purchase['ticket']['id'], 'tripId': other_trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)
        self.must('ticketing', '/bookings', 'POST', {'ticketId': purchase['ticket']['id'], 'tripId': trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'])

    def test_pack_exhaustion_and_route_restriction(self):
        route, first = self.trip()
        purchase = self.paid(first, 'TEN_RIDE')
        ticket_id = purchase['ticket']['id']
        booking_ids = [purchase['booking']['id']]
        for _ in range(9):
            _, trip = self.trip(route=route)
            booking = self.must('ticketing', '/bookings', 'POST', {'ticketId': ticket_id, 'tripId': trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'])
            booking_ids.append(booking['id'])
        _, extra = self.trip(route=route)
        self.must('ticketing', '/bookings', 'POST', {'ticketId': ticket_id, 'tripId': extra['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)
        for booking_id in booking_ids: self.must('ticketing', '/bookings/' + booking_id + '/validate', 'POST', {}, self.operator['token'])
        self.assertEqual(self.must('ticketing', '/tickets/' + ticket_id, token=self.passenger['token'])['usedRides'], 10)
        _, other_route_trip = self.trip()
        self.must('ticketing', '/bookings', 'POST', {'ticketId': ticket_id, 'tripId': other_route_trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_monthly_pass_and_expiry(self):
        route, trip = self.trip()
        purchase = self.paid(trip, 'MONTHLY')
        for _ in range(10):
            _, next_trip = self.trip(route=route)
            self.must('ticketing', '/bookings', 'POST', {'ticketId': purchase['ticket']['id'], 'tripId': next_trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'])
        mongo('d.tickets.updateOne({id:' + json.dumps(purchase['ticket']['id']) + '},{$set:{validUntil:"2000-01-01T00:00:00.000Z"},$inc:{version:1}});')
        _, next_trip = self.trip(route=route)
        self.must('ticketing', '/bookings', 'POST', {'ticketId': purchase['ticket']['id'], 'tripId': next_trip['id'], 'requestKey': str(uuid.uuid4())}, self.passenger['token'], 409)

    def test_trip_cancellation_and_capacity_guards(self):
        _, trip = self.trip(capacity=2)
        purchase = self.paid(trip)
        self.paid(trip, user=self.other)
        body = {key: trip[key] for key in ['routeId', 'operatorId', 'departureTime', 'arrivalTime', 'capacity']}
        self.must('transport', '/trips/' + trip['id'], 'PUT', {**body, 'capacity': 1}, self.admin, 409)
        self.must('transport', '/trips/' + trip['id'] + '/cancel', 'POST', {}, self.admin)
        self.assertEqual(self.must('ticketing', '/bookings/' + purchase['booking']['id'], token=self.passenger['token'])['status'], 'CANCELLED')
        self.must('ticketing', '/bookings/' + purchase['booking']['id'] + '/validate', 'POST', {}, self.operator['token'], 404)

    def test_trip_schedule_update_notifies_owner(self):
        route, trip = self.trip()
        self.paid(trip)
        body = {key: trip[key] for key in ['routeId', 'operatorId', 'departureTime', 'arrivalTime', 'capacity']}
        updated = self.must('transport', '/trips/' + trip['id'], 'PUT', {**body,
            'departureTime': instant(15), 'arrivalTime': instant(75)}, self.manager['token'])
        self.assertTrue(updated['departureTime'].endswith('Z'))
        deadline = time.time() + 30
        while time.time() < deadline:
            notifications = json.loads(mongo('print(JSON.stringify(d.notifications.find({userId:' + json.dumps(self.passenger['id']) + ',"data.tripId":' + json.dumps(trip['id']) + '},{_id:0}).toArray()));'))
            if notifications: break
            time.sleep(1)
        else: self.fail('Trip schedule change was not delivered to the booking owner.')
        self.assertEqual(notifications[0]['data']['routeId'], route['id'])

    def test_validation_pagination_and_index_plan(self):
        self.must('transport', '/routes?limit=101', expected=400)
        self.must('transport', '/trips?offset=-1', expected=400)
        self.must('transport', '/routes', 'POST', {}, self.admin, 400)
        route, _ = self.trip()
        plan = json.loads(mongo('const e=d.routes.find({id:' + json.dumps(route['id']) + '}).explain("executionStats"); print(JSON.stringify({plan:e.queryPlanner.winningPlan,examined:e.executionStats.totalDocsExamined}));'))
        self.assertIn('IXSCAN', json.dumps(plan['plan']))
        self.assertLessEqual(plan['examined'], 1)

    def test_left_outer_join_retains_unmatched_trip(self):
        _, trip = self.trip()
        missing = str(uuid.uuid4())
        mongo('d.trips.updateOne({id:' + json.dumps(trip['id']) + '},{$set:{routeId:' + json.dumps(missing) + '}});')
        page = self.must('transport', '/trips?routeId=' + missing)
        self.assertEqual([item['id'] for item in page['items']], [trip['id']])

    def test_cli_journeys_for_all_roles(self):
        """Only prompt input is scripted; the real CLI calls the real gateway/services."""
        powershell = shutil.which('pwsh')
        self.assertIsNotNone(powershell, 'PowerShell 7 is required for CLI integration checks.')
        route, trip = self.trip()
        purchase = self.paid(trip)
        script = r'''
$ErrorActionPreference='Stop'
$spec=[Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
$module=Import-Module ./scripts/lib/Cli.psm1 -PassThru -DisableNameChecking
& $module {
    param($spec)
    $script:answers=[Collections.Generic.Queue[string]]::new()
    foreach($answer in $spec.answers) { $script:answers.Enqueue([string]$answer) }
    function script:Read-Host {
        param([string]$Prompt, [switch]$AsSecureString)
        if($script:answers.Count -eq 0) { throw 'CLI requested an unexpected prompt.' }
        $answer=$script:answers.Dequeue()
        if($AsSecureString) { return ConvertTo-SecureString $answer -AsPlainText -Force }
        return $answer
    }
    Start-UthCli -Context (New-UthContext -BaseUrl $spec.baseUrl)
    if($script:answers.Count) { throw 'CLI exited before consuming the journey.' }
} $spec
'''

        def journey(account, answers):
            spec = {'baseUrl': BASE, 'answers': ['1', account['email'], account['password'], *answers]}
            result = subprocess.run([powershell, '-NoProfile', '-Command', script], cwd=ROOT,
                input=json.dumps(spec), capture_output=True, text=True, encoding='utf-8', timeout=45)
            self.assertEqual(result.returncode, 0, 'CLI journey did not finish successfully.')
            self.assertIn('Signed in as Test (' + account['role'] + ').', result.stdout)
            self.assertNotIn('returned HTTP', result.stdout)
            self.assertNotIn(account['password'], result.stdout + result.stderr)
            return result.stdout

        # Authorization: assigned operators validate a booking through the same menu/API as users.
        journey(self.operator, ['1', '', '2', trip['id'], '', '3', purchase['booking']['id'], '13', '0'])
        self.assertEqual(self.must('ticketing', '/bookings/' + purchase['booking']['id'],
                                   token=self.passenger['token'])['status'], 'VALIDATED')
        journey(self.manager, ['14', route['id'], '', 'CLI updated route', '', '', '', '', '8', '13', '0'])
        self.assertEqual(self.must('transport', '/routes/' + route['id'])['name'], 'CLI updated route')
        # The bootstrap display name is configurable, so use a fresh staff account for this journey.
        staff_admin = self.new_account('SUPER_ADMIN')
        journey(staff_admin, ['10', self.other_operator['id'], 'ROUTE_OPERATOR', 'yes', '17', '', '12', '', '13', '0'])
        buyer = self.new_account('PASSENGER')
        trips = []
        while True:
            page = self.must('transport', '/trips?limit=100&offset=' + str(len(trips)))
            trips.extend(page['items'])
            if len(trips) >= page['total']: break
        selection = str(next(index + 1 for index, item in enumerate(trips) if item['id'] == trip['id']))
        output = journey(buyer, ['1', selection, 'TEN_RIDE', 'yes', '2', '', '3', '', '5', '', '7', '12', '0'])
        self.assertIn('CONFIRMED', output)
        ticket = self.must('ticketing', '/tickets', token=buyer['token'])['items'][0]
        self.created_tickets.append((ticket, buyer))
        self.must('payment', '/refunds', 'POST', {'ticketId': ticket['id'], 'requestKey': str(uuid.uuid4())}, buyer['token'])

    def test_representative_indexes_and_join_cardinality(self):
        marker = 'volume-' + uuid.uuid4().hex
        ids = [str(uuid.uuid5(uuid.NAMESPACE_URL, marker + '-' + str(index))) for index in range(2000)]
        # Disposable query fixtures exercise real indexes without adding thousands of audit events.
        try:
            mongo('const prefix=' + json.dumps(marker) + '; const ids=' + json.dumps(ids) + '; const rows=ids.map((id,i)=>({id,active:true,name:prefix+"-"+i,searchName:prefix+"-"+i,searchStart:"volume origin",searchEnd:"volume destination",createdAt:"2026-01-01T00:00:00Z",version:1,baseFareMinor:1250,transportType:"BUS",startLocation:"Volume origin",endLocation:"Volume destination",intermediateStops:[]})); d.routes.insertMany(rows);')
            data = json.loads(mongo('const prefix={$gte:' + json.dumps(marker + '-1999') + ',$lt:' + json.dumps(marker + '-1999\U0010ffff') + '}; const q={active:true,$or:[{searchName:prefix},{searchStart:prefix},{searchEnd:prefix}]}; const e=d.routes.find(q).sort({createdAt:-1,id:1}).explain("executionStats"); let duplicateRejected=false; try { const r=d.routes.findOne({id:' + json.dumps(ids[0]) + '}); delete r._id; d.routes.insertOne(r); } catch(e) { duplicateRejected=e.code===11000; } print(JSON.stringify({plan:e.queryPlanner.winningPlan,examined:e.executionStats.totalDocsExamined,returned:e.executionStats.nReturned,duplicateRejected}));'))
            self.assertIn('IXSCAN', json.dumps(data['plan']))
            self.assertEqual(data['returned'], 1)
            self.assertLessEqual(data['examined'], 1)
            self.assertTrue(data['duplicateRejected'], 'Unique IDs must prevent multiple foreign-key matches.')
            (ROOT / '.runtime/final-query-plan.json').write_text(json.dumps(data, indent=2) + '\n')
            page = self.must('transport', '/routes?q=' + marker + '-1999')
            self.assertEqual([item['id'] for item in page['items']], [ids[1999]])
            route, first = self.trip()
            _, second = self.trip(route=route)
            joined = self.must('transport', '/trips?routeId=' + route['id'])
            self.assertEqual({item['id'] for item in joined['items']}, {first['id'], second['id']})
            self.assertTrue(all(item['route']['id'] == route['id'] for item in joined['items']))
        finally:
            mongo('const q={searchName:{$regex:' + json.dumps('^' + marker + '-') + '}}; d.routes.deleteMany(q); if(d.routes.countDocuments(q)!==0) throw Error("Query fixture cleanup failed");')

    def test_z_kafka_outage_and_recovery(self):
        _, trip = self.trip()
        try:
            subprocess.run(['docker', 'compose', 'stop', 'kafka'], cwd=ROOT, check=True, capture_output=True, timeout=45)
            purchase = self.paid(trip)
            self.assertEqual(self.must('ticketing', '/tickets/' + purchase['ticket']['id'], token=self.passenger['token'])['status'], 'ACTIVE')
            pending = int(mongo('print(d.outbox.countDocuments({published:false,"data.ticketId":' + json.dumps(purchase['ticket']['id']) + '}));'))
            self.assertEqual(pending, 1)
            _, hold_trip = self.trip(capacity=1)
            held = self.checkout(hold_trip)
            mongo('d.bookings.updateOne({id:' + json.dumps(held['booking']['id']) + '},{$set:{holdUntil:0}});')
            deadline = time.time() + 15
            while time.time() < deadline:
                if self.must('transport', '/trips/' + hold_trip['id'])['reservedSeats'] == 0: break
                time.sleep(1)
            else: self.fail('Hold expiry incorrectly depends on Kafka availability.')
        finally:
            subprocess.run(['docker', 'compose', 'start', 'kafka'], cwd=ROOT, check=True, capture_output=True, timeout=45)
        deadline = time.time() + 75
        while time.time() < deadline:
            delivered = int(mongo('print(d.notifications.countDocuments({userId:' + json.dumps(self.passenger['id']) + ',"data.ticketId":' + json.dumps(purchase['ticket']['id']) + '}));'))
            if delivered: break
            time.sleep(2)
        else: self.fail('Durable event was not delivered after Kafka recovered.')

    def test_x_service_recreation_preserves_session_and_gateway(self):
        subprocess.run(['docker', 'compose', 'up', '-d', '--no-deps', '--force-recreate',
                        '--wait', '--wait-timeout', '60', 'passenger-service'], cwd=ROOT,
                       check=True, capture_output=True, timeout=90)
        deadline = time.time() + 25
        while time.time() < deadline:
            status, profile = api('passenger', '/me', token=self.passenger['token'])
            if status == 200:
                self.assertEqual(profile['id'], self.passenger['id'])
                return
            time.sleep(1)
        self.fail('Gateway/session did not recover after replacing a service container.')

    def test_w_fresh_database_bootstrap(self):
        values = dict(line.split('=', 1) for line in (ROOT / '.env').read_text(encoding='utf-8-sig').splitlines() if '=' in line and not line.startswith('#'))
        environment = {**os.environ, 'MONGO_ROOT_PASSWORD': values['MONGO_ROOT_PASSWORD'],
                       'MONGO_APP_PASSWORD': values['MONGO_APP_PASSWORD']}
        name = 'uth-bootstrap-check-' + uuid.uuid4().hex[:12]
        shell = 'export MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD"; cp /run/uth-key /tmp/key; chmod 400 /tmp/key; chown mongodb:mongodb /tmp/key; exec docker-entrypoint.sh mongod --replSet bootstrap-check --bind_ip 127.0.0.1 --keyFile /tmp/key'
        command = ['docker', 'run', '-d', '--name', name, '--network', 'none', '--memory', '512m',
            '--env', 'MONGO_ROOT_PASSWORD', '--env', 'MONGO_APP_PASSWORD', '--env', 'MONGO_INITDB_ROOT_USERNAME=uth_root',
            '--mount', f'type=bind,source={ROOT / "init-mongo.js"},target=/docker-entrypoint-initdb.d/init-mongo.js,readonly',
            '--mount', f'type=bind,source={ROOT / ".runtime" / "mongo-key"},target=/run/uth-key,readonly',
            '--entrypoint', '/bin/bash', 'uth-demo-v2-mongodb:local', '-c', shell]
        created = False
        try:
            subprocess.run(command, cwd=ROOT, env=environment, check=True, capture_output=True, timeout=30)
            created = True
            uri = 'mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000'
            probe = f'''mongosh '{uri}' --quiet --username uth_root --password "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin --eval 'try {{ rs.status() }} catch(e) {{ rs.initiate({{_id:"bootstrap-check",members:[{{_id:0,host:"127.0.0.1:27017"}}]}}) }}; if(!db.hello().isWritablePrimary) quit(1);' '''
            deadline = time.time() + 60
            while time.time() < deadline:
                result = subprocess.run(['docker', 'exec', name, 'sh', '-c', probe], capture_output=True, timeout=10)
                if result.returncode == 0: break
                time.sleep(1)
            else: self.fail('Fresh authenticated replica set did not become ready.')
            write_probe = f'''mongosh '{uri}' --quiet --username uth_app --password "$MONGO_APP_PASSWORD" --authenticationDatabase uth_demo_v2 --eval 'const d=db.getSiblingDB("uth_demo_v2"); if(!d.bootstrap_probe.insertOne({{id:"probe"}}).acknowledged) quit(1); d.bootstrap_probe.drop();' '''
            subprocess.run(['docker', 'exec', name, 'sh', '-c', write_probe], check=True, capture_output=True, timeout=15)
        finally:
            if created:
                subprocess.run(['docker', 'rm', '-fv', name], check=True, capture_output=True, timeout=20)

    def test_y_worker_restart_replay_and_quarantine(self):
        _, trip = self.trip()
        try:
            subprocess.run(['docker', 'compose', 'stop', 'notification-service'], cwd=ROOT, check=True, capture_output=True, timeout=45)
            purchase = self.paid(trip)
            event = json.loads(mongo('print(JSON.stringify(d.outbox.findOne({"data.ticketId":' + json.dumps(purchase['ticket']['id']) + '},{_id:0})));'))
            self.assertFalse(event['published'])
        finally:
            subprocess.run(['docker', 'compose', 'start', 'notification-service'], cwd=ROOT, check=True, capture_output=True, timeout=45)
        deadline = time.time() + 45
        while time.time() < deadline:
            delivered = int(mongo('print(d.notifications.countDocuments({eventId:' + json.dumps(event['id']) + '}));'))
            if delivered == 1: break
            time.sleep(1)
        else: self.fail('Committed outbox event did not survive a worker restart.')
        command = ['docker', 'compose', 'exec', '-T', 'kafka', '/opt/kafka/bin/kafka-console-producer.sh',
                   '--bootstrap-server', 'kafka:9092', '--topic', 'uth.events.v2']
        malformed_id = str(uuid.uuid4())
        malformed = {'id': malformed_id, 'recipient': '', 'data': {'message': 'Invalid event missing kind'}}
        after = {**event, 'id': str(uuid.uuid4()), 'data': {'message': 'Valid event after malformed event'}}
        subprocess.run(command, input=json.dumps(event) + '\n' + json.dumps(malformed) + '\n' + json.dumps(after) + '\n' + json.dumps(event) + '\n',
                       text=True, capture_output=True, cwd=ROOT, check=True, timeout=30)
        deadline = time.time() + 25
        while time.time() < deadline:
            failures = int(mongo('print(d.delivery_failures.countDocuments({"payload.id":' + json.dumps(malformed_id) + '}));'))
            continued = int(mongo('print(d.notifications.countDocuments({eventId:' + json.dumps(after['id']) + '}));'))
            if failures and continued == 1: break
            time.sleep(1)
        else: self.fail('Malformed event was not durably quarantined.')
        self.assertEqual(int(mongo('print(d.notifications.countDocuments({eventId:' + json.dumps(event['id']) + '}));')), 1)


if __name__ == '__main__': unittest.main()
