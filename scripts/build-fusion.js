/* ============================================================
 *  build-fusion.js
 *  Generates fusion.html from data/pieces-codex.js.
 *
 *  Run from anywhere:  node scripts/build-fusion.js
 * ============================================================ */
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const codexDataPath = path.join(repoRoot, 'data', 'pieces-codex.js');
const outputPath    = path.join(repoRoot, 'fusion.html');

const PIECES_CODEX = require(codexDataPath);

// 25 pieces referenced by the fusion table.
const FUSION_IDS = [
  'rook','bishop','queen','knight','archbishop','alibaba','squirrel',
  'ferz','gryphon','wazir','manticore','godzilla','dragon-king',
  'dragon-horse','elephant-modern','war-machine','chancellor','champion',
  'high-priestess','kirin','crown-princess','amazon','banshee','raven',
  'amazonrider'
];

const FUSIONS = {
  additive: [
    { lhs: 'alibaba', rhs: 'war-machine', out: 'champion' },
    { lhs: 'knight', rhs: 'elephant-modern', out: 'high-priestess' },
    { lhs: 'knight', rhs: 'alibaba', out: 'squirrel' },
    { lhs: 'rook', rhs: 'kirin', out: 'dragon-king' },
    { lhs: 'bishop', rhs: 'knight',         out: 'archbishop' },
    { lhs: 'bishop', rhs: 'high-priestess', out: 'archbishop' },
    { lhs: 'knight', rhs: 'rook', out: 'chancellor' },
    { lhs: 'bishop',       rhs: 'rook',         out: 'queen' },
    { lhs: 'bishop',       rhs: 'dragon-king',  out: 'queen' },
    { lhs: 'rook',         rhs: 'dragon-horse', out: 'queen' },
    { lhs: 'dragon-horse', rhs: 'dragon-king',  out: 'queen' },
    { lhs: 'bishop',     rhs: 'chancellor',    out: 'amazon' },
    { lhs: 'knight',     rhs: 'queen',         out: 'amazon' },
    { lhs: 'rook',       rhs: 'archbishop',    out: 'amazon' },
    { lhs: 'archbishop', rhs: 'chancellor',    out: 'amazon' },
    { lhs: 'archbishop', rhs: 'dragon-king',   out: 'amazon' },
    { lhs: 'archbishop', rhs: 'queen',         out: 'amazon' },
    { lhs: 'chancellor', rhs: 'dragon-horse',  out: 'amazon' },
    { lhs: 'chancellor', rhs: 'queen',         out: 'amazon' },
    { lhs: 'queen',      rhs: 'high-priestess', out: 'amazon' },
    { lhs: 'knight',       rhs: 'dragon-horse',   out: 'crown-princess' },
    { lhs: 'wazir',        rhs: 'archbishop',     out: 'crown-princess' },
    { lhs: 'archbishop',   rhs: 'dragon-horse',   out: 'crown-princess' },
    { lhs: 'dragon-horse', rhs: 'high-priestess', out: 'crown-princess' },
  ],
  synergistic: [
    { lhs: 'ferz',  rhs: 'rook',   out: 'gryphon'   },
    { lhs: 'wazir', rhs: 'bishop', out: 'manticore' },
    { lhs: 'archbishop', rhs: 'knight', out: 'banshee'     },
    { lhs: 'chancellor', rhs: 'knight', out: 'raven'       },
    { lhs: 'amazon',     rhs: 'knight', out: 'amazonrider' },
    { lhs: 'manticore', rhs: 'gryphon', out: 'godzilla' },
  ],
};

// Sanity-check the dataset matches the IDs we expect to render.
{
  const datasetIds = new Set(PIECES_CODEX.map(p => p.id));
  const missing = FUSION_IDS.filter(id => !datasetIds.has(id));
  if (missing.length) {
    console.error('pieces-codex.js is missing IDs the fusion build needs:', missing.join(', '));
    process.exit(1);
  }
}

// Fields not rendered by fusion.html that we strip on embed to keep the
// inline PIECES array as close to the pre-refactor shape as possible.
const FUSION_OMIT = new Set(['original_name', 'description_codex']);

