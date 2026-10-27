// Output encoding: untrusted values become text nodes, never executable HTML.
export function el(tag, attributes = {}, ...children) {
    const node = document.createElement(tag);
    for (const [name, value] of Object.entries(attributes)) {
        if (name.startsWith('on')) node.addEventListener(name.slice(2), value);
        else if (name === 'className') node.className = value;
        else if (value !== undefined && value !== false) node.setAttribute(name, value === true ? '' : value);
    }
    for (const child of children.flat()) {
        if (child !== undefined && child !== null && child !== false) node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return node;
}

export function button(label, action, className = '') {
    return el('button', { type: 'button', className, onclick: async event => {
        const control = event.currentTarget;
        control.disabled = true;
        try { await action(); }
        catch (failure) { window.dispatchEvent(new CustomEvent('ui-error', { detail: failure })); }
        finally { control.disabled = false; }
    } }, label);
}

export function field(label, name, options = {}) {
    const { type = 'text', value = '', choices, required = true, ...attributes } = options;
    const control = choices
        ? el('select', { name, required }, choices.map(([id, text]) => el('option', { value: id }, text)))
        : el(type === 'textarea' ? 'textarea' : 'input', { name, type, required, ...attributes });
    control.value = value;
    return el('label', {}, label, control);
}

export function form(fields, submitLabel, onSubmit) {
    const error = el('p', { role: 'alert' });
    const submit = el('button', { type: 'submit', className: 'primary' }, submitLabel);
    const node = el('form', { className: 'panel' }, fields, error, submit);
    node.addEventListener('submit', async event => {
        event.preventDefault();
        if (submit.disabled) return;
        submit.disabled = true;
        error.textContent = '';
        try { await onSubmit(Object.fromEntries(new FormData(node))); }
        catch (failure) { error.textContent = failure.message; }
        finally { submit.disabled = false; }
    });
    return node;
}

export function row(title, details, actions = [], subtitle = '') {
    return el('article', { className: 'list-row' },
        el('div', {}, el('h3', {}, title), subtitle && el('p', { className: 'badge' }, subtitle),
            details.map(text => el('p', { className: 'meta' }, text))),
        el('div', { className: 'actions' }, actions));
}
