/**
 * Scroll simulation for pages built by tools/sim/page.php.
 *
 *   NODE_PATH=$(npm root -g) node tools/sim/run.cjs page-a.html [page-b.html ...]
 *
 * A fake adsbygoogle answers every request after a fixed latency, filling
 * 7 of every 8 (deterministic), with a 280px creative (620px for Multiplex).
 * Three readers per page on a 390x844 phone: one leaves at 20% of the
 * document, one at half, one reads to the end, and one skims with smooth
 * flicks to 60%. Reports, per page and reader, what the theme's own
 * runtime requested, what was filled and what met its local 50%/1s proxy.
 * This is a behavioural check of the engine, not a revenue forecast.
 */
const { chromium } = require('playwright');
const path = require('path');

const FAKE = `
(function(){
  var n = 0;
  window.adsbygoogle = { loaded: true, push: function(){
    var ins = Array.prototype.filter.call(document.querySelectorAll('ins.adsbygoogle:not([data-adsbygoogle-status])'), function(x){ return x.isConnected; })[0];
    if (!ins) return;
    ins.setAttribute('data-adsbygoogle-status', 'done');
    var k = ++n, multiplex = ins.getAttribute('data-ad-format') === 'autorelaxed';
    setTimeout(function(){
      if (k % 8 === 0) { ins.setAttribute('data-ad-status', 'unfilled'); return; }
      var h = multiplex ? 620 : 280, f = document.createElement('div');
      f.style.cssText = 'height:' + h + 'px;background:#c9e4ff';
      ins.style.height = h + 'px'; ins.appendChild(f);
      ins.setAttribute('data-ad-status', 'filled');
    }, 700);
  } };
})();`;

async function skim(page, stopAt) {
  /* Discover-style skimming: smooth flicks of ~0.9 screen, a short look, again. */
  for (;;) {
    const pos = await page.evaluate(() => ({ y: scrollY, max: document.documentElement.scrollHeight - innerHeight }));
    if (pos.y >= Math.round(pos.max * stopAt) - 2) break;
    await page.evaluate(() => window.scrollBy({ top: 760, behavior: 'smooth' }));
    await page.waitForTimeout(900);
  }
  await page.waitForTimeout(4000);
  return page.evaluate(() => {
    const r = window.GOAdsRuntime.inspect();
    const rows = r.manual.map((m) => ({ placement: m.placement, surface: m.surface, requested: !!m.requested, status: m.status || '', viewable: !!(m.localViewability && m.localViewability.qualified), state: m.state }));
    return { rows, docHeight: document.documentElement.scrollHeight };
  });
}

async function read(page, stopAt) {
  /* The target is re-read every step: each filled creative makes the document
   * taller, so a target fixed at load would stop the reader short of the end. */
  let sinceDwell = 0;
  for (;;) {
    const pos = await page.evaluate(() => ({ y: scrollY, max: document.documentElement.scrollHeight - innerHeight }));
    if (pos.y >= Math.round(pos.max * stopAt) - 2) break;
    const step = Math.min(110, Math.round(pos.max * stopAt) - pos.y);
    sinceDwell += step;
    await page.evaluate((s) => window.scrollBy(0, s), step);
    await page.waitForTimeout(240);
    if (sinceDwell >= 1400) { sinceDwell = 0; await page.waitForTimeout(1600); }
  }
  await page.waitForTimeout(4000);
  return page.evaluate(() => {
    const r = window.GOAdsRuntime.inspect();
    const rows = r.manual.map((m) => ({ placement: m.placement, surface: m.surface, requested: !!m.requested, status: m.status || '', viewable: !!(m.localViewability && m.localViewability.qualified), state: m.state }));
    return { rows, docHeight: document.documentElement.scrollHeight };
  });
}

(async () => {
  const files = process.argv.slice(2);
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] }).catch(() => chromium.launch());
  const jobs = [];
  for (const file of files) {
    for (const [reader, stopAt] of [['bounces-at-20%', 0.2], ['stops-at-half', 0.5], ['reads-to-end', 1], ['skims-to-60%', 0.6]]) {
      jobs.push((async () => {
        const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
        const page = await context.newPage();
        const errors = [];
        page.on('pageerror', (e) => errors.push(String(e)));
        await page.addInitScript(FAKE);
        await page.goto('file://' + path.resolve(file));
        await page.waitForTimeout(2500);
        const out = reader.startsWith('skims') ? await skim(page, stopAt) : await read(page, stopAt);
        await context.close();
        const req = out.rows.filter((r) => r.requested);
        const filled = req.filter((r) => r.status === 'filled');
        const viewable = filled.filter((r) => r.viewable);
        return { file: path.basename(file), reader, docHeight: out.docHeight, hosts: out.rows.length, requested: req.length, filled: filled.length, viewable: viewable.length, errors, detail: out.rows };
      })());
    }
  }
  const results = await Promise.all(jobs);
  await browser.close();
  for (const r of results) {
    console.log(`${r.file.padEnd(22)} ${r.reader.padEnd(14)} doc=${r.docHeight}px hosts=${r.hosts} requested=${r.requested} filled=${r.filled} viewable(50%/1s)=${r.viewable} errors=${r.errors.length}`);
    if (process.env.SIM_DETAIL) r.detail.forEach((d) => console.log(`    ${d.placement.padEnd(24)} ${d.surface.padEnd(34)} ${d.requested ? 'REQ' : '   '} ${d.status.padEnd(9)} ${d.viewable ? 'VIEW' : '    '} ${d.state}`));
    r.errors.forEach((e) => console.log('    ERROR ' + e));
  }
})();
