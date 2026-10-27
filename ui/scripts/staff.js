import { request, money, date } from './api.js';
import { el, button, field, form, row } from './dom.js';

const managerRoles = ['TRANSPORT_MANAGER', 'SUPER_ADMIN'];
const staffRoles = [['ROUTE_OPERATOR', 'Route operator'], ['TRANSPORT_MANAGER', 'Transport manager'], ['SUPER_ADMIN', 'Super administrator']];

async function options(service, path, label) {
    const choices = [];
    let offset = 0;
    while (true) {
        const page = await request(service, `${path}?limit=100&offset=${offset}`);
        for (const item of page.items) choices.push([item.id, label(item)]);
        offset += page.items.length;
        if (offset >= page.total || !page.items.length) return choices;
    }
}

export async function staff(ctx) {
    const actions = [button('Validate bookings', () => validation(ctx))];
    if (managerRoles.includes(ctx.user.role)) actions.push(
        button('Manage routes', () => routes(ctx)), button('Manage trips', () => trips(ctx)),
        button('Reports', () => reports(ctx)), button('Send announcement', () => announcement(ctx)));
    if (ctx.user.role === 'SUPER_ADMIN') actions.push(button('Manage accounts', () => accounts(ctx)),
        button('Audit and delivery', () => operations(ctx)));
    ctx.show('Staff workspace', el('p', { className: 'muted' }, `${ctx.user.firstName} · ${ctx.user.role.replaceAll('_', ' ')}`),
        el('div', { className: 'toolbar' }, actions));
}

