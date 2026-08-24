/* Verifies artefacts.html (the map + ledger) plus the nav link on every page.
   Serve first:  python3 -m http.server 8931
   Run:          node tools/verify-artefacts-gallery.js

   Every expectation is derived from the page's own ARTEFACTS, never hardcoded,
   so a data edit cannot produce a false red. */
const { chromium } = require('/tmp/node_modules/playwright');
const BASE = 'http://localhost:8931';
const URL = `${BASE}/artefacts.html`;

(async () => {
  const browser = await chromium.launch();
  const fails = [];
  const ok = (c, m) => { console.log((c ? 'PASS' : 'FAIL') + ' ' + m); if (!c) fails.push(m); };
  const watch = p => {
    const e = [];
    p.on('console', m => { if (m.type() === 'error') e.push(m.text()); });
    p.on('pageerror', x => e.push(String(x)));
    return e;
  };
  const snap = p => p.evaluate(() => ({
    tiers: document.querySelectorAll('.tier').length,
    cells: document.querySelectorAll('.cell').length,
    rows: document.querySelectorAll('.row').length,
    chips: [...document.querySelectorAll('.chip')].map(c => c.dataset.v),
    heads: [...document.querySelectorAll('.tier-hd h3')].map(h => h.textContent)
  }));

  // ---- 1: both themes render clean, and the tokens react to the theme.
  const bg = {};
  for (const theme of ['light', 'dark']) {
    const p = await browser.newPage({ viewport: { width: 1440, height: 950 } });
    const errs = watch(p);
    await p.addInitScript(t => {
      localStorage.setItem('fp-theme', t);
      localStorage.setItem('nokings-view:artefacts', 'rarity');
    }, theme);
    const r = await p.goto(URL);
    await p.waitForTimeout(700);
    ok(r.status() === 200 && errs.length === 0,
      `${theme}: 200 + zero console errors${errs.length ? ' - ' + errs.join(' | ') : ''}`);
    ok(await p.locator('.cell').count() === 180, `${theme}: 180 squares on the map`);
    bg[theme] = await p.evaluate(() => getComputedStyle(document.body).backgroundColor);
    await p.close();
  }
  ok(bg.light !== bg.dark, `body background differs light vs dark (${bg.light} / ${bg.dark})`);

  // ---- 2: nav regression across every page.
  for (const name of ['codex', 'graph', 'promotion', 'fusion', 'inversion', 'betza', 'artefacts', 'encyclopedia/index']) {
    const p = await browser.newPage({ viewport: { width: 1440, height: 950 } });
    const errs = watch(p);
    const r = await p.goto(`${BASE}/${name}.html`);
    await p.waitForTimeout(250);
    const links = await p.locator('nav a[href$="artefacts.html"]').count();
    ok(r.status() === 200 && errs.length === 0 && links === 1,
      `${name}.html: 200, zero console errors, exactly 1 Artefacts nav link (got ${links})`);
    await p.close();
  }

  // Explicit context: the persistence check needs a second page sharing storage.
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 950 } });
  const p = await ctx.newPage();
  await p.addInitScript(() => localStorage.setItem('nokings-view:artefacts', 'rarity'));
  const errs = watch(p);
  await p.goto(URL);
  await p.waitForTimeout(800);

  const exp = await p.evaluate(() => {
    const byR = {}, byB = {};
    ARTEFACTS.forEach(a => {
      byR[a.rarity] = (byR[a.rarity] || 0) + 1;
      a.bonus.forEach(b => byB[b] = (byB[b] || 0) + 1);
    });
    return {
      total: ARTEFACTS.length, byR, byB,
      tags: ARTEFACTS.reduce((n, a) => n + a.bonus.length, 0),
      bonuses: Object.keys(byB).length,
      legendary: byR.Legendary,
      legendaryTags: ARTEFACTS.filter(a => a.rarity === 'Legendary').reduce((n, a) => n + a.bonus.length, 0),
      special: ARTEFACTS.filter(a => a.bonus.includes('Special')).length
    };
  });

  // ---- 3: rarity grouping
  let s = await snap(p);
  ok(s.tiers === 4 && s.cells === exp.total, `rarity view: ${exp.total} squares in 4 grids`);
  ok(s.heads.join() === 'Common,Uncommon,Rare,Legendary', `rarity view: grids in tier order`);
  ok(s.chips.length === exp.bonuses && !s.chips.includes('Legendary'),
    `rarity view: chips filter the other axis, ${exp.bonuses} bonuses`);
  for (const [r, n] of Object.entries(exp.byR)) {
    ok(await p.locator(`.tier[data-r="${r}"] .cell`).count() === n, `rarity view: ${r} grid has ${n} squares`);
  }

  // ---- 4: shade encodes bonus-tag count
  const badLvl = await p.evaluate(() => {
    let bad = 0;
    document.querySelectorAll('.cell').forEach(c => {
      if (+c.dataset.lvl !== ARTEFACTS[+c.dataset.cell].bonus.length) bad++;
    });
    return bad;
  });
  ok(badLvl === 0, `every square's shade matches its bonus-tag count (${badLvl} wrong)`);

  // ---- 5: filtering dims the map instead of shrinking it
  await p.click('.chip[data-v="Special"]');
  await p.waitForTimeout(500);
  let f = await p.evaluate(() => ({
    rows: document.querySelectorAll('.row').length,
    lit: document.querySelectorAll('.cell:not(.is-out)').length,
    cells: document.querySelectorAll('.cell').length,
    count: document.querySelector('#count').innerText.trim()
  }));
  ok(f.rows === exp.special && f.lit === exp.special && f.cells === exp.total,
    `rarity view: bonus Special -> ${exp.special} rows, map keeps all ${exp.total} squares`);
  ok(f.count.startsWith(String(exp.special)), `live count agrees (${f.count})`);
  await p.click('.chip[data-v="Special"]');
  await p.waitForTimeout(400);
  await p.fill('#q', 'booger');
  await p.waitForTimeout(400);
  ok((await snap(p)).rows === 1, 'search "booger" narrows to 1 row');
  await p.fill('#q', '');
  await p.waitForTimeout(400);
  ok((await snap(p)).rows === exp.total, `clearing the search restores ${exp.total} rows`);

  // ---- 6: bonus grouping duplicates by tag
  await p.click('.group button[data-view="bonus"]');
  await p.waitForTimeout(700);
  s = await snap(p);
  ok(s.tiers === exp.bonuses && s.cells === exp.tags,
    `bonus view: ${exp.tags} squares (one per tag, not ${exp.total}) in ${exp.bonuses} grids`);
  ok(s.rows === exp.total, `bonus view: ledger still lists each artefact once (${s.rows})`);
  ok(s.chips.join() === 'Common,Uncommon,Rare,Legendary', `bonus view: chips swap to rarities`);
  const perBonus = await p.evaluate(() => {
    const out = {};
    document.querySelectorAll('.tier').forEach(t =>
      out[t.querySelector('h3').textContent] = t.querySelectorAll('.cell').length);
    return out;
  });
  ok(Object.entries(exp.byB).every(([b, n]) => perBonus[b] === n),
    `bonus view: every grid's count matches the data (Gold ${perBonus.Gold}, Score ${perBonus.Score})`);

  await p.click('.chip[data-v="Legendary"]');
  await p.waitForTimeout(500);
  f = await p.evaluate(() => ({
    rows: document.querySelectorAll('.row').length,
    lit: document.querySelectorAll('.cell:not(.is-out)').length
  }));
  ok(f.rows === exp.legendary && f.lit === exp.legendaryTags,
    `bonus view: rarity Legendary -> ${exp.legendary} rows and ${exp.legendaryTags} undimmed squares`);
  await p.click('.chip[data-v="Legendary"]');
  await p.waitForTimeout(400);

  // ---- 7: clicking a square expands and scrolls to its row
  await p.evaluate(() => document.querySelector('.cell[data-cell="120"]').click());
  await p.waitForTimeout(900);
  const st = await p.evaluate(() => {
    const r = document.querySelector('.row[data-row="120"]'), b = r.getBoundingClientRect();
    return { open: r.open, inView: b.top > 0 && b.bottom < innerHeight };
  });
  ok(st.open && st.inView, 'clicking a square expands its row and scrolls it into view');

  // ---- 8: threads, in the duplicating view
  const geo = () => p.evaluate(() => {
    const d = [...document.querySelectorAll('.threads path')].map(x => x.getAttribute('d') || '').join(' ');
    const bar = document.querySelector('.bar');
    const chrome = document.querySelector('.nk-nav').offsetHeight +
      (getComputedStyle(bar).position === 'sticky' ? bar.offsetHeight : 0);
    let want = 0;
    document.querySelectorAll('.row').forEach(r => {
      const b = r.getBoundingClientRect();
      if (b.bottom > chrome + 4 && b.top < innerHeight - 4)
        want += document.querySelectorAll(`.cell[data-cell="${r.dataset.row}"]`).length;
    });
    const nums = d.match(/-?\d+(\.\d+)?/g) || [];
    let outside = 0;
    for (let i = 0; i < nums.length; i += 2)
      if (+nums[i] < -80 || +nums[i] > innerWidth + 80 || +nums[i + 1] < -80 || +nums[i + 1] > innerHeight + 80) outside++;
    return { d, segs: (d.match(/M/g) || []).length, want, outside };
  });
  await p.evaluate(() => window.scrollBy(0, 600));
  await p.waitForTimeout(700);
  const g1 = await geo();
  ok(g1.segs > 0 && g1.segs === g1.want,
    `one thread per square of every on-screen row (${g1.segs} threads / ${g1.want} squares)`);
  ok(g1.outside === 0, `all thread coordinates inside the viewport (${g1.outside} outside)`);
  await p.evaluate(() => window.scrollBy(0, 900));
  await p.waitForTimeout(600);
  const g2 = await geo();
  ok(g2.d !== g1.d && g2.outside === 0 && g2.segs === g2.want, 'threads redraw on scroll and stay correct');

  // ---- 9: the grouping choice persists
  const fresh = await ctx.newPage();
  await fresh.goto(URL);
  await fresh.waitForTimeout(700);
  ok(await fresh.locator('.group button[data-view="bonus"][aria-pressed="true"]').count() === 1,
    'grouping choice persists into a new page load');
  await fresh.close();

  // ---- 10: the rail fits its slot exactly, and never scrolls internally
  const fit = await p.evaluate(() => {
    const rail = document.querySelector('.rail');
    const rb = rail.getBoundingClientRect(), bb = document.querySelector('.bar').getBoundingClientRect();
    return {
      gap: Math.round(rb.top - bb.bottom), over: Math.round(rb.bottom - innerHeight),
      scrolls: rail.scrollHeight > rail.clientHeight + 1,
      cell: rail.querySelector('.cell').offsetWidth
    };
  });
  ok(fit.gap === 0 && fit.over <= 0, `rail sits flush under the filter bar and inside the viewport (gap ${fit.gap})`);
  ok(!fit.scrolls, 'rail fits without internal scrolling');
  ok(fit.cell <= 16, `squares respect the 16px cap (${fit.cell}px)`);

  // ---- 11: dots engage when small, and un-engage when the viewport grows
  await p.setViewportSize({ width: 1280, height: 720 });
  await p.waitForTimeout(800);
  const dense = await p.evaluate(() => ({
    dense: document.querySelector('.rail').hasAttribute('data-dense'),
    cell: document.querySelector('.cell').offsetWidth
  }));
  ok(dense.dense, `cramped bonus view switches to dots (${dense.cell}px)`);
  await p.setViewportSize({ width: 1600, height: 1200 });
  await p.waitForTimeout(900);
  const back = await p.evaluate(() => ({
    dense: document.querySelector('.rail').hasAttribute('data-dense'),
    cell: document.querySelector('.cell').offsetWidth
  }));
  ok(!back.dense && back.cell > 12, `growing the viewport returns to ${back.cell}px squares (no dense latch)`);

  ok(errs.length === 0, `interaction run: zero console errors${errs.length ? ' - ' + errs.join(' | ') : ''}`);
  await ctx.close();

  // ---- 12: reduced motion must not hide anything
  const rmCtx = await browser.newContext({ viewport: { width: 1440, height: 950 }, reducedMotion: 'reduce' });
  const rm = await rmCtx.newPage();
  await rm.goto(URL);
  await rm.waitForTimeout(600);
  const op = await rm.evaluate(() => [
    getComputedStyle(document.querySelector('.row')).opacity,
    getComputedStyle(document.querySelector('.cell')).opacity]);
  ok(await rm.locator('.row').count() === exp.total && op[0] === '1' && op[1] === '1',
    `reduced motion: ${exp.total} rows at full opacity`);
  await rmCtx.close();

  // ---- 13: phone. Map stays beside the ledger; nav collapses to a burger.
  const m = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const mErrs = watch(m);
  await m.goto(URL);
  await m.waitForTimeout(700);
  const mob = await m.evaluate(() => {
    const rail = document.querySelector('.rail'), cell = document.querySelector('.cell');
    return {
      over: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      pos: getComputedStyle(rail).position,
      railW: Math.round(rail.getBoundingClientRect().width),
      cell: cell.offsetWidth,
      dense: rail.hasAttribute('data-dense'),
      scrolls: rail.scrollHeight > rail.clientHeight + 1,
      threads: [...document.querySelectorAll('.threads path')].map(x => x.getAttribute('d')).join(''),
      navH: document.querySelector('.nk-nav').offsetHeight,
      navToken: getComputedStyle(document.documentElement).getPropertyValue('--nav-h').trim(),
      burger: getComputedStyle(document.getElementById('burger')).display,
      menuOpen: getComputedStyle(document.getElementById('nk-menu')).display !== 'none',
      barH: Math.round(document.querySelector('.bar').getBoundingClientRect().height)
    };
  });
  ok(mob.over <= 0, `390px: no horizontal overflow (delta ${mob.over}px)`);
  ok(mob.pos === 'sticky' && mob.railW <= 70, `390px: thin ${mob.railW}px rail stays pinned beside the ledger`);
  ok(mob.dense && mob.cell <= 11 && !mob.scrolls, `390px: ${mob.cell}px dots, no internal scroll`);
  ok(!!mob.threads, '390px: threads still drawn, columns are still side by side');
  ok(mob.burger !== 'none' && !mob.menuOpen, '390px: burger shown, menu closed by default');
  ok(mob.navH < 80 && mob.navToken === mob.navH + 'px',
    `390px: header is one row and --nav-h is measured (${mob.navToken})`);
  ok(mob.barH < 120, `390px: filter bar is compact (${mob.barH}px)`);

  await m.click('#burger');
  await m.waitForTimeout(400);
  const open = await m.evaluate(() => ({
    links: document.querySelectorAll('#nk-menu[data-open] .nk').length,
    expanded: document.getElementById('burger').getAttribute('aria-expanded'),
    over: document.documentElement.scrollWidth - document.documentElement.clientWidth
  }));
  ok(open.links === 8 && open.expanded === 'true' && open.over <= 0,
    '390px: burger opens all 8 links with no overflow');
  await m.keyboard.press('Escape');
  await m.waitForTimeout(300);
  ok(await m.evaluate(() => document.getElementById('burger').getAttribute('aria-expanded')) === 'false',
    '390px: Escape closes the menu');
  ok(mErrs.length === 0, `390px: zero console errors${mErrs.length ? ' - ' + mErrs.join(' | ') : ''}`);
  await m.close();

  // ---- 14: no em dash in the page's own authored chrome. Artefact prose is
  // canonical Notion copy and passes through untouched.
  const c = await browser.newPage({ viewport: { width: 1440, height: 950 } });
  await c.goto(URL);
  await c.waitForTimeout(500);
  const chrome = await c.evaluate(() => [
    document.title,
    document.querySelector('.nk-nav').innerText,
    document.querySelector('.hero').innerText,
    document.querySelector('.bar').innerText,
    document.querySelector('.foot').innerText
  ].join(' '));
  ok(!chrome.includes('—'), 'no em dash in nav, hero, filter bar, title or footer');
  await c.close();

  await browser.close();
  console.log(fails.length ? `\n${fails.length} FAILURES` : '\nALL GREEN');
  process.exit(fails.length ? 1 : 0);
})();