// Subset and re-format the dataset blocks the same way the original
// fusion-pieces.txt was formatted so the inline `const PIECES = [...]`
// keeps the same shape.
function formatPieceBlock(piece) {
  // Use the same shape the original /tmp/fusion-pieces.txt used: pretty,
  // 4-space-leading indentation, identifier-style keys.
  // (We hand-format because JSON.stringify would quote every key.)
  const lines = [];
  lines.push('    {');
  for (const key of Object.keys(piece)) {
    if (FUSION_OMIT.has(key)) continue;
    const val = piece[key];
    let valStr;
    if (key === 'moves') {
      valStr = '[\n' + val.map(m => '        ' + formatMove(m)).join(',\n') + '\n      ]';
    } else if (Array.isArray(val)) {
      valStr = '[' + val.map(v => typeof v === 'string' ? `'${v}'` : JSON.stringify(v)).join(', ') + ']';
    } else if (typeof val === 'string') {
      valStr = `'${val.replace(/'/g, "\\'")}'`;
    } else {
      valStr = JSON.stringify(val);
    }
    lines.push(`      ${key}: ${valStr},`);
  }
  // Strip trailing comma on last line.
  lines[lines.length - 1] = lines[lines.length - 1].replace(/,$/, '');
  lines.push('    }');
  return lines.join('\n');
}

function formatMove(move) {
  // { kind: 'rays', dirs: [...] } or { kind: 'dots', squares: [...] } etc.
  const entries = Object.keys(move).map(k => {
    const v = move[k];
    if (typeof v === 'string') return `${k}: '${v}'`;
    if (Array.isArray(v)) return `${k}: [${v.map(item => Array.isArray(item) ? `[${item.join(',')}]` : JSON.stringify(item)).join(',')}]`;
    return `${k}: ${JSON.stringify(v)}`;
  });
  return `{ ${entries.join(', ')} }`;
}

const piecesBody = FUSION_IDS
  .map(id => PIECES_CODEX.find(p => p.id === id))
  .map(formatPieceBlock)
  .join(',\n');

const fusionsJs = JSON.stringify(FUSIONS, null, 2);

