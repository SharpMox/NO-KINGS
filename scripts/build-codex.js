/* ============================================================
 *  build-codex.js
 *  Generates codex.html from encyclopedia/index.html as a template,
 *  swapping in the curated 38-piece dataset from data/pieces-codex.js,
 *  the codex-specific tabs, relations sidebars, etc.
 *
 *  Run from anywhere:  node scripts/build-codex.js
 * ============================================================ */
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const encyclopediaPath = path.join(repoRoot, 'encyclopedia', 'index.html');
const codexDataPath    = path.join(repoRoot, 'data',         'pieces-codex.js');
const outputPath       = path.join(repoRoot, 'codex.html');

const PIECES_CODEX = require(codexDataPath);
const encyclopediaHtml = fs.readFileSync(encyclopediaPath, 'utf8');

// Order: 8 promotion chains laid out sequentially; each piece immediately
// followed by its void counterpart when one exists. Non-chain pieces close out.
const CODEX_IDS = [
  // Chain 1 — Pawn
  'pawn', 'berolina',
  'sergeant', 'inv-sergeant',
  'arrow-pawn', 'inv-arrow-pawn',
  // Chain 2 — Ferz
  'ferz', 'elephant-modern', 'high-priestess',
  // Chain 3 — Wazir
  'wazir', 'war-machine', 'champion',
  // Chain 4 — Bishop
  'bishop', 'dragon-horse', 'archbishop',
  // Chain 5 — Rook
  'rook', 'dragon-king', 'chancellor',
  // Chain 6 — Knight
  'knight', 'gnu', 'buffalo',
  // Chain 7 — Kirin
  'kirin',
  'kirin-plus', 'inv-kirin-plus',
  'kirin-plus-plus', 'inv-kirin-plus-plus',
  // Chain 8 — Alibaba
  'alibaba', 'bodyguard', 'queen',
  // Non-chain pieces
  'squirrel', 'crown-princess', 'amazon',
  'gryphon', 'manticore', 'godzilla',
  'banshee', 'raven', 'amazonrider'
];

// Sanity-check the dataset matches the IDs we expect to render.
{
  const datasetIds = new Set(PIECES_CODEX.map(p => p.id));
  const missing = CODEX_IDS.filter(id => !datasetIds.has(id));
  if (missing.length) {
    console.error('pieces-codex.js is missing IDs the build expects:', missing.join(', '));
    process.exit(1);
  }
}

// Stitch together the codex page based on the encyclopedia template.
let codexHtml = encyclopediaHtml;

// 1. Title
codexHtml = codexHtml.replace(
  /<title>[^<]*<\/title>/,
  '<title>Fairy Chess — Codex</title>'
);

// 2. Swap the encyclopedia data <script src> for the codex data file.
codexHtml = codexHtml.replace(
  '<script src="../data/pieces-encyclopedia.js"></script>',
  '<script src="data/pieces-codex.js"></script>'
);
// 3. Adjust asset relative paths: encyclopedia is one level deep, codex sits at root.
codexHtml = codexHtml.replace('<link rel="stylesheet" href="../assets/site.css">', '<link rel="stylesheet" href="assets/site.css">');
codexHtml = codexHtml.replace('<script src="../assets/board.js"></script>', '<script src="assets/board.js"></script>');

// 4. Replace the encyclopedia's PIECES alias. Codex prefers the short
//    Betza-atom prose (description_codex) over the full encyclopedia text.
codexHtml = codexHtml.replace(
  'const PIECES = PIECES_ENCYCLOPEDIA;',
  'const PIECES = PIECES_CODEX.map(p => ({ ...p, description: p.description_codex || p.description }));'
);

// 5. Site nav — Codex first on left, marked active; remove Encyclopedia 'active' class.
codexHtml = codexHtml.replace(
  /<nav class="site-nav"[\s\S]*?<\/nav>/,
  `<nav class="site-nav" aria-label="Site sections">
    <div class="site-nav-inner">
      <a href="codex.html" class="active">Codex</a>
      <a href="graph.html">Graph</a>
      <a href="promotion.html">Promotions</a>
      <a href="fusion.html">Fusions</a>
      <a href="inversion.html">Inversions</a>
      <a href="encyclopedia/index.html" class="nav-encyclopedia">Encyclopedia</a>
      <a href="betza.html">Betza</a>
      <button class="theme-toggle" id="theme-toggle" aria-label="Toggle dark mode" title="Toggle dark mode">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true">
          <path d="M21.64 13a1 1 0 0 0-1.05-.14 8.05 8.05 0 0 1-3.37.73 8.15 8.15 0 0 1-8.14-8.1 8.59 8.59 0 0 1 .25-2A1 1 0 0 0 8 2.36 10.14 10.14 0 1 0 22 14.05a1 1 0 0 0-.36-1.05Z"/>
        </svg>
      </button>
    </div>
  </nav>`
);

