const { chromium } = require('/tmp/node_modules/playwright');

(async () => {
  const browser = await chromium.launch();
  const fails = [];
  const ok = (cond, msg) => { console.log((cond ? 'PASS' : 'FAIL') + ' ' + msg); if (!cond) fails.push(msg); };

  for (const theme of ['light', 'dark']) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', e => errors.push(String(e)));
    await page.addInitScript(t => localStorage.setItem('fp-theme', t), theme);
    const resp = await page.goto('http://localhost:8931/artefacts.html');
    ok(resp.status() === 200, `${theme}: page 200`);
    await page.waitForTimeout(300);
    ok(errors.length === 0, `${theme}: zero console errors${errors.length ? ' — ' + errors.join(' | ') : ''}`);
    const rows = await page.locator('.art-row').count();
    ok(rows === 180, `${theme}: 180 rows rendered (got ${rows})`);
    await page.close();
  }

  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto('http://localhost:8931/artefacts.html');
  await page.fill('#search', 'booger');
  ok(await page.locator('.art-row').count() === 1, 'search "booger" narrows to 1 row');
  await page.fill('#search', '');
  await page.selectOption('#rarity', 'Legendary');
  ok(await page.locator('.art-row').count() === 26, 'rarity filter Legendary = 26 rows');
  await page.selectOption('#rarity', '');
  const badLinks = await page.$$eval('.conspiracy-name a', as => as.filter(a => !a.href.startsWith('https://')).length);
  ok(badLinks === 0, 'all 150 conspiracy links are https');
  const statusBadges = await page.locator('.art-row .badge:text-is("REWORK")').count() + await page.locator('.art-row .badge:text-is("BASIC")').count();
  ok(statusBadges === 0, 'no BASIC/REWORK badges left (all 180 KEEP; KEEP renders unbadged)');
  await page.setViewportSize({ width: 375, height: 800 });
  await page.waitForTimeout(200);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  ok(overflow <= 0, `no horizontal overflow at 375px (delta ${overflow}px)`);
  await page.close();

  await browser.close();
  console.log(fails.length ? `\n${fails.length} FAILURES` : '\nALL GREEN');
  process.exit(fails.length ? 1 : 0);
})();
