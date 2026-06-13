/* Tab persistence across NO-KINGS pages.
   On any page that has a [role="tablist"], remember which tab was last
   active and restore it on the next visit. Storage is per-page (keyed
   by the URL pathname). A URL hash like #tab-foo takes precedence so
   deep links still work. */
(function () {
  const KEY_PREFIX = 'nokings-tab:';
  function pageKey() {
    const p = location.pathname.replace(/\/+$/, '').replace(/^.*\//, '').replace(/\.html?$/i, '') || 'index';
    return KEY_PREFIX + p;
  }

  function setup() {
    const tablist = document.querySelector('[role="tablist"]');
    if (!tablist) return;
    const buttons = Array.from(tablist.querySelectorAll('[role="tab"]'));
    if (!buttons.length) return;

    // Save on every tab activation.
    buttons.forEach(btn => {
      btn.addEventListener('click', () => {
        try { localStorage.setItem(pageKey(), btn.getAttribute('aria-controls')); } catch (_) {}
      });
    });

    // Don't restore if a hash link is targeting a specific tab.
    if (location.hash && /^#tab-/.test(location.hash)) return;

    try {
      const saved = localStorage.getItem(pageKey());
      if (!saved) return;
      const target = buttons.find(b => b.getAttribute('aria-controls') === saved);
      if (!target) return;
      if (target.getAttribute('aria-selected') === 'true') return; // already default
      target.click();
    } catch (_) { /* localStorage may be unavailable */ }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
})();
