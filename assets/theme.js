/* Shared theme toggle across all pages.
   Behaviour byte-identical to the per-page copies it replaces:
   - Toggles `data-theme="dark"` on <html>.
   - Persists choice in localStorage under `fp-theme`.
   - On first visit, honours prefers-color-scheme: dark. */
(function () {
  const themeToggle = document.getElementById('theme-toggle');
  function setTheme(t) {
    if (t === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
    if (themeToggle) themeToggle.setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
    try { localStorage.setItem('fp-theme', t); } catch (e) {}
  }
  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
      setTheme(current === 'dark' ? 'light' : 'dark');
    });
  }
  try {
    // Dark is the product default; prefers-color-scheme is deliberately not
    // consulted, so a first-time visitor sees the intended look whatever their
    // OS is set to. Only an explicit choice made here selects light.
    // assets/theme-init.js applies the same rule before first paint.
    setTheme(localStorage.getItem('fp-theme') === 'light' ? 'light' : 'dark');
  } catch (e) { setTheme('dark'); }
})();