const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fairy Chess — Fusions</title>
  <link rel="stylesheet" href="assets/site.css">
  <script src="assets/board.js"></script>
  <style>
    header {
      max-width: 1280px;
      margin: 0 auto;
      padding: 32px 24px 16px;
    }
    h1 {
      margin: 0 0 8px 0;
      font-size: 32px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }
    .intro {
      color: var(--text-soft);
      max-width: 760px;
      margin: 0 0 24px 0;
      font-size: 15px;
    }
    .controls {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      align-items: center;
      margin-bottom: 16px;
    }
    .back-link {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      text-decoration: none;
      color: var(--accent);
      font-weight: 500;
      font-size: 14px;
      padding: 8px 14px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
    }
    .back-link:hover { text-decoration: none; border-color: var(--accent); }
    .theme-toggle {
      appearance: none;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      width: 38px;
      height: 38px;
      cursor: pointer;
      color: var(--text);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-left: auto;
    }
    .theme-toggle:hover { color: var(--accent); }

    .tabs {
      display: flex;
      gap: 2px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 4px;
    }
    .tab-btn {
      appearance: none;
      background: transparent;
      border: 0;
      padding: 8px 16px;
      font-size: 14px;
      font-weight: 500;
      color: var(--text-soft);
      cursor: pointer;
      border-radius: 7px;
      font-family: inherit;
      transition: color 0.15s ease, background 0.15s ease;
    }
    .tab-btn:hover { color: var(--text); }
    .tab-btn[aria-selected="true"] {
      background: var(--bg);
      color: var(--text);
      box-shadow: 0 1px 2px rgba(0,0,0,0.06);
    }
    .tab-count {
      display: inline-block;
      margin-left: 4px;
      padding: 1px 6px;
      font-size: 11px;
      font-weight: 600;
      color: var(--text-soft);
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      line-height: 1.4;
    }
    .tab-btn[aria-selected="true"] .tab-count {
      background: var(--surface);
      color: var(--text);
    }

    main {
      max-width: 1280px;
      margin: 0 auto;
      padding: 0 24px 64px;
    }
    section[role="tabpanel"] { display: none; }
    section[role="tabpanel"].active { display: block; }

    .fusion-table {
      border-collapse: separate;
      border-spacing: 8px;
      width: 100%;
    }
    .fusion-table td,
    .fusion-table th {
      padding: 0;
      vertical-align: middle;
    }
    .fusion-table tbody td {
      padding-top: 48px;
    }
    .fusion-table tbody tr:first-child td {
      padding-top: 0;
    }
    .fusion-op {
      text-align: center;
      font-size: 32px;
      color: var(--text-soft);
      font-weight: 300;
      width: 1%;
      user-select: none;
    }
    .mini-card {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
      width: 280px;
      padding: 8px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      box-shadow: var(--shadow);
      margin: 0 auto;
    }
    .mini-card .board {
      width: 100%;
      height: auto;
      display: block;
      border-radius: 4px;
      overflow: hidden;
      background: var(--sq-light);
    }
    .mini-betza { font-size: 11px; color: var(--text-soft); font-family: 'SF Mono','Menlo',monospace; text-align: center; line-height: 1.2; }
    a.mini-betza { display: block; text-decoration: none; cursor: pointer; transition: color 0.12s ease; }
    a.mini-betza:hover { color: var(--accent); }
    .mini-name {
      font-size: 13px;
      font-weight: 500;
      text-align: center;
      color: var(--text);
      line-height: 1.2;
    }

    @media (max-width: 720px) {
      h1 { font-size: 24px; }
      .controls { gap: 8px; }
      .theme-toggle { margin-left: 0; }
      .mini-card { width: 140px; padding: 6px; }
      .fusion-op { font-size: 22px; }
      .fusion-table { border-spacing: 4px; }
    }
  </style>