async function routes(ctx) {
    ctx.show('Manage routes', button('Create route', () => routeForm(ctx)),
        await ctx.list('transport', '/routes', item => row(item.name,
            [`${item.startLocation} → ${item.endLocation}`, `${money(item.baseFareMinor)} · ${item.transportType}`],
            [button('Edit', () => routeForm(ctx, item)), button('Retire', async () => {
                if (!confirm('Retire this route? Cancel its future trips first.')) return;
                await request('transport', `/routes/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
                ctx.notify('Route retired.'); await routes(ctx);
            })])));
}

function routeForm(ctx, route = {}) {
    ctx.show(route.id ? 'Edit route' : 'Create route', form([
        field('Route name', 'name', { value: route.name, maxlength: 120 }),
        field('Start location', 'startLocation', { value: route.startLocation, maxlength: 120 }),
        field('End location', 'endLocation', { value: route.endLocation, maxlength: 120 }),
        field('Intermediate stops (comma separated)', 'stops', { value: route.intermediateStops?.join(', '), required: false }),
        field('Transport type', 'transportType', { choices: [['BUS', 'Bus'], ['TRAIN', 'Train'], ['SHUTTLE', 'Shuttle']], value: route.transportType || 'BUS' }),
        field('Base fare (NAD)', 'fare', { type: 'number', min: '.01', max: 10000, step: '.01', value: route.baseFareMinor ? route.baseFareMinor / 100 : '' }),
    ], 'Save route', async values => {
        const { stops, fare, ...body } = values;
        body.intermediateStops = stops.split(',').map(stop => stop.trim()).filter(Boolean);
        body.baseFareMinor = Math.round(Number(fare) * 100);
        await request('transport', `/routes${route.id ? `/${encodeURIComponent(route.id)}` : ''}`, { method: route.id ? 'PUT' : 'POST', body });
        ctx.notify('Route saved.'); await routes(ctx);
    }), button('Back to routes', () => routes(ctx)));
}

async function trips(ctx) {
    ctx.show('Manage trips', button('Create trip', () => tripForm(ctx)),
        await ctx.list('transport', '/trips', item => row(item.route?.name || 'Trip',
            [`${date(item.departureTime)} → ${date(item.arrivalTime)}`, `${item.availableSeats} / ${item.capacity} seats available`],
            [button('Edit schedule', () => tripForm(ctx, item)), button('Cancel trip', async () => {
                if (!confirm('Cancel this trip and release its active bookings? Passengers will be notified.')) return;
                await request('transport', `/trips/${encodeURIComponent(item.id)}/cancel`, { method: 'POST', body: {} });
                ctx.notify('Trip cancelled.'); await trips(ctx);
            })])));
}

function localTime(value) {
    if (!value) return '';
    const instant = new Date(value);
    return new Date(instant - instant.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

async function tripForm(ctx, trip = {}) {
    const [routes, operators] = await Promise.all([
        options('transport', '/routes', item => item.name),
        options('admin', '/operators', item => `${item.firstName} ${item.lastName}`),
    ]);
    if (!routes.length || !operators.length) throw new Error('Create a route and an active route operator before scheduling a trip.');
    ctx.show(trip.id ? 'Edit trip schedule' : 'Schedule a trip', form([
        field('Route', 'routeId', { choices: routes, value: trip.routeId || routes[0][0] }),
        field('Departure (your local time)', 'departureTime', { type: 'datetime-local', value: localTime(trip.departureTime) }),
        field('Arrival (your local time)', 'arrivalTime', { type: 'datetime-local', value: localTime(trip.arrivalTime) }),
        field('Seats', 'capacity', { type: 'number', min: 1, max: 200, value: trip.capacity || 40 }),
        field('Assigned operator', 'operatorId', { choices: operators, value: trip.operatorId || operators[0][0] }),
    ], 'Save trip', async values => {
        const body = { ...values, capacity: Number(values.capacity), departureTime: new Date(values.departureTime).toISOString(), arrivalTime: new Date(values.arrivalTime).toISOString() };
        await request('transport', `/trips${trip.id ? `/${encodeURIComponent(trip.id)}` : ''}`, { method: trip.id ? 'PUT' : 'POST', body });
        ctx.notify('Trip saved.'); await trips(ctx);
    }), button('Back to trips', () => trips(ctx)));
}

async function validation(ctx) {
    const trips = await options('admin', '/assigned-trips', item => `${item.route?.name || 'Trip'} · ${date(item.departureTime)}`);
    if (!trips.length) { ctx.show('Validate bookings', el('p', { className: 'empty' }, 'No trips are currently available for validation.')); return; }
    ctx.show('Validate bookings', el('p', { className: 'muted' }, 'Validation opens 30 minutes before departure and closes two hours after arrival.'),
        form([field('Trip', 'tripId', { choices: trips, value: trips[0][0] })], 'Load bookings', async values => {
            const list = await ctx.list('ticketing', `/bookings?tripId=${encodeURIComponent(values.tripId)}`, item => row(item.id,
                [`Passenger ID: ${item.userId}`], item.status === 'CONFIRMED' ? [button('Validate ride', async () => {
                    await request('ticketing', `/bookings/${encodeURIComponent(item.id)}/validate`, { method: 'POST', body: {} });
                    ctx.notify('Booking validated. One ride was consumed.'); await validation(ctx);
                }, 'primary')] : [], item.status));
            ctx.show('Trip bookings', button('Choose another trip', () => validation(ctx)), list);
        }));
}

async function reports(ctx) {
    const report = await request('admin', '/reports');
    const table = el('table', {}, el('caption', {}, 'Simulated payment totals by status'),
        el('thead', {}, el('tr', {}, ...['Status', 'Payments', 'Amount'].map(value => el('th', { scope: 'col' }, value)))),
        el('tbody', {}, report.payments.map(item => el('tr', {}, el('td', {}, item.status), el('td', {}, item.count), el('td', {}, money(item.totalMinor))))));
    ctx.show('Transport report', el('p', {}, `${report.accounts} active accounts · ${report.routes} routes · ${report.trips} scheduled trips`),
        el('p', {}, `${report.activeBookings} active bookings · ${report.pendingEvents} events awaiting publication`), el('div', { className: 'table-wrap' }, table));
}

function announcement(ctx) {
    ctx.show('Send an announcement', el('p', { className: 'muted' }, 'Each active passenger receives their own notification and read status.'),
        form([field('Announcement', 'message', { type: 'textarea', maxlength: 500, rows: 4 })], 'Send to passengers', async body => {
            await request('notification', '/broadcasts', { method: 'POST', body });
            ctx.notify('Announcement queued for delivery.'); await staff(ctx);
        }));
}

async function accounts(ctx) {
    ctx.show('Manage accounts', button('Create staff account', () => accountForm(ctx)),
        await ctx.list('admin', '/accounts', item => row(`${item.firstName} ${item.lastName}`,
            [item.email, item.role.replaceAll('_', ' ')], item.id !== ctx.user.id ? [button('Change access', () => accessForm(ctx, item))] : [], item.active ? 'Active' : 'Inactive')));
}

function accountForm(ctx) {
    ctx.show('Create staff account', form([
        field('First name', 'firstName', { maxlength: 80 }), field('Last name', 'lastName', { maxlength: 80 }),
        field('Email', 'email', { type: 'email', maxlength: 254 }), field('Phone', 'phone', { type: 'tel', maxlength: 30 }),
        field('Initial password', 'password', { type: 'password', minlength: 12, maxlength: 128, autocomplete: 'new-password' }),
        field('Role', 'role', { choices: staffRoles, value: 'ROUTE_OPERATOR' }),
    ], 'Create staff account', async body => {
        await request('admin', '/accounts', { method: 'POST', body }); ctx.notify('Staff account created.'); await accounts(ctx);
    }));
}

function accessForm(ctx, account) {
    ctx.show('Change account access', el('p', {}, account.email), form([
        field('Role', 'role', { choices: [['PASSENGER', 'Passenger'], ...staffRoles], value: account.role }),
        field('Account state', 'active', { choices: [['true', 'Active'], ['false', 'Inactive']], value: String(account.active) }),
    ], 'Save access and end existing sessions', async values => {
        await request('admin', `/accounts/${encodeURIComponent(account.id)}`, { method: 'PUT', body: { role: values.role, active: values.active === 'true' } });
        ctx.notify('Account access updated. Earlier sessions have ended.'); await accounts(ctx);
    }));
}

async function operations(ctx) {
    const [events, failures, audit] = await Promise.all([
        ctx.list('admin', '/events', item => row(item.kind, [`${item.attempts} attempts`, item.lastError || 'Awaiting publication'])),
        ctx.list('admin', '/delivery-failures', item => row(item.id, [item.reason], [button('Retry delivery', async () => {
            await request('admin', `/delivery-failures/${encodeURIComponent(item.id)}/retry`, { method: 'POST', body: {} });
            ctx.notify('Delivery retried.'); await operations(ctx);
        })])),
        ctx.list('admin', '/audit', item => row(item.action, [`${date(item.createdAt)}`, `Actor: ${item.actorId}`, `Subject: ${item.subjectId}`])),
    ]);
    ctx.show('Audit and delivery', el('h2', {}, 'Events awaiting publication'), events,
        el('h2', {}, 'Failed deliveries'), failures, el('h2', {}, 'Audit records'), audit);
}
