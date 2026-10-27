import { request, hasSession, setToken } from './api.js';
import { el, button } from './dom.js';
import * as passenger from './passenger.js';
import { staff } from './staff.js';

const content = document.querySelector('#content');
const notice = document.querySelector('#notice');
const dialog = document.querySelector('#authDialog');
const authForm = document.querySelector('#authForm');
let registering = false;
let navigationVersion = 0;

const ctx = {
    user: null, bookingTicket: null,
    show(title, ...children) {
        content.replaceChildren(el('h1', {}, title), ...children.filter(Boolean));
    },
    notify(message, error = false) {
        notice.textContent = message; notice.classList.toggle('error', error);
    },
    signIn() { if (!dialog.open) dialog.showModal(); },
    endSession() { setToken(''); ctx.user = null; ctx.bookingTicket = null; renderNavigation(); },
    navigate,
    async list(service, path, renderItem) {
        const container = el('div', { className: 'list' });
        let offset = 0;
        let pageVersion = 0;
        async function load() {
            const current = ++pageVersion;
            container.setAttribute('aria-busy', 'true');
            try {
                const joiner = path.includes('?') ? '&' : '?';
                const page = await request(service, `${path}${joiner}limit=20&offset=${offset}`);
                if (current !== pageVersion) return;
                const rows = page.items.map(renderItem);
                const pager = el('div', { className: 'pager' },
                    offset > 0 && button('Previous', () => { offset -= 20; return load(); }),
                    el('span', {}, page.total ? `${offset + 1}–${offset + page.items.length} of ${page.total}` : '0 results'),
                    offset + page.items.length < page.total && button('Next', () => { offset += 20; return load(); }));
                container.replaceChildren(...rows, ...(!rows.length ? [el('p', { className: 'empty' }, 'Nothing here yet.')] : []), pager);
            } finally { if (current === pageVersion) container.setAttribute('aria-busy', 'false'); }
        }
        await load(); return container;
    },
};

const views = { routes: passenger.routes, trips: passenger.trips, bookings: passenger.bookings,
    tickets: passenger.tickets, payments: passenger.payments, notifications: passenger.notifications,
    profile: passenger.profile, staff };
const labels = { routes: 'Routes', trips: 'Trips', bookings: 'My bookings', tickets: 'My tickets',
    payments: 'Payments', notifications: 'Notifications', profile: 'Profile', staff: 'Staff workspace' };

function allowedViews() {
    if (!ctx.user) return ['routes', 'trips'];
    if (ctx.user.role === 'PASSENGER') return ['routes', 'trips', 'bookings', 'tickets', 'payments', 'notifications', 'profile'];
    if (['ROUTE_OPERATOR', 'TRANSPORT_MANAGER', 'SUPER_ADMIN'].includes(ctx.user.role)) return ['routes', 'trips', 'staff', 'notifications', 'profile'];
    return ['routes', 'trips'];
}

function renderNavigation() {
    const active = location.hash.slice(1) || 'routes';
    document.querySelector('#navigation').replaceChildren(...allowedViews().map(name =>
        el('a', { href: `#${name}`, 'aria-current': name === active ? 'page' : undefined }, labels[name])));
    document.querySelector('#authButton').textContent = ctx.user ? 'Sign out' : 'Sign in';
}

async function navigate(name = location.hash.slice(1) || 'routes') {
    const version = ++navigationVersion;
    if (!allowedViews().includes(name)) { name = 'routes'; ctx.notify('Sign in with an authorized account to open that page.', true); }
    history.replaceState(null, '', `#${name}`);
    renderNavigation();
    content.setAttribute('aria-busy', 'true');
    // Concurrency: each navigation may render only while it remains the current view.
    const view = {
        ...ctx,
        get user() { return ctx.user; }, set user(value) { ctx.user = value; },
        get bookingTicket() { return ctx.bookingTicket; }, set bookingTicket(value) { ctx.bookingTicket = value; },
        show(...parts) { if (version === navigationVersion) ctx.show(...parts); },
    };
    try { await views[name](view); }
    catch (failure) {
        if (version !== navigationVersion) return;
        ctx.show('Unable to load this page', el('p', { role: 'alert' }, failure.message), button('Try again', () => navigate(name)));
    } finally { if (version === navigationVersion) content.setAttribute('aria-busy', 'false'); }
}

document.querySelector('#navigation').addEventListener('click', event => {
    const link = event.target.closest('a');
    if (link) { event.preventDefault(); ctx.bookingTicket = null; navigate(link.hash.slice(1)); }
});
document.querySelector('.brand').addEventListener('click', event => { event.preventDefault(); navigate('routes'); });
window.addEventListener('hashchange', () => navigate());
window.addEventListener('ui-error', event => ctx.notify(event.detail.message, true));
window.addEventListener('session-ended', () => { ctx.endSession(); ctx.notify('Your session ended. Sign in again.', true); navigate('routes'); });
document.querySelector('#authButton').addEventListener('click', async () => {
    if (!ctx.user) { ctx.signIn(); return; }
    try { await request('passenger', '/logout', { method: 'POST', body: {} }); }
    catch (failure) {
        if (failure.status !== 401) ctx.notify('Signed out on this tab. Server sign-out could not be confirmed.', true);
    } finally { ctx.endSession(); await navigate('routes'); }
});
document.querySelector('#closeAuth').addEventListener('click', () => dialog.close());
document.querySelector('#toggleRegistration').addEventListener('click', () => {
    registering = !registering;
    document.querySelector('#registrationFields').hidden = !registering;
    for (const input of document.querySelectorAll('#registrationFields input')) input.required = registering;
    document.querySelector('#authTitle').textContent = registering ? 'Create an account' : 'Sign in';
    document.querySelector('#submitAuth').textContent = registering ? 'Create account' : 'Sign in';
    document.querySelector('#toggleRegistration').textContent = registering ? 'I already have an account' : 'Create a passenger account';
    authForm.elements.password.autocomplete = registering ? 'new-password' : 'current-password';
    document.querySelector('#authError').textContent = '';
});
authForm.addEventListener('submit', async event => {
    event.preventDefault();
    const submit = document.querySelector('#submitAuth');
    if (submit.disabled) return;
    submit.disabled = true;
    document.querySelector('#authError').textContent = '';
    try {
        const values = Object.fromEntries(new FormData(authForm));
        if (registering) await request('passenger', '/register', { method: 'POST', body: values });
        const result = await request('passenger', '/login', { method: 'POST', body: { email: values.email, password: values.password } });
        setToken(result.token); ctx.user = result.user;
        authForm.reset(); dialog.close(); ctx.notify(`Welcome, ${ctx.user.firstName}.`);
        await navigate(ctx.user.role === 'PASSENGER' ? 'routes' : 'staff');
    } catch (failure) { document.querySelector('#authError').textContent = failure.message; }
    finally { submit.disabled = false; }
});

function applyTheme(theme) {
    document.documentElement.dataset.theme = theme;
    const label = theme === 'dark' ? 'Light theme' : 'Dark theme';
    document.querySelector('#themeButton').textContent = label;
    document.querySelector('#themeButton').setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`);
}
applyTheme(localStorage.getItem('uth.theme') === 'light' ? 'light' : 'dark');
document.querySelector('#themeButton').addEventListener('click', () => {
    const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('uth.theme', theme); applyTheme(theme);
});

// Explicit initialization: restore identity, then load the first view exactly once.
if (hasSession()) {
    try { ctx.user = await request('passenger', '/me'); }
    catch (failure) { if (failure.status !== 401) ctx.notify('Could not restore your session. Try signing in again.', true); }
}
await navigate();