</head>
<body>
  <nav class="site-nav" aria-label="Site sections">
    <div class="site-nav-inner">
      <a href="codex.html">Codex</a>
      <a href="promotion.html">Promotions</a>
      <a href="fusion.html" class="active">Fusions</a>
      <a href="inversion.html">Inversions</a>
      <a href="encyclopedia/index.html" class="nav-encyclopedia">Encyclopedia</a>
      <a href="betza.html">Betza</a>
      <button class="theme-toggle" id="theme-toggle" aria-label="Toggle dark mode" title="Toggle dark mode">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true">
          <path d="M21.64 13a1 1 0 0 0-1.05-.14 8.05 8.05 0 0 1-3.37.73 8.15 8.15 0 0 1-8.14-8.1 8.59 8.59 0 0 1 .25-2A1 1 0 0 0 8 2.36 10.14 10.14 0 1 0 22 14.05a1 1 0 0 0-.36-1.05Z"/>
        </svg>
      </button>
    </div>
  </nav>
  <header>
    <h1>Fusions</h1>
    <p class="intro">
      A reference of the <strong>30 fusions</strong> in NO-KINGS.
    </p>
    <div class="controls">
      <div class="tabs" role="tablist" aria-label="Fusion type">
        <button class="tab-btn" role="tab" aria-selected="true"  aria-controls="tab-additive"    id="tabbtn-additive">Additive <span class="tab-count" id="count-additive"></span></button>
        <button class="tab-btn" role="tab" aria-selected="false" aria-controls="tab-synergistic" id="tabbtn-synergistic">Synergistic <span class="tab-count" id="count-synergistic"></span></button>
      </div>
    </div>
  </header>

  <main>
    <section role="tabpanel" id="tab-additive"    aria-labelledby="tabbtn-additive" class="active">
      <div id="additive-table"></div>
    </section>
    <section role="tabpanel" id="tab-synergistic" aria-labelledby="tabbtn-synergistic">
      <div id="synergistic-table"></div>
    </section>
  </main>

  <footer>
    <p class="footer-page-line">Pairs of pieces whose movement schemes combine into a third piece — additive (set-equality) and synergistic (emergent bent rider) flavours.</p>
    <p>Sourced from the <a href="https://en.wikipedia.org/wiki/List_of_fairy_chess_pieces" target="_blank" rel="noopener">Wikipedia article on fairy chess pieces</a> and <a href="https://en.wikipedia.org/wiki/Fairy_chess_piece" target="_blank" rel="noopener">Betza's notation</a>. Built as a single static HTML file — no servers, no frameworks.</p>
    <p>Companion pages: <a href="codex.html">codex</a> · <a href="promotion.html">promotions</a> · <a href="inversion.html">inversions</a> · <a href="encyclopedia/index.html">encyclopedia</a> · <a href="betza.html">Betza</a>.</p>
  </footer>

  <script>
  const PIECES = [
${piecesBody}
  ];

  const FUSIONS = ${fusionsJs};

  /* ============================================================
   *  Fusion rendering (renderBoard/renderMove live in assets/board.js)
   * ============================================================ */

  function renderMiniCard(piece) {
    const betzaLine = piece.betza ? \`<a class="mini-betza" href="betza.html?b=\${encodeURIComponent(piece.betza)}" target="_blank" rel="noopener" title="Open in Betza sandbox">\${piece.betza}</a>\` : '';
    return \`<div class="mini-card">
      \${renderBoard(piece)}
      <div class="mini-name">\${piece.name}</div>
      \${betzaLine}
    </div>\`;
  }

  function renderFusion(f) {
    const card = id => {
      const p = PIECES.find(x => x.id === id);
      return p ? renderMiniCard(p) : \`<div class="mini-card"><em>missing: \${id}</em></div>\`;
    };
    return \`<tr>
      <td>\${card(f.lhs)}</td>
      <td class="fusion-op">+</td>
      <td>\${card(f.rhs)}</td>
      <td class="fusion-op">=</td>
      <td>\${card(f.out)}</td>
    </tr>\`;
  }

  function renderTable(rows) {
    return \`<table class="fusion-table"><tbody>\${rows.map(renderFusion).join('')}</tbody></table>\`;
  }

  document.getElementById('additive-table').innerHTML = renderTable(FUSIONS.additive);
  document.getElementById('synergistic-table').innerHTML = renderTable(FUSIONS.synergistic);
  document.getElementById('count-additive').textContent = FUSIONS.additive.length;
  document.getElementById('count-synergistic').textContent = FUSIONS.synergistic.length;

  /* ============================================================
   *  Tab switching
   * ============================================================ */
  const tabBtns = Array.from(document.querySelectorAll('.tab-btn'));
  const panels = Array.from(document.querySelectorAll('[role="tabpanel"]'));
  function activateTab(panelId) {
    panels.forEach(p => p.classList.toggle('active', p.id === panelId));
    tabBtns.forEach(b => {
      const sel = b.getAttribute('aria-controls') === panelId;
      b.setAttribute('aria-selected', sel ? 'true' : 'false');
      b.setAttribute('tabindex', sel ? '0' : '-1');
    });
    history.replaceState(null, '', '#' + panelId);
  }
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => activateTab(btn.getAttribute('aria-controls')));
  });
  if (location.hash === '#tab-synergistic') activateTab('tab-synergistic');

  /* ============================================================
   *  Theme toggle
   * ============================================================ */
  const themeToggle = document.getElementById('theme-toggle');
  function setTheme(t) {
    if (t === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
    try { localStorage.setItem('fp-theme', t); } catch (e) {}
  }
  themeToggle.addEventListener('click', () => {
    const current = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
    setTheme(current === 'dark' ? 'light' : 'dark');
  });
  try {
    const saved = localStorage.getItem('fp-theme');
    if (saved) setTheme(saved);
    else if (window.matchMedia('(prefers-color-scheme: dark)').matches) setTheme('dark');
  } catch (e) {}
  </script>
</body>
</html>
`;

fs.writeFileSync(outputPath, html);
console.log('Wrote', html.length, 'bytes to fusion.html');
