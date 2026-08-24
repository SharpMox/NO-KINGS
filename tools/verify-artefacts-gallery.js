/* Verifies artefacts.html (the gallery) plus the nav link added to every page.
   Serve first:  python3 -m http.server 8931
   Run:          node tools/verify-artefacts-gallery.js

   Expectations are computed from the page's own ARTEFACTS, never hardcoded, so
   a data edit cannot produce a false red. */
const { chromium } = require('/tmp/node_modules/playwright');
const BASE = 'http://localhost:8931';

(async () => {
  const browser = await chromium.launch();
  const fails = [];
  const ok = (cond, msg) => { console.log((cond ? 'PASS' : 'FAIL') + ' ' + msg); if (!cond) fails.push(msg); };

  const watch = page => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', e => errors.push(String(e)));
    return errors;
  };

  // ---- 1 + 2: both themes render, and the tokens actually react to the theme.
  const bg = {};
  for (const theme of ['light', 'dark']) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = watch(page);
    await page.addInitScript(t => localStorage.setItem('fp-theme', t), theme);
    const resp = await page.goto(`${BASE}/artefacts.html`);
    ok(resp.status() === 200, `${theme}: page 200`);
    await page.waitForTimeout(400);
    ok(errors.length === 0, `${theme}: zero console errors${errors.length ? ' - ' + errors.join(' | ') : ''}`);
    const cards = await page.locator('.ax-card').count();
    ok(cards === 180, `${theme}: 180 cards rendered (got ${cards})`);
    ok(await page.locator('img').count() === 0, `${theme}: no <img> emitted while artwork is pending (no 404s)`);
    bg[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    await page.close();
  }
  ok(bg.light !== bg.dark, `body background differs light vs dark (${bg.light} / ${bg.dark})`);

  // ---- 3: nav regression across every page.
  const pages = ['codex', 'graph', 'promotion', 'fusion', 'inversion', 'betza', 'artefacts', 'encyclopedia/index'];
  for (const p of pages) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = watch(page);
    const resp = await page.goto(`${BASE}/${p}.html`);
    await page.waitForTimeout(250);
    const links = await page.locator('nav a[href$="artefacts.html"]').count();
    ok(resp.status() === 200 && errors.length === 0 && links === 1,
      `${p}.html: 200, zero console errors, exactly 1 Artefacts nav link (got ${links})`);
    await page.close();
  }

  const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
  const errors = watch(page);
  await page.goto(`${BASE}/artefacts.html`);
  await page.waitForTimeout(300);

  const exp = await page.evaluate(() => ({
    total: ARTEFACTS.length,
    legendary: ARTEFACTS.filter(a => a.rarity === 'Legendary').length,
    passive: ARTEFACTS.filter(a => a.type === 'Passive').length,
    special: ARTEFACTS.filter(a => a.bonus.includes('Special')).length,
    legendaryPassive: ARTEFACTS.filter(a => a.rarity === 'Legendary' && a.type === 'Passive').length,
    bonusClusters: new Set(ARTEFACTS.map(a => a.bonus[0])).size,
    typeClusters: new Set(ARTEFACTS.map(a => a.type)).size,
    rarityClusters: new Set(ARTEFACTS.map(a => a.rarity)).size
  }));

  const shown = () => page.locator('.ax-card').count();
  const countText = () => page.locator('#ax-count').innerText();

  // ---- 4: filters, and the live count agreeing with what is on screen.
  await page.fill('#ax-q', 'booger');
  ok(await shown() === 1, 'search "booger" narrows to 1 card');
  await page.fill('#ax-q', '');
  await page.selectOption('#ax-rarity', 'Legendary');
  ok(await shown() === exp.legendary, `rarity Legendary = ${exp.legendary} cards`);
  ok((await countText()).startsWith(String(exp.legendary)), 'live count matches the rendered cards');
  await page.selectOption('#ax-type', 'Passive');
  ok(await shown() === exp.legendaryPassive, `Legendary + Passive = ${exp.legendaryPassive} cards`);
  await page.click('#ax-reset');
  ok(await shown() === exp.total, `reset restores all ${exp.total}`);
  await page.selectOption('#ax-type', 'Passive');
  ok(await shown() === exp.passive, `type Passive = ${exp.passive} cards`);
  await page.click('#ax-reset');
  await page.selectOption('#ax-bonus', 'Special');
  ok(await shown() === exp.special, `bonus Special = ${exp.special} cards`);
  await page.click('#ax-reset');

  // ---- 5: a filter change stays cheap with all 180 in the DOM.
  const ms = await page.evaluate(() => {
    const el = document.getElementById('ax-rarity');
    const t = performance.now();
    el.value = 'Rare'; el.dispatchEvent(new Event('change'));
    return performance.now() - t;
  });
  ok(ms < 50, `filter change under 50ms (${ms.toFixed(1)}ms)`);
  await page.click('#ax-reset');

  // ---- 6: drawer semantics come from native <dialog>.
  const first = await page.evaluate(() => ({ name: ARTEFACTS[0].name, conspiracy: ARTEFACTS[0].conspiracy }));
  await page.locator('.ax-card .ax-name a').first().click();
  await page.waitForTimeout(350);
  ok(await page.locator('#ax-drawer[open]').count() === 1, 'clicking a card opens the drawer');
  const inside = await page.evaluate(() => document.getElementById('ax-drawer').contains(document.activeElement));
  ok(inside, 'focus moves inside the dialog');
  const dText = await page.locator('#ax-drawer').innerText();
  ok(dText.includes(first.name) && dText.includes(first.conspiracy), 'drawer shows the name and the conspiracy');
  ok(await page.locator('#ax-drawer a[href^="https://"]').count() === 1, 'drawer has one external wiki link');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(250);
  ok(await page.locator('#ax-drawer[open]').count() === 0, 'Escape closes the drawer');
  const restored = await page.evaluate(() => document.activeElement.matches('.ax-card .ax-name a'));
  ok(restored, 'focus returns to the originating card link');

  // ---- 7: board view and thread geometry.
  await page.click('#ax-view-board');
  await page.waitForTimeout(400);
  ok(await page.locator('svg.ax-threads').count() === 1, 'exactly one threads svg');
  for (const [dim, expected] of [['bonus', exp.bonusClusters], ['type', exp.typeClusters], ['rarity', exp.rarityClusters]]) {
    await page.selectOption('#ax-cluster', dim);
    await page.waitForTimeout(350);
    const pins = await page.locator('.ax-pin').count();
    const clusters = await page.locator('.ax-cluster').count();
    ok(pins === exp.total && clusters === expected,
      `cluster by ${dim}: ${exp.total} pins in ${expected} clusters (got ${pins} / ${clusters})`);
    const geo = await page.evaluate(() => {
      const d = document.getElementById('ax-thread-path').getAttribute('d') || '';
      const board = document.getElementById('ax-board');
      const nums = d.match(/-?\d+(\.\d+)?/g) || [];
      let outside = 0;
      for (let i = 0; i < nums.length; i += 2) {
        const x = +nums[i], y = +nums[i + 1];
        if (x < 0 || x > board.offsetWidth || y < 0 || y > board.offsetHeight) outside++;
      }
      return { moves: (d.match(/M/g) || []).length, points: nums.length / 2, outside, d };
    });
    ok(geo.moves === expected, `cluster by ${dim}: one polyline per cluster (${geo.moves} M tokens)`);
    ok(geo.points === exp.total, `cluster by ${dim}: every pin is a thread vertex (${geo.points})`);
    ok(geo.outside === 0, `cluster by ${dim}: all thread coordinates are board-local (${geo.outside} outside the box)`);
  }

  // ---- 8: threads re-layout on resize, via ResizeObserver.
  await page.selectOption('#ax-cluster', 'bonus');
  await page.waitForTimeout(300);
  const before = await page.getAttribute('#ax-thread-path', 'd');
  await page.setViewportSize({ width: 900, height: 900 });
  await page.waitForTimeout(500);
  const after = await page.evaluate(() => {
    const d = document.getElementById('ax-thread-path').getAttribute('d') || '';
    const board = document.getElementById('ax-board');
    const nums = d.match(/-?\d+(\.\d+)?/g) || [];
    let outside = 0;
    for (let i = 0; i < nums.length; i += 2) {
      if (+nums[i] < 0 || +nums[i] > board.offsetWidth || +nums[i + 1] < 0 || +nums[i + 1] > board.offsetHeight) outside++;
    }
    return { d, outside };
  });
  ok(before !== after.d && after.outside === 0, 'threads re-layout on resize and stay inside the board box');

  // ---- 9: no horizontal overflow on a phone, in both views and with the drawer open.
  await page.setViewportSize({ width: 375, height: 800 });
  await page.waitForTimeout(400);
  const over = () => page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  ok(await over() <= 0, `board view: no horizontal overflow at 375px (delta ${await over()}px)`);
  await page.click('#ax-view-grid');
  await page.waitForTimeout(300);
  ok(await over() <= 0, `grid view: no horizontal overflow at 375px (delta ${await over()}px)`);
  await page.locator('.ax-card .ax-name a').first().click();
  await page.waitForTimeout(400);
  ok(await over() <= 0, `drawer open: no horizontal overflow at 375px (delta ${await over()}px)`);
  await page.keyboard.press('Escape');

  // ---- 11: no em dash in the page's own authored chrome (artefact prose is
  // canonical Notion copy and passes through untouched).
  const chrome = await page.evaluate(() => [
    document.title,
    document.querySelector('nav').innerText,
    document.querySelector('.ax-hero').innerText,
    document.querySelector('.ax-bar').innerText,
    document.querySelector('.ax-foot').innerText
  ].join(' '));
  ok(!chrome.includes('—'), 'no em dash in nav, hero, filter bar, title or footer');

  ok(errors.length === 0, `interaction run: zero console errors${errors.length ? ' - ' + errors.join(' | ') : ''}`);
  await page.close();

  // ---- 10: reduced motion must not leave the cards stranded at opacity 0.
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, reducedMotion: 'reduce' });
  const rm = await ctx.newPage();
  await rm.goto(`${BASE}/artefacts.html`);
  await rm.waitForTimeout(400);
  const rmCards = await rm.locator('.ax-card').count();
  const rmOpacity = await rm.evaluate(() => getComputedStyle(document.querySelector('.ax-card')).opacity);
  ok(rmCards === 180 && rmOpacity === '1', `reduced motion: 180 cards visible (opacity ${rmOpacity})`);
  await ctx.close();

  await browser.close();
  console.log(fails.length ? `\n${fails.length} FAILURES` : '\nALL GREEN');
  process.exit(fails.length ? 1 : 0);
})();
