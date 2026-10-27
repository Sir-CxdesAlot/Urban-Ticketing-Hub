let token = sessionStorage.getItem('uth.token') || '';

export function setToken(value) {
    token = value;
    if (value) sessionStorage.setItem('uth.token', value);
    else sessionStorage.removeItem('uth.token');
}

export function hasSession() { return Boolean(token); }

export async function request(service, path, { method = 'GET', body } = {}) {
    const headers = { Accept: 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const response = await fetch(`/api/v1/${service}${path}`, {
        method, headers, body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(15000), cache: 'no-store',
    });
    const data = await response.json().catch(() => null);
    if (!response.ok) {
        const error = new Error(data?.error?.message || `Request failed (${response.status}). Try again.`);
        error.status = response.status;
        if (response.status === 401) {
            setToken('');
            window.dispatchEvent(new Event('session-ended'));
        }
        throw error;
    }
    return data;
}

export function operationKey() { return crypto.randomUUID(); }
export const money = minor => new Intl.NumberFormat('en-NA', { style: 'currency', currency: 'NAD' }).format(minor / 100);
export const date = value => new Date(value).toLocaleString('en-NA', { dateStyle: 'medium', timeStyle: 'short' });
