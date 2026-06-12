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
    const saved = localStorage.getItem('fp-theme');
    if (saved) setTheme(saved);
    else if (window.matchMedia('(prefers-color-scheme: dark)').matches) setTheme('dark');
    else setTheme('light');
  } catch (e) {}
})();
