/** Actual PHP options + production runtime; DOM/CSS media doubles, no network. */
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { El, adBox, makeEnvironment, boot, config } = require('./helpers/runtime-harness');
const php = process.env.GO_TEST_PHP || 'php';
const fixtures = new Map();
let passed = 0;
const failures = [];
function fixture(name) {
  if (!fixtures.has(name)) fixtures.set(name, JSON.parse(execFileSync(php,
    [path.join(__dirname, 'test-masthead-editorial.php'), name, '--json'], { encoding: 'utf8' })));
  return fixtures.get(name);
}
function test(name, fn) { try { fn(); passed++; console.log('PASS ' + name); } catch (e) { failures.push(name + ': ' + e.stack); console.error('FAIL ' + name + ': ' + e.message); } }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach(fn => fn()); }
function matches(query, width) {
  return [...query.matchAll(/\((min|max)-width:(\d+)px\)/g)].every(m => m[1] === 'min' ? width >= +m[2] : width <= +m[2]);
}
function scene(name, width, settings = {}) {
  const f = fixture(name);
  const env = makeEnvironment(config(), { now: 1000, scrollY: 0, innerWidth: width, innerHeight: 900 });
  const queries = [];
  env.win.matchMedia = query => {
    const listeners = new Set();
    const mq = { media: query, matches: matches(query, env.win.innerWidth),
      addEventListener: (event, fn) => listeners.add(fn), removeEventListener: (event, fn) => listeners.delete(fn),
      update() { const value = matches(query, env.win.innerWidth); if (value === mq.matches) return; mq.matches = value; [...listeners].forEach(fn => fn(mq)); } };
    queries.push(mq); return mq;
  };
  env.resize = next => { env.win.innerWidth = next; queries.forEach(mq => mq.update()); flush(env); };
  let consent = !settings.denyConsent;
  env.win.GOAdsConsent = { permitted: () => consent, storagePermitted: () => false };
  env.grant = () => { consent = true; env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(env); };
  const runtime = boot(env);
  const box = adBox({ placement: f.placement, slot: f.unit.slot, tier: 'reach', surface: 'masthead', top: 40,
    height: 132, answer: settings.answer || 'filled' });
  box.parentElement = env.body; env.offBoxes.push(box);
  env.pushTargets.push(box.children[0].content.firstElementChild);
  runtime.mount(box, Object.assign({}, f.options, { gate: !!settings.denyConsent })); flush(env);
  return { env, runtime, box, f };
}

for (const name of ['review', 'critica', 'especial', 'pack', 'legacy-review', 'legacy-critica', 'legacy-special']) {
  test(name + ': 1101+ remains inert; all widths through 1100 remain eligible', () => {
    for (const width of [1101, 1366, 1920]) {
      const s = scene(name, width);
      assert.equal(s.env.win.adsbygoogle.length, 0, 'no desktop push at ' + width);
      assert.equal(s.box.children[0].tagName, 'TEMPLATE');
      assert.equal(s.runtime.inspect().manual[0].state, 'ineligible-viewport');
      for (let i = 0; i < 5; i++) { s.env.advance(1000); s.env.onScroll(); flush(s.env); }
      assert.equal(s.env.win.adsbygoogle.length, 0, 'scroll/time never bypasses media gate');
    }
    for (const width of [360, 767, 768, 1100]) {
      const s = scene(name, width);
      assert.equal(s.env.win.adsbygoogle.length, 1, 'one eligible push at ' + width);
    }
  });
}
test('The emitted CSS removes only the unrequested desktop wrapper and uses the same breakpoint', () => {
  for (const name of ['review', 'critica', 'especial', 'pack', 'review-breakpoint']) {
    const f = fixture(name);
    const guard = f.html.match(/<style>@media\(min-width:(\d+)px\)\{body\.go-verge \.go-ad-slot--site-masthead:not\(\[data-go-ad-requested="1"\]\)\{([^}]+)\}\}<\/style>/);
    assert.ok(guard, 'scoped rule precedes host: ' + name);
    assert.equal(+guard[1], f.desktopMin);
    assert.match(guard[2], /display:none;min-block-size:0;margin-block:0;padding-block:0/);
    assert.equal(f.html.indexOf('<style>'), 0);
    assert.equal(matches(f.options.media, f.desktopMin), false);
    assert.equal(matches(f.options.media, f.desktopMin - 1), true);
  }
});
test('Desktop to mobile requests once; return to desktop preserves the served node/iframe', () => {
  const s = scene('review', 1440);
  s.env.resize(390);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  const ins = s.box.children.find(node => node.tagName === 'INS');
  const iframe = new El('iframe', { id: 'google_ads_iframe_fixture', width: '300', height: '100' });
  ins.appendChild(iframe);
  s.env.resize(1440); s.env.resize(390);
  s.runtime.mount(s.box, s.f.options); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.box.children.find(node => node.tagName === 'INS'), ins);
  assert.equal(ins.children[0], iframe);
  assert.equal(s.box.getAttribute('data-go-ad-requested'), '1');
  assert.equal(s.box.hidden, false);
});
test('Denied consent remains inert on mobile; granting on desktop cannot bypass format restriction', () => {
  const s = scene('critica', 390, { denyConsent: true });
  assert.equal(s.env.win.adsbygoogle.length, 0);
  assert.equal(s.runtime.inspect().manual[0].state, 'waiting-consent');
  s.env.resize(1440); s.env.grant();
  assert.equal(s.env.win.adsbygoogle.length, 0);
  s.env.resize(390);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});
test('Unfilled and silent mobile responses are never retried through resize', () => {
  for (const answer of ['unfilled', '__NO_STATUS__']) {
    const s = scene('especial', 390, { answer });
    s.env.resize(1440); s.env.advance(10000); s.env.resize(390);
    assert.equal(s.env.win.adsbygoogle.length, 1, answer);
  }
});
test('A filtered 1281 desktop breakpoint governs the CSS and the runtime', () => {
  assert.equal(scene('review-breakpoint', 1280).env.win.adsbygoogle.length, 1);
  assert.equal(scene('review-breakpoint', 1281).env.win.adsbygoogle.length, 0);
});
test('Existing explicit mobile-disable setting is preserved without widening eligibility', () => {
  assert.equal(scene('review-mobile-disabled', 767).env.win.adsbygoogle.length, 0);
  assert.equal(scene('review-mobile-disabled', 768).env.win.adsbygoogle.length, 1);
  assert.equal(scene('review-mobile-disabled', 1100).env.win.adsbygoogle.length, 1);
  assert.equal(scene('review-mobile-disabled', 1101).env.win.adsbygoogle.length, 0);
});
test('News, guide, archives, games and home retain their prior desktop requests', () => {
  for (const name of ['news', 'guide', 'news-stale-review', 'archive', 'games', 'home']) {
    assert.equal(scene(name, 1440).env.win.adsbygoogle.length, 1, name);
  }
  assert.equal(scene('home', 390).env.win.adsbygoogle.length, 0, 'home remains desktop only');
});
console.log(JSON.stringify({ suite: 'runtime-masthead-editorial', passed, failed: failures.length, failures }));
if (failures.length) process.exitCode = 1;
