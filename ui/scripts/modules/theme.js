// Theme handling
(() => {
  const App = (window.App = window.App || {});
  const THEME_KEY = 'theme';

  function applyTheme(t) {
    const root = document.documentElement;
    root.classList.remove('light', 'dark');
    root.classList.add(t);
    const btn = document.getElementById('themeToggle');
    if (btn) {
      btn.setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
      const img = btn.querySelector('img');
      if (img) img.src = t === 'dark' ? 'icons/moon.svg' : 'icons/sun.svg';
    }
  }
  function initTheme() {
    console.log('initTheme called');
    let t = localStorage.getItem(THEME_KEY);
    if (!t) t = 'dark';
    console.log('Initializing theme:', t);
    applyTheme(t);
  }
  function toggleTheme() {
    console.log('toggleTheme called');
    const current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    console.log('Current theme:', current, '→ Next theme:', next);
    applyTheme(next);
    localStorage.setItem(THEME_KEY, next);
  }

  App.theme = { applyTheme, initTheme, toggleTheme };
})();
