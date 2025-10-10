// Utilities and helpers
(() => {
  const App = (window.App = window.App || {});
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  // CSS.escape polyfill
  if (typeof CSS === 'undefined' || typeof CSS.escape !== 'function') {
    (function () {
      const cssEscape = function (value) {
        if (arguments.length === 0) {
          throw new TypeError('`CSS.escape` requires an argument.');
        }
        var string = String(value);
        var length = string.length;
        var index = -1;
        var codeUnit;
        var result = '';
        var firstCodeUnit = string.charCodeAt(0);
        while (++index < length) {
          codeUnit = string.charCodeAt(index);
          if (codeUnit == 0x0000) {
            result += '\uFFFD';
            continue;
          }
          if (
            (codeUnit >= 0x0001 && codeUnit <= 0x001f) ||
            codeUnit == 0x007f ||
            (index == 0 && codeUnit >= 0x0030 && codeUnit <= 0x0039) ||
            (index == 1 &&
              codeUnit >= 0x0030 &&
              codeUnit <= 0x0039 &&
              firstCodeUnit == 0x002d)
          ) {
            result += '\\' + codeUnit.toString(16) + ' ';
            continue;
          }
          if (
            codeUnit >= 0x0080 ||
            codeUnit == 0x002d ||
            codeUnit == 0x005f ||
            (codeUnit >= 0x0030 && codeUnit <= 0x0039) ||
            (codeUnit >= 0x0041 && codeUnit <= 0x005a) ||
            (codeUnit >= 0x0061 && codeUnit <= 0x007a)
          ) {
            result += string.charAt(index);
            continue;
          }
          result += '\\' + string.charAt(index);
        }
        return result;
      };
      if (typeof window.CSS === 'undefined') window.CSS = {};
      window.CSS.escape = cssEscape;
    })();
  }

  function debounce(fn, wait = 120) {
    let t;
    return function (...args) {
      clearTimeout(t);
      t = setTimeout(() => fn.apply(this, args), wait);
    };
  }

  function genId() {
    try {
      if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
        return crypto.randomUUID();
      }
    } catch {}
    return 'id-' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  // Avatars: inline SVG fallbacks (theme-aligned)
  const phSm =
    'data:image/svg+xml;utf8,' +
    encodeURIComponent(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"36\" height=\"36\" viewBox=\"0 0 36 36\"><rect width=\"36\" height=\"36\" rx=\"18\" fill=\"#111a2a\"/><circle cx=\"12\" cy=\"14\" r=\"5\" fill=\"#2b4366\"/><rect x=\"6\" y=\"22\" width=\"24\" height=\"8\" rx=\"4\" fill=\"#2b4366\"/></svg>"
    );
  const phLg =
    'data:image/svg+xml;utf8,' +
    encodeURIComponent(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"60\" height=\"60\" viewBox=\"0 0 60 60\"><rect width=\"60\" height=\"60\" rx=\"30\" fill=\"#f2eadf\"/><circle cx=\"20\" cy=\"24\" r=\"8\" fill=\"#a88f6c\"/><rect x=\"10\" y=\"36\" width=\"40\" height=\"12\" rx=\"6\" fill=\"#a88f6c\"/></svg>"
    );

  const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (ch) => ESC[ch]);
  const safeUrl = (u) => {
    const v = String(u || '').trim();
    if (!/^https?:\/\//i.test(v)) return '';
    if (/["'<>]/.test(v)) return '';
    return v;
  };
  function wireAvatarFallbacks(root = document) {
    $$('.avatar', root).forEach((img) => {
      img.onerror = () => {
        img.onerror = null;
        img.src = img.classList.contains('avatar-sm') ? phSm : phLg;
      };
    });
  }

  const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  function setError(id, msg) {
    const el = document.getElementById(id);
    if (el) el.textContent = msg || '';
  }

  App.utils = { $, $$, debounce, genId, phSm, phLg, esc, safeUrl, wireAvatarFallbacks, emailRe, setError };
})();
