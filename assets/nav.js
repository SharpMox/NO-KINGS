/* ============================================================
 *  Shared site header — markup and behaviour.
 *
 *  One definition for all eight pages. Before this, the nav was
 *  copy-pasted verbatim into every file, so adding a link meant
 *  seven identical edits and any of them could silently drift.
 *
 *  Each page carries only:
 *      <div id="site-nav" data-page="codex"></div>
 *      <script src="assets/nav.js"></script>
 *  plus data-base="../" for pages in a subdirectory.
 *
 *  Load it BEFORE assets/theme.js: theme.js binds #theme-toggle by
 *  id, and this script is what creates that button.
 *
 *  Styles live in assets/nav.css.
 * ============================================================ */
(function () {
  var mount = document.getElementById('site-nav');
  if (!mount) return;

  // key, href, label. `gap` pushes this and everything after it to the right.
  var LINKS = [
    ['codex',        'codex.html',            'Codex'],
    ['graph',        'graph.html',            'Graph'],
    ['promotion',    'promotion.html',        'Promotions'],
    ['fusion',       'fusion.html',           'Fusions'],
    ['inversion',    'inversion.html',        'Inversions'],
    ['artefacts',    'artefacts.html',        'Artefacts'],
    ['encyclopedia', 'encyclopedia/index.html', 'Encyclopedia', 'gap'],
    ['betza',        'betza.html',            'Betza']
  ];

  // Explicit rather than sniffed from location: the site is served from a
  // subpath on GitHub Pages, so counting path segments is not reliable.
  var base = mount.dataset.base || '';
  var current = mount.dataset.page || '';

  var MOON = '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true">' +
    '<path d="M21.64 13a1 1 0 0 0-1.05-.14 8.05 8.05 0 0 1-3.37.73 8.15 8.15 0 0 1-8.14-8.1 8.59 8.59 0 0 1 .25-2A1 1 0 0 0 8 2.36 10.14 10.14 0 1 0 22 14.05a1 1 0 0 0-.36-1.05Z"/></svg>';
  var BARS = '<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" ' +
    'stroke-width="2" stroke-linecap="round" aria-hidden="true">' +
    '<path d="M4 7h16"/><path d="M4 12h16"/><path d="M4 17h16"/></svg>';

  mount.innerHTML =
    '<nav class="nk-nav-in" aria-label="Site sections">' +
      '<a class="nk-mark" href="' + base + 'codex.html">NO KINGS</a>' +
      '<div class="nk-links" id="nk-menu">' +
        LINKS.map(function (l) {
          return '<a class="nk' + (l[3] === 'gap' ? ' nk-gap' : '') + '" href="' + base + l[1] + '"' +
            (l[0] === current ? ' aria-current="page"' : '') + '>' + l[2] + '</a>';
        }).join('') +
      '</div>' +
      '<button class="nk-burger" id="burger" aria-expanded="false" aria-controls="nk-menu" aria-label="Open menu">' + BARS + '</button>' +
      '<button class="nk-theme" id="theme-toggle" aria-label="Toggle dark mode" aria-pressed="false" title="Toggle dark mode">' + MOON + '</button>' +
    '</nav>';

  // ---- Publish the measured header height. Pages pin things below the header
  // (deep-linked cards, betza's sticky panels) and used to hardcode ~94px for
  // the old two-row mobile nav. They read var(--nav-h) instead now, so nothing
  // goes stale when the header changes shape.
  function syncHeight() {
    document.documentElement.style.setProperty('--nav-h', mount.offsetHeight + 'px');
  }
  syncHeight();
  if (window.ResizeObserver) new ResizeObserver(syncHeight).observe(mount);
  else addEventListener('resize', syncHeight);

  // ---- Burger
  var burger = document.getElementById('burger');
  var menu = document.getElementById('nk-menu');
  function setMenu(open) {
    menu.toggleAttribute('data-open', open);
    burger.setAttribute('aria-expanded', String(open));
    burger.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  }
  burger.addEventListener('click', function () {
    setMenu(burger.getAttribute('aria-expanded') !== 'true');
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && burger.getAttribute('aria-expanded') === 'true') {
      setMenu(false);
      burger.focus();
    }
  });
  document.addEventListener('click', function (e) {
    if (burger.getAttribute('aria-expanded') !== 'true') return;
    if (!menu.contains(e.target) && !burger.contains(e.target)) setMenu(false);
  });
  // Leaving the phone breakpoint must not strand the panel open.
  var mq = matchMedia('(max-width: 860px)');
  if (mq.addEventListener) mq.addEventListener('change', function () { setMenu(false); });
})();