// 6. h1
codexHtml = codexHtml.replace(/<h1>Fairy Chess Pieces<\/h1>/, '<h1>Codex</h1>');

// 7. Intro paragraph
codexHtml = codexHtml.replace(
  /<p class="intro">[\s\S]*?<\/p>/,
  `<p class="intro">A filterable reference of the <strong>${CODEX_IDS.length} pieces</strong> used across NO-KINGS.</p>`
);

// 8. Normalise relative '../' references — encyclopedia is one level deep, codex is at root.
codexHtml = codexHtml.replace(/href="\.\.\/promotion\.html"/g, 'href="promotion.html"');
codexHtml = codexHtml.replace(/href="\.\.\/fusion\.html"/g, 'href="fusion.html"');
codexHtml = codexHtml.replace(/href="\.\.\/inversion\.html"/g, 'href="inversion.html"');
codexHtml = codexHtml.replace(/href="\.\.\/encyclopedia\/index\.html"/g, 'href="encyclopedia/index.html"');
codexHtml = codexHtml.replace(/href="\.\.\/betza\.html"/g, 'href="betza.html"');
codexHtml = codexHtml.replace(/href="index\.html"/g, 'href="codex.html"');

// 9. Strip the origin tag from the card header — codex cards shouldn't show the historical origin.
codexHtml = codexHtml.replace(/\s*<span class="origin-tag">\$\{piece\.origin\}<\/span>/, '');

// 10. renderCard — add the original_name line right under the card-name h2 when it differs from name.
codexHtml = codexHtml.replace(
  /<h2 class="card-name">\${piece\.name}<\/h2>\s*\n\s*\${aliases}/,
  `<h2 class="card-name">\${piece.name}</h2>
            \${piece.original_name && piece.original_name !== piece.name ? '<div class="original-name">originally <em>' + piece.original_name + '</em></div>' : ''}
            \${aliases}`
);

