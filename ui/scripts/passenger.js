import { request, operationKey, money, date } from './api.js';
import { el, button, field, form, row } from './dom.js';

const products = [['SINGLE', 'Single trip · one fare'], ['TEN_RIDE', 'Ten rides / 30 days · eight fares'], ['MONTHLY', 'Unlimited / 30 days · twenty fares']];

export async function routes(ctx) {
    const search = field('Find a route or destination', 'search', { type: 'search', required: false, placeholder: 'Start typing a route, origin, or destination' });
    const renderRoute = route => row(route.name,
        [`${route.startLocation} → ${route.endLocation}`, `${money(route.baseFareMinor)} per single trip`],
        [button('View trips', () => trips(ctx, route))], route.transportType);
    const results = el('div', {}, await ctx.list('transport', '/routes', renderRoute));
    let timer;
    let version = 0;
    // Debouncing: query the server's complete indexed route set with bounded result pages.
    search.querySelector('input').addEventListener('input', event => {
        clearTimeout(timer);
        const current = ++version;
        const term = event.target.value.trim();
        timer = setTimeout(async () => {
            try {
                const page = await ctx.list('transport', `/routes?q=${encodeURIComponent(term)}`, renderRoute);
                if (current === version) results.replaceChildren(page);
            } catch (failure) { if (current === version) ctx.notify(failure.message, true); }
        }, 300);
    });
    ctx.show('Find your next trip', el('p', { className: 'muted' }, 'Choose a route, reserve a seat, and travel with one ticket or a pass.'), search, results);
}

export async function trips(ctx, route = null) {
    const selectedTicket = ctx.bookingTicket;
    const routeId = route?.id || selectedTicket?.routeId;
    const path = `/trips${routeId ? `?routeId=${encodeURIComponent(routeId)}` : ''}${selectedTicket?.ticketType === 'SINGLE' ? `&tripId=${encodeURIComponent(selectedTicket.originalTripId)}` : ''}`;
    const results = await ctx.list('transport', path, trip => {
        const bookingKey = operationKey();
        const actions = trip.availableSeats > 0 ? [button(selectedTicket ? 'Book with this ticket' : 'Choose ticket', async () => {
            if (!ctx.user) { ctx.signIn(); return; }
            if (ctx.user.role !== 'PASSENGER') throw new Error('Use a passenger account to purchase travel.');
            if (selectedTicket) {
                await request('ticketing', '/bookings', { method: 'POST', body: {
                    ticketId: selectedTicket.id, tripId: trip.id, requestKey: bookingKey,
                } });
                ctx.bookingTicket = null;
                ctx.notify('Your seat is booked.');
                await ctx.navigate('bookings');
            } else purchase(ctx, trip);
        }, 'primary')] : [];
        return row(trip.route?.name || route?.name || 'Scheduled trip',
            [`Departs ${date(trip.departureTime)}`, `Arrives ${date(trip.arrivalTime)}`, `${trip.availableSeats} seats available`], actions);
    });
    ctx.show(selectedTicket ? 'Book your next ride' : route ? route.name : 'Upcoming trips',
        selectedTicket && el('p', {}, 'Using your ', selectedTicket.ticketType, ' ticket. ',
            button('Choose a different ticket', () => { ctx.bookingTicket = null; return ctx.navigate('tickets'); })), results);
}

function purchase(ctx, trip) {
    const key = operationKey();
    const baseFare = trip.route?.baseFareMinor;
    const prices = baseFare ? products.map(([id, label]) => [id, `${label} — ${money(baseFare * (id === 'TEN_RIDE' ? 8 : id === 'MONTHLY' ? 20 : 1))}`]) : products;
    ctx.show('Choose your ticket', el('p', {}, trip.route?.name || 'Selected route'),
        el('p', {}, `Departs ${date(trip.departureTime)}. Your ticket includes this booking.`),
        form([field('Ticket type', 'ticketType', { choices: prices, value: 'SINGLE' })], 'Reserve for 10 minutes', async body => {
            const result = await request('ticketing', '/checkout', { method: 'POST', body: { ...body, tripId: trip.id, requestKey: key } });
            payment(ctx, result.ticket);
        }), button('Back to trips', () => trips(ctx, trip.route)));
}

function payment(ctx, ticket) {
    const key = operationKey();
    ctx.show('Confirm payment', el('p', {}, `${ticket.ticketType} · ${money(ticket.amountMinor)}`),
        el('p', { className: 'muted' }, 'This is a simulated payment. Do not enter card or bank details. An unpaid seat is held for ten minutes.'),
        form([], `Pay ${money(ticket.amountMinor)}`, async () => {
            await request('payment', '/payments', { method: 'POST', body: { ticketId: ticket.id, requestKey: key } });
            ctx.notify('Payment received. Your booking is confirmed.');
            await ctx.navigate('bookings');
        }), button('Return to my tickets', () => ctx.navigate('tickets')));
}

