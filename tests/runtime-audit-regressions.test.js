/**
 * Targeted audit regressions. Provider responses are DOM doubles; no network,
 * ad library, real impressions or revenue is created by this suite.
 * GO_RUNTIME_SOURCE=/absolute/original.js demonstrates the defects pre-patch.
 */
'use strict';

const assert = require('node:assert/strict');
const { El, adBox, makeEnvironment, boot, mountAd, config } = require('./helpers/runtime-harness');
let assertions = 0;
const failures = [];
function check(name, fn) {
  try { fn(); assertions++; console.log('PASS ' + name); }
  catch (error) { failures.push(name + ': ' + error.message); console.log('FAIL ' + name + ': ' + error.message); }
}
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach(cb => cb()); }
function scene(overrides, cfg) {
  const env = makeEnvironment(cfg || config(), Object.assign({
    scrollY: 0, now: 1000, articleWords: 1800, plannedBodyCount: 2,
    renderedBodyCount: 3, structuralBodyCapacity: 3, documentHeight: 12000
  }, overrides || {}));
  const events = {};
  const add = env.win.addEventListener, remove = env.win.removeEventListener;
  env.win.addEventListener = (type, cb, options) => {
    add(type, cb, options);
    (events[type] = events[type] || []).push({ cb, once: !!(options && options.once) });
  };
  env.win.removeEventListener = (type, cb) => {
    remove(type, cb);
    events[type] = (events[type] || []).filter(entry => entry.cb !== cb);
  };
  env.emit = (type, extra) => {
    (events[type] || []).slice().forEach(entry => {
      entry.cb(Object.assign({ type }, extra || {}));
      if (entry.once) events[type] = (events[type] || []).filter(item => item !== entry);
    });
  };
  return { env, runtime: boot(env) };
}
function body(s, spec) {
  return mountAd(s.runtime, s.env, Object.assign({ placement: 'article-a1', slot: 'audit-a1',
    tier: 'premium', surface: 'article', top: 6000, near: 2500 }, spec || {}));
}

check('Late anchor appearance and dismissal update the useful viewport without a resize', () => {
  const s = scene(); body(s); flush(s.env);
  const before = s.runtime.inspect().manual[0].delivery.restingLeadPx;
  const anchor = new El('ins', { class: 'adsbygoogle', 'data-anchor-status': 'displayed' },
    { top: 710, bottom: 800, height: 90, width: 360, left: 0, right: 360 });
  s.env.doc.querySelectorAll = selector => selector.includes('data-anchor-status') ? [anchor] : [];
  s.env.onScroll(); flush(s.env);
  const present = s.runtime.inspect().manual[0].delivery.restingLeadPx;
  assert.ok(present < before, 'late anchor must reduce resting lead');
  s.env.doc.querySelectorAll = () => [];
  s.env.onScroll(); flush(s.env);
  assert.equal(s.runtime.inspect().manual[0].delivery.restingLeadPx, before);
});