// 11. Add styling for .original-name (small italic line under the card name).
codexHtml = codexHtml.replace(
  /\.card-aliases \{/,
  `.original-name { font-size: 12px; color: var(--text-soft); margin-top: 2px; font-style: italic; }
    .card-aliases {`
);

// 12. Footer — update copy.
codexHtml = codexHtml.replace(
  /<footer>[\s\S]*?<\/footer>/,
  `<footer>
    <p class="footer-page-line">A curated codex of ${CODEX_IDS.length} pieces — every piece referenced in the promotions, fusions and inversions pages.</p>
    <p>Sourced from the <a href="https://en.wikipedia.org/wiki/List_of_fairy_chess_pieces" target="_blank" rel="noopener">Wikipedia article on fairy chess pieces</a> and <a href="https://en.wikipedia.org/wiki/Fairy_chess_piece" target="_blank" rel="noopener">Betza's notation</a>. Built as a single static HTML file — no servers, no frameworks.</p>
    <p>Companion pages: <a href="promotion.html">promotions</a> · <a href="fusion.html">fusions</a> · <a href="inversion.html">inversions</a> · <a href="encyclopedia/index.html">encyclopedia</a> · <a href="betza.html">Betza</a>.</p>
  </footer>`
);

// 13. Replace the second row of tabs (origin tabs) with our 6 codex categories.
const ROW2_CATEGORIES = [
  { id: 'new',    label: 'New',    members: ['kirin-plus','kirin-plus-plus','inv-sergeant','inv-arrow-pawn','inv-kirin-plus','inv-kirin-plus-plus'] },
  { id: 'base',   label: 'Base',   members: ['pawn','ferz','wazir','bishop','rook','knight','kirin','alibaba'] },
  { id: 'mid',    label: 'Mid',    members: ['sergeant','elephant-modern','war-machine','dragon-horse','dragon-king','gnu','kirin-plus','bodyguard'] },
  { id: 'end',    label: 'End',    members: ['arrow-pawn','high-priestess','champion','archbishop','chancellor','buffalo','kirin-plus-plus','queen'] },
  { id: 'invert', label: 'Invert', members: ['berolina','inv-sergeant','inv-arrow-pawn','inv-kirin-plus','inv-kirin-plus-plus'] },
  { id: 'fusion', label: 'Fusion', members: ['crown-princess','amazon','gryphon','manticore','banshee','raven','amazonrider','godzilla','squirrel'] }
];

const newTabButtons = ROW2_CATEGORIES.map(c =>
  `        <button class="tab-btn" role="tab" aria-selected="false" aria-controls="tab-cat-${c.id}" id="tabbtn-cat-${c.id}">${c.label} <span class="tab-count" id="count-cat-${c.id}">0</span></button>`
).join('\n');

codexHtml = codexHtml.replace(
  /<div class="tabs origin-tabs"[\s\S]*?<\/div>/,
  `<div class="tabs origin-tabs" role="tablist" aria-label="Category">\n${newTabButtons}\n      </div>`
);

const newTabPanels = ROW2_CATEGORIES.map(c =>
  `    <section role="tabpanel" id="tab-cat-${c.id}" aria-labelledby="tabbtn-cat-${c.id}"> <div class="card-grid" id="grid-cat-${c.id}"></div> </section>`
).join('\n');

codexHtml = codexHtml.replace(
  /(\s*<section role="tabpanel" id="tab-origin-[\s\S]*?<\/section>)+/,
  '\n' + newTabPanels
);

// 14. Replace the JS ORIGIN_BUCKETS rendering loop with our category loop.
const newRow2Js = `
  const ROW2_CATEGORIES = ${JSON.stringify(ROW2_CATEGORIES, null, 2)};
  for (const c of ROW2_CATEGORIES) {
    const members = c.members.map(id => PIECES.find(p => p.id === id)).filter(Boolean);
    const grid = document.getElementById('grid-cat-' + c.id);
    if (grid) {
      if (members.length) {
        grid.innerHTML = members.map(p => renderCard({ ...p, _idSuffix: '--cat-' + c.id })).join('');
      } else {
        grid.innerHTML = '<p class="empty-tab">No pieces in this category yet.</p>';
      }
      document.getElementById('count-cat-' + c.id).textContent = members.length;
    }
  }`;

codexHtml = codexHtml.replace(
  /\/\/ Bucket pieces by origin and render each origin tab's grid\.[\s\S]*?for \(const b of ORIGIN_BUCKETS\) \{[\s\S]*?document\.getElementById\('count-origin-' \+ b\.id\)\.textContent = byOrigin\[b\.id\]\.length;[\s\S]*?\n  \}/,
  '// Codex second-row categories (multi-membership).' + newRow2Js
);

// 15. Update the filter logic to count category tabs instead of origin tabs.
codexHtml = codexHtml.replace(
  /const visibleOrigin = Object\.fromEntries\(ORIGIN_BUCKETS\.map\(b => \[b\.id, 0\]\)\);/,
  'const visibleCat = Object.fromEntries(ROW2_CATEGORIES.map(c => [c.id, 0]));'
);
codexHtml = codexHtml.replace(
  /} else if \(gid && gid\.startsWith\('grid-origin-'\)\) \{\s*const b = gid\.replace\('grid-origin-', ''\);\s*if \(visibleOrigin\[b\] !== undefined\) visibleOrigin\[b\]\+\+;/,
  `} else if (gid && gid.startsWith('grid-cat-')) {
          const c = gid.replace('grid-cat-', '');
          if (visibleCat[c] !== undefined) visibleCat[c]++;`
);
codexHtml = codexHtml.replace(
  /for \(const b of ORIGIN_BUCKETS\) \{\s*document\.getElementById\('count-origin-' \+ b\.id\)\.textContent = visibleOrigin\[b\.id\];\s*\}/,
  `for (const c of ROW2_CATEGORIES) {
      document.getElementById('count-cat-' + c.id).textContent = visibleCat[c.id];
    }`
);

// 16. Relations data — promote/demote/invert mappings for codex cards.
const CHAINS = [
  ['pawn','sergeant','arrow-pawn'],
  ['ferz','elephant-modern','high-priestess'],
  ['wazir','war-machine','champion'],
  ['bishop','dragon-horse','archbishop'],
  ['rook','dragon-king','chancellor'],
  ['knight','gnu','buffalo'],
  ['kirin','kirin-plus','kirin-plus-plus'],
  ['alibaba','bodyguard','queen']
];
const INVERSIONS_PAIRS = [
  ['wazir','ferz'], ['bishop','rook'], ['pawn','berolina'],
  ['sergeant','inv-sergeant'], ['arrow-pawn','inv-arrow-pawn'],
  ['dragon-horse','dragon-king'], ['kirin','squirrel'],
  ['elephant-modern','war-machine'], ['archbishop','chancellor'],
  ['kirin-plus','inv-kirin-plus'], ['high-priestess','champion'],
  ['banshee','raven'], ['kirin-plus-plus','inv-kirin-plus-plus'],
  ['gryphon','manticore']
];
const PROMOTE = {}, DEMOTE = {}, INVERT = {};
for (const chain of CHAINS) {
  for (let i = 0; i < chain.length; i++) {
    if (i + 1 < chain.length) PROMOTE[chain[i]] = chain[i + 1];
    if (i > 0) DEMOTE[chain[i]] = chain[i - 1];
  }
}
for (const [a, b] of INVERSIONS_PAIRS) { INVERT[a] = b; INVERT[b] = a; }

// 17. Inject relations CSS + extend renderCard to add the relations block under the diagram.
const relationsCss = `
    /* Relations block on codex cards */
    .relations { display: flex; flex-direction: column; gap: 8px; margin: 10px 0 0 0; padding: 10px; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; }
    .relation-row { display: flex; align-items: center; gap: 10px; font-size: 12px; }
    .relation-label { color: var(--text-soft); width: 80px; flex-shrink: 0; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; font-size: 10px; }
    .relation-target { display: flex; align-items: center; gap: 8px; }
    .relation-mini { width: 64px; height: 64px; flex-shrink: 0; border-radius: 3px; overflow: hidden; background: var(--sq-light); border: 1px solid var(--border); }
    .relation-mini svg { display: block; width: 100%; height: 100%; }
    .relation-name { font-weight: 500; color: var(--text); }
`;
codexHtml = codexHtml.replace(
  /\.card-desc \{/,
  relationsCss + '\n    .card-desc {'
);

const relationsJs = `
  const PROMOTE_OF = ${JSON.stringify(PROMOTE)};
  const DEMOTE_OF = ${JSON.stringify(DEMOTE)};
  const INVERT_OF = ${JSON.stringify(INVERT)};
  function renderMiniRelation(targetId, label) {
    const target = PIECES.find(p => p.id === targetId);
    if (!target) return '';
    return \`<div class="relation-row">
      <span class="relation-label">\${label}</span>
      <div class="relation-target">
        <div class="relation-mini">\${renderBoard(target)}</div>
        <span class="relation-name">\${target.name}</span>
      </div>
    </div>\`;
  }
  function renderRelations(piece) {
    const promote = PROMOTE_OF[piece.id];
    const demote = DEMOTE_OF[piece.id];
    const invert = INVERT_OF[piece.id];
    if (!promote && !demote && !invert) return '';
    const rows = [
      demote ? renderMiniRelation(demote, 'Demote to') : '',
      promote ? renderMiniRelation(promote, 'Promote to') : '',
      invert ? renderMiniRelation(invert, 'Invert to') : ''
    ].filter(Boolean).join('');
    return '<div class="relations">' + rows + '</div>';
  }
`;
// Inject relations data + helper before renderCard. (The encyclopedia template
// no longer has the inline renderer block, so we anchor on renderCard itself.)
codexHtml = codexHtml.replace(
  /  function renderCard\(piece\) \{/,
  relationsJs + '\n  function renderCard(piece) {'
);

// Inject the relations block call inside renderCard's returned template.
codexHtml = codexHtml.replace(
  /<div class="card-board">\$\{renderBoard\(piece\)\}<\/div>/,
  '<div class="card-board">${renderBoard(piece)}</div>\n        ${renderRelations(piece)}'
);

// 18. Mark empty category tabs as is-empty (family tabs already get the is-empty
// flag in the encyclopedia template, so we only need to patch the new category loop).
codexHtml = codexHtml.replace(
  /document\.getElementById\('count-cat-' \+ c\.id\)\.textContent = members\.length;\s*\}\s*\}/,
  `document.getElementById('count-cat-' + c.id).textContent = members.length;
      const btn = document.getElementById('tabbtn-cat-' + c.id);
      if (btn && members.length === 0) btn.classList.add('is-empty');
    }
  }`
);

// 19. Make the betza-chip clickable: open betza.html with the notation as URL param.
codexHtml = codexHtml.replace(
  '<span class="betza-chip"><span class="betza-chip-label">Betza</span>${piece.betza}</span>',
  '<a class="betza-chip" href="betza.html?b=${encodeURIComponent(piece.betza)}" target="_blank" rel="noopener" title="Open in Betza sandbox"><span class="betza-chip-label">Betza</span>${piece.betza}</a>'
);
codexHtml = codexHtml.replace(
  '      font-size: 12px;\n    }\n    .betza-chip-label {',
  '      font-size: 12px;\n    }\n    a.betza-chip { text-decoration: none; cursor: pointer; transition: border-color 0.12s ease, color 0.12s ease; }\n    a.betza-chip:hover { border-color: var(--accent); color: var(--accent); }\n    .betza-chip-label {'
);

fs.writeFileSync(outputPath, codexHtml);
console.log(`Wrote codex.html (${codexHtml.length} bytes, ${CODEX_IDS.length} pieces, 6 categories, relations on every applicable card)`);