export async function tickets(ctx) {
    ctx.show('My tickets', await ctx.list('ticketing', '/tickets', ticket => {
        const refundKey = operationKey();
        const actions = [];
        if (ticket.status === 'PENDING') actions.push(button('Complete payment', () => payment(ctx, ticket), 'primary'));
        if (ticket.status === 'ACTIVE') {
            if (new Date(ticket.validUntil) > new Date()) actions.push(button(ticket.ticketType === 'SINGLE' ? 'Rebook original trip' : 'Book another trip', () => { ctx.bookingTicket = ticket; return trips(ctx); }));
            if (ticket.usedRides === 0) actions.push(button('Refund unused ticket', async () => {
                if (!confirm('Refund this ticket and cancel all of its bookings?')) return;
                await request('payment', '/refunds', { method: 'POST', body: { ticketId: ticket.id, requestKey: refundKey } });
                ctx.notify('Ticket refunded. Its bookings have been cancelled.');
                await tickets(ctx);
            }, 'danger'));
        }
        const displayStatus = ticket.status === 'ACTIVE' && new Date(ticket.validUntil) < new Date() ? 'EXPIRED' : ticket.status;
        return row(ticket.route?.name || 'Route ticket', [`${ticket.ticketType} · ${money(ticket.amountMinor)}`,
            `${ticket.usedRides} rides used · ${ticket.reservedRides} reserved`, `Valid until ${date(ticket.validUntil)}`, `Ticket ID: ${ticket.id}`], actions, displayStatus);
    }));
}

export async function bookings(ctx) {
    ctx.show('My bookings', await ctx.list('ticketing', '/bookings', booking => {
        const actions = [];
        if (booking.active && new Date(booking.trip?.departureTime) > new Date()) actions.push(button('Cancel booking', async () => {
            if (!confirm('Cancel this booking and release the seat?')) return;
            await request('ticketing', `/bookings/${encodeURIComponent(booking.id)}/cancel`, { method: 'POST', body: {} });
            ctx.notify('Booking cancelled.'); await bookings(ctx);
        }));
        return row(booking.route?.name || 'Trip booking',
            [booking.trip ? `Departs ${date(booking.trip.departureTime)}` : 'Trip details unavailable', `Booking ID: ${booking.id}`,
                booking.status === 'HELD' ? 'Complete payment from My tickets before the hold expires.' : 'Show the booking ID to your operator.'], actions, booking.status);
    }));
}

export async function payments(ctx) {
    ctx.show('My payments', el('p', { className: 'muted' }, 'All payments in this application are simulated.'),
        await ctx.list('payment', '/payments', item => row(money(item.amountMinor),
            [`${date(item.createdAt)}`, `Ticket ID: ${item.ticketId}`], [], item.status)));
}

export async function notifications(ctx) {
    ctx.show('Notifications', await ctx.list('notification', '/notifications', item => row(item.message,
        [date(item.createdAt)], [
            ...(!item.read ? [button('Mark read', async () => {
                await request('notification', `/notifications/${encodeURIComponent(item.id)}/read`, { method: 'POST', body: {} });
                await notifications(ctx);
            })] : []),
            button('Delete', async () => {
                await request('notification', `/notifications/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
                await notifications(ctx);
            }),
        ], item.read ? 'Read' : 'Unread')));
}

export async function profile(ctx) {
    const user = await request('passenger', '/me');
    ctx.show('My profile', el('p', {}, `${user.email} · ${user.role.replaceAll('_', ' ')}`),
        form([field('First name', 'firstName', { value: user.firstName, maxlength: 80 }),
            field('Last name', 'lastName', { value: user.lastName, maxlength: 80 }),
            field('Phone', 'phone', { type: 'tel', value: user.phone, maxlength: 30 })], 'Save profile', async body => {
            ctx.user = await request('passenger', '/me', { method: 'PUT', body });
            ctx.notify('Profile saved.');
        }), user.role === 'PASSENGER' && button('Delete my account', async () => {
            if (!confirm('Deactivate your account and remove your profile details? Cancel or complete active bookings first.')) return;
            await request('passenger', '/me', { method: 'DELETE' }); ctx.endSession();
            ctx.notify('Your account has been deactivated.'); await ctx.navigate('routes');
        }, 'danger'));
}