check('A host fully covered by the bottom anchor is not already in range when near=0', () => {
  const s = scene({ anchorHeight: 90 });
  body(s, { top: 750, near: 0 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 0);
  s.env.doc.querySelectorAll = () => [];
  s.env.onScroll(); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

check('Delayed consent reads the stored reader prior; revocation returns a neutral prior', () => {
  const s = scene({ localStorageData: { go_ads_reader_depth_v1: JSON.stringify({ pages: 9, emaDepth: 0.86 }) } });
  assert.equal(s.runtime.inspect().engine.governor.readerPrior, 0.5);
  let consent = true;
  s.env.win.GOAdsConsent = { permitted: () => consent };
  s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(s.env);
  assert.equal(s.runtime.inspect().engine.governor.readerPrior, 0.86);
  consent = false;
  s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(s.env);
  assert.equal(s.runtime.inspect().engine.governor.readerPrior, 0.5);
});

check('Explicit request consent gate releases once after consent and never duplicates a request', () => {
  const s = scene();
  const box = adBox({ placement: 'article-a1', slot: 'audit-consent', tier: 'premium', surface: 'article', top: 150 });
  box.parentElement = s.env.content; s.env.adBoxes.push(box);
  s.env.pushTargets.push(box.children[0].content.firstElementChild);
  s.runtime.mount(box, { near: 1200, tier: 'premium', gate: true }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 0);
  s.env.win.GOAdsConsent = { permitted: () => true };
  for (let i = 0; i < 3; i++) { s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(s.env); }
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

check('Late consent opens Top Scroll session even after its first request, without backfilling active time', () => {
  const s = scene();
  mountAd(s.runtime, s.env, { placement: 'topscroll', slot: 'audit-topscroll', tier: 'reach', surface: 'topscroll',
    top: 20, critical: true, inContent: false, frequencyMax: 6, smartFrequency: true }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  s.env.advance(10000); flush(s.env);
  s.env.win.GOAdsConsent = { permitted: () => true };
  s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(s.env);
  const stored = JSON.parse(s.env.win.sessionStorage.getItem('go_ads_topscroll_session_v1'));
  assert.equal(stored.pages, 1);
  assert.equal(stored.activeMs, 0);
  assert.equal(s.runtime.inspect().manual[0].delivery.smartSessionActiveMs, 0);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

check('BFcache checkpoints update this document without counting it twice; clocks pause while away', () => {
  const s = scene({ storagePermission: true }); body(s); flush(s.env);
  s.env.advance(1000);
  s.env.setScroll(1500); flush(s.env);
  s.env.emit('pagehide', { persisted: true });
  const first = JSON.parse(s.env.win.localStorage.getItem('go_ads_reader_depth_v1'));
  const dwell = s.runtime.inspect().engine.dwellMs;
  s.env.advance(30000);
  assert.equal(s.runtime.inspect().engine.dwellMs, dwell, 'frozen page must not gain active reading time');
  s.env.emit('pageshow', { persisted: true }); flush(s.env);
  s.env.setScroll(6500); flush(s.env); s.env.advance(1000);
  s.env.emit('pagehide', { persisted: false });
  const last = JSON.parse(s.env.win.localStorage.getItem('go_ads_reader_depth_v1'));
  assert.equal(last.pages, first.pages, 'restored DOM is still the same document');
  assert.ok(last.emaDepth > first.emaDepth, 'later depth must not be lost after the first pagehide');
});

check('A hidden interval beyond Top Scroll session idle clears old engagement on return', () => {
  const realNow = Date.now;
  let wall = realNow();
  Date.now = () => wall;
  try {
    const slot = '7792311754';
    const s = scene({ storagePermission: true, localStorageData: {
      ['go_adsense_topscroll_24h_' + slot]: JSON.stringify([1, 2, 3, 4].map(n => wall - n * 1000))
    }, sessionStorageData: {
      go_ads_topscroll_session_v1: JSON.stringify({ pages: 1, activeMs: 1000, updatedAt: wall })
    } });
    mountAd(s.runtime, s.env, { placement: 'topscroll', slot, tier: 'reach', surface: 'topscroll',
      top: 20, critical: true, inContent: false, frequencyMax: 6, smartFrequency: true }); flush(s.env);
    assert.equal(s.runtime.inspect().manual[0].delivery.smartSessionPages, 2);
    s.env.doc.visibilityState = 'hidden'; s.env.doc.dispatchEvent({ type: 'visibilitychange' });
    wall += 1800001; s.env.advance(1800001); flush(s.env);
    s.env.doc.visibilityState = 'visible'; s.env.doc.dispatchEvent({ type: 'visibilitychange' }); flush(s.env);
    assert.equal(s.runtime.inspect().manual[0].delivery.smartSessionPages, 1);
    assert.equal(s.env.win.adsbygoogle.length, 0);
  } finally { Date.now = realNow; }
});

check('A provider response after timeout keeps the original request and admits no refresh', () => {
  const s = scene({ plannedBodyCount: 1, renderedBodyCount: 2, structuralBodyCapacity: 2 });
  const silent = body(s, { top: 100, answer: '__NO_STATUS__' });
  body(s, { placement: 'article-a2', slot: 'audit-a2', top: 850 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  s.env.advance(9000); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2);
  const ins = silent.children.find(node => node.tagName === 'INS');
  ins.setAttribute('data-ad-status', 'filled'); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2);
  assert.equal(s.runtime.inspect().counts.manual.filled, 2);
});

check('Diagnostic waits accumulate foreground duration and identify density subrule without network', () => {
  const cfg = config(); cfg.diagnostics = { gate_timings: true };
  const s = scene({}, cfg);
  body(s, { top: 100 });
  body(s, { placement: 'article-a2', slot: 'audit-density', top: 250 }); flush(s.env);
  s.env.advance(600);
  s.env.doc.visibilityState = 'hidden'; s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  s.env.advance(5000);
  s.env.doc.visibilityState = 'visible'; s.env.doc.dispatchEvent({ type: 'visibilitychange' }); flush(s.env);
  s.env.advance(400);
  const unit = s.runtime.inspect().manual.find(item => item.slot === 'audit-density');
  assert.equal(unit.delivery.densityReason, 'minimum-gap');
  assert.equal(unit.delivery.gateTimings['waiting-content-density'].foregroundMs, 1000);
  assert.ok(unit.delivery.gateTimings['waiting-content-density'].checks >= 1);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

console.log('\n' + assertions + ' passed; ' + failures.length + ' failed. Simulation only.');
if (failures.length) { failures.forEach(f => console.error(f)); process.exitCode = 1; }
