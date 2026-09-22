/** Final runtime regressions. Local DOM/provider doubles; no advertising network. */
'use strict';
const assert = require('node:assert/strict');
const { makeEnvironment, boot, mountAd, config } = require('./helpers/runtime-harness');
let passed = 0;
const failures = [];
function test(name, fn) {
  try { fn(); passed++; console.log('PASS ' + name); }
  catch (error) { failures.push(name + ': ' + error.stack); console.error('FAIL ' + name + ': ' + error.message); }
}
function flush(env) {
  for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach(fn => fn());
  assert.equal(env.frames.length, 0, 'reconciliation must settle without polling');
}
function scene(options, configure) {
  const cfg = config(null, { mobile: { request_spacing_ms: 90 }, desktop: { request_spacing_ms: 70 } });
  const env = makeEnvironment(cfg, Object.assign({ scrollY: 0, now: 1000, innerWidth: 360, innerHeight: 800,
    articleWords: 2600, plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6,
    contentHeight: 30000, documentHeight: 31000 }, options || {}));
  if (configure) configure(env);
  return { env, runtime: boot(env) };
}
function place(s, spec) {
  return mountAd(s.runtime, s.env, Object.assign({ placement: 'article-a1', slot: 'final-a1',
    surface: 'article', tier: 'standard', top: 100, height: 250, near: 1200 }, spec || {}));
}

test('Optimized empty critical units do not masquerade as a strong fill signal', () => {
  const s = scene();
  ['topscroll', 'site-masthead'].forEach((placement, i) => place(s, {
    placement, slot: 'optimized-' + i, top: i * 400, critical: true, inContent: false,
    surface: placement, tier: 'reach', answer: 'unfill-optimized'
  }));
  flush(s.env);
  const view = s.runtime.inspect();
  assert.equal(view.engine.article.auctionSignal, 'weak');
  assert.ok(view.manual.every(record => record.status === 'unfill-optimized'));
  assert.ok(view.manual.every(record => record.state === 'optimized'));
  assert.equal(s.env.win.adsbygoogle.length, 2);
});

test('Filled responses retain their strong signal and mixed empty responses remain neutral', () => {
  for (const answers of [['filled', 'filled'], ['filled', 'unfill-optimized']]) {
    const s = scene();
    answers.forEach((answer, i) => place(s, { placement: 'critical-' + i, slot: 'signal-' + i,
      top: i * 400, critical: true, inContent: false, surface: 'site-masthead', tier: 'reach', answer }));
    flush(s.env);
    assert.equal(s.runtime.inspect().engine.article.auctionSignal, answers[1] === 'filled' ? 'strong' : 'neutral');
    assert.equal(s.env.win.adsbygoogle.length, 2);
  }
});

test('A past unit-window excess after viewport growth does not veto a distant safe body opportunity', () => {
  const s = scene({ innerWidth: 1440, innerHeight: 900 });
  [100, 900, 1700, 2500].forEach((top, i) => place(s, { placement: 'article-a' + (i + 1), slot: 'past-' + i,
    top, width: 720, height: 250 }));
  flush(s.env);
  for (const y of [700, 1500, 2300]) { s.env.advance(1500); s.env.setScroll(y); flush(s.env); }
  assert.equal(s.env.win.adsbygoogle.length, 4, 'all four earlier requests originally cleared density');
  s.env.win.innerHeight = 2000;
  s.env.advance(1500); s.env.setScroll(5600); flush(s.env);
  const next = place(s, { placement: 'article-a5', slot: 'distant-safe', top: 400, width: 720 });
  flush(s.env);
  const record = s.runtime.inspect().manual.find(item => item.slot === 'distant-safe');
  assert.equal(record.requested, true, 'new opportunity does not participate in the old excessive window: ' + record.state);
  assert.equal(s.env.win.adsbygoogle.length, 5);
  assert.equal(next.hidden, false);
});

test('A candidate that adds a fourth unit to an existing window remains blocked', () => {
  const s = scene({ innerHeight: 1100 });
  [100, 660, 1220].forEach((top, i) => place(s, { placement: 'critical-' + i, slot: 'crowded-' + i,
    surface: 'site-masthead', inContent: false, critical: true, tier: 'reach', top, height: 200 }));
  flush(s.env); s.env.advance(1500); s.env.setScroll(1000); flush(s.env);
  place(s, { placement: 'article-a4', slot: 'fourth-near', top: 780, height: 200 }); flush(s.env);
  const next = s.runtime.inspect().manual.find(item => item.slot === 'fourth-near');
  assert.equal(next.requested, false);
  assert.equal(next.state, 'waiting-content-density');
  assert.equal(s.env.win.adsbygoogle.length, 3);
});

test('Materializing one manual host reconciles changed flow before a silent provider answers', () => {
  const s = scene({ scrollY: 200 }, env => { env.doc.visibilityState = 'hidden'; });
  const first = place(s, { slot: 'flow-first', top: 100, height: 1, answer: '__NO_STATUS__' });
  const next = place(s, { placement: 'article-a2', slot: 'flow-next', top: 400, height: 1, answer: '__NO_STATUS__' });
  // Real getBoundingClientRect() returns a snapshot; later layout must not mutate a cached DOMRect.
  [first, next].forEach(box => { box.getBoundingClientRect = () => Object.assign({}, box.rect); });
  flush(s.env);
  assert.equal(s.runtime.inspect().engine.readerEngaged, true, 'restored scroll position already established engagement');
  const originalPush = s.env.win.adsbygoogle.push;
  s.env.win.adsbygoogle.push = function (value) {
    originalPush.call(this, value);
    if (this.length !== 1) return;
    // The publisher's requested reservation changes normal flow before Google responds.
    first.rect.height = 250; first.rect.bottom = first.rect.top + 250;
    next.rect.top += 350; next.rect.bottom += 350; next._docTop += 350;
  };
  s.env.doc.visibilityState = 'visible'; s.env.doc.dispatchEvent({ type: 'visibilitychange' }); flush(s.env);
  const immediateRequests = s.env.win.adsbygoogle.length;
  s.env.advance(7999); flush(s.env);
  const requestsBeforeTimeout = s.env.win.adsbygoogle.length;
  s.env.advance(1); flush(s.env);
  assert.equal(immediateRequests, 2, 'the next already-visible safe host must not await the 8s response timeout; requests at 7999ms=' + requestsBeforeTimeout);
  assert.equal(s.runtime.inspect().manual[1].requested, true);
  s.env.advance(9000); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2, 'timeout does not refresh either unit');
});

console.log(JSON.stringify({ suite: 'runtime-final-regressions', scenarios: passed + failures.length,
  passed, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { console.error(failures.join('\n\n')); process.exitCode = 1; }
