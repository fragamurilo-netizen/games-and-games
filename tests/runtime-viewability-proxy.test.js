/**
 * Local exposure proxy and creative-origin warm-up.
 *
 * The shared harness deliberately ships no IntersectionObserver, so the
 * exposure clock is never reached by the other suites. This one supplies a
 * minimal observer double and drives the clock directly, on the production
 * runtime file, with no network and no advertising request.
 *
 * What it pins down:
 *   - a LARGE creative (>=242,500 px²) qualifies at the published 30% share,
 *     and an ordinary one still needs 50%;
 *   - pixels hidden behind a recognized account anchor never accumulate local
 *     exposure, matching the usable viewport the delivery path already uses;
 *   - the creative origin is warmed once, on the first request, never earlier
 *     and never twice.
 */
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
}

/**
 * An environment with an IntersectionObserver double and a <head> that records
 * appended connection hints.
 */
function scene(options) {
  const env = makeEnvironment(config(), Object.assign({
    scrollY: 0, now: 1000, innerWidth: 360, innerHeight: 800,
    articleWords: 2600, plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6,
    contentHeight: 30000, documentHeight: 31000
  }, options || {}));

  const observed = [];
  env.win.IntersectionObserver = function IntersectionObserver(callback, init) {
    this.thresholds = (init && init.threshold) || [];
    this.observe = (node) => { observed.push({ node, callback }); };
    this.unobserve = (node) => {
      const i = observed.findIndex(entry => entry.node === node);
      if (i !== -1) observed.splice(i, 1);
    };
    this.disconnect = () => { observed.length = 0; };
    this.takeRecords = () => [];
  };

  const hints = [];
  env.doc.head = {
    appendChild: (node) => { hints.push(node); return node; }
  };
  env.doc.createElement = (tag) => ({ tagName: String(tag).toUpperCase(), rel: '', href: '' });
  const baseQuery = env.doc.querySelector;
  env.doc.querySelector = (selector) => {
    if (String(selector).indexOf('preconnect') !== -1) {
      return hints.find(hint => hint.rel === 'preconnect' && hint.href === 'https://tpc.googlesyndication.com') || null;
    }
    return baseQuery(selector);
  };

  const runtime = boot(env);
  return { env, runtime, hints, observed };
}

/** Report the creative's geometry to the runtime's exposure observer. */
function report(scene, rect) {
  const entry = scene.observed[scene.observed.length - 1];
  assert.ok(entry, 'the runtime must observe a present creative');
  Object.assign(entry.node.rect, rect);
  entry.callback([{ target: entry.node, boundingClientRect: entry.node.rect, intersectionRatio: 1 }]);
}

function placeFilled(s, spec) {
  const box = mountAd(s.runtime, s.env, Object.assign({
    placement: 'site-masthead', slot: 'view-1', surface: 'masthead', tier: 'reach',
    top: 0, height: 250, critical: true, inContent: false, near: 1200
  }, spec || {}));
  flush(s.env);
  return box;
}

/** The creative the runtime is now measuring, as inspect() reports it. */
function exposure(runtime, slot) {
  return runtime.inspect().manual.find(record => record.slot === slot).localViewability;
}

test('A large creative qualifies at the published 30% share', () => {
  const s = scene({ innerWidth: 1280, innerHeight: 900 });
  /* 970x250 is exactly 242,500 px² — the large-creative boundary. */
  placeFilled(s, { slot: 'large-1', width: 970, height: 250 });
  report(s, { top: 725, bottom: 975, height: 250, left: 0, right: 970, width: 970 });

  const before = exposure(s.runtime, 'large-1');
  assert.equal(before.requiredRatio, 0.3, 'a 242,500 px² creative uses the large-format share');
  assert.equal(before.largeCreative, true);
  /* 175 of 250 rows are off the bottom: 30% is on screen, and that is enough. */
  assert.equal(before.qualified, false, 'one continuous second has not elapsed yet');

  s.env.advance(1100);
  assert.equal(exposure(s.runtime, 'large-1').qualified, true, 'the large creative qualifies at 30% for 1s');
});

test('An ordinary creative still needs half of its pixels', () => {
  const s = scene({ innerWidth: 360, innerHeight: 800 });
  placeFilled(s, { slot: 'small-1', width: 336, height: 280 });
  /* 336x280 = 94,080 px²: an ordinary display creative. */
  report(s, { top: 702, bottom: 982, height: 280, left: 0, right: 336, width: 336 });
  assert.equal(exposure(s.runtime, 'small-1').requiredRatio, 0.5);
  s.env.advance(1100);
  assert.equal(exposure(s.runtime, 'small-1').qualified, false, '35% is below the ordinary share');

  report(s, { top: 660, bottom: 940, height: 280, left: 0, right: 336, width: 336 });
  s.env.advance(1100);
  assert.equal(exposure(s.runtime, 'small-1').qualified, true, '50% for a second qualifies');
});

test('Pixels behind the account anchor never become local exposure', () => {
  /* A 110px anchor covers the bottom of an 800px screen, so the reader can only
   * see the top 690px. A creative that sits entirely in the covered strip is
   * fully inside the raw viewport and completely invisible to the reader. */
  const s = scene({ innerWidth: 360, innerHeight: 800, anchorHeight: 110 });
  /* Born inside the covered strip, so the high-water ratio never saw it clear. */
  placeFilled(s, { slot: 'anchored-1', top: 700, width: 336, height: 100 });
  report(s, { top: 700, bottom: 800, height: 100, left: 0, right: 336, width: 336 });

  s.env.advance(1100);
  const covered = exposure(s.runtime, 'anchored-1');
  assert.equal(covered.maxIntersectionRatio, 0, 'covered pixels are not visible pixels');
  assert.equal(covered.qualified, false, 'a creative behind the anchor earns no exposure');
  assert.equal(covered.timeAtLeastRequiredMs, 0);

  /* Lift it clear of the anchor and the same creative qualifies normally. */
  report(s, { top: 300, bottom: 400, height: 100, left: 0, right: 336, width: 336 });
  s.env.advance(1100);
  assert.equal(exposure(s.runtime, 'anchored-1').qualified, true);
});

test('The creative origin is warmed once, on the first request', () => {
  const s = scene();
  assert.equal(s.hints.length, 0, 'no connection is opened before a placement asks for one');
  assert.equal(s.runtime.inspect().evolution.creativeOriginWarmed, false);

  placeFilled(s, { slot: 'warm-1' });
  assert.equal(s.hints.length, 1, 'the first request warms the creative host');
  assert.equal(s.hints[0].rel, 'preconnect');
  assert.equal(s.hints[0].href, 'https://tpc.googlesyndication.com');
  assert.equal(s.hints[0].crossOrigin, undefined, 'the creative arrives credentialed, so the hint must be too');
  assert.equal(s.runtime.inspect().evolution.creativeOriginWarmed, true);

  placeFilled(s, { slot: 'warm-2', placement: 'article-a1', surface: 'article', tier: 'standard', top: 400, critical: false, inContent: true });
  assert.equal(s.hints.length, 1, 'later requests reuse the connection instead of re-hinting');
});

test('Warming is a hint only: it never requests, retries or refreshes a unit', () => {
  const s = scene();
  placeFilled(s, { slot: 'hint-only' });
  /* One host, one push. The hint is a <link>, not an ad call. */
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.hints.every(hint => hint.tagName === 'LINK'), true);
});

test('An anchor that appears mid-read re-measures the clocks without an observer entry', () => {
  /* The anchor watch only starts where a sticky rail exists, which never happens
   * on a phone — exactly where the bottom anchor shows up. Nothing moves the
   * creative, so the exposure observer produces no entry either: the sweep has
   * to notice the usable viewport shrinking on its own. A second, far-below
   * placement keeps the queue alive, which is the state delivery is actually in
   * while the account's anchor appears. */
  const s = scene({ innerWidth: 360, innerHeight: 800, anchorHeight: 0 });
  placeFilled(s, { slot: 'late-anchor', top: 700, width: 336, height: 100 });
  mountAd(s.runtime, s.env, { placement: 'article-a5', slot: 'keeps-queue-alive', surface: 'article',
    tier: 'deep', top: 20000, height: 250, near: 400, predictive: true });
  flush(s.env);
  report(s, { top: 700, bottom: 800, height: 100, left: 0, right: 336, width: 336 });
  s.env.advance(1100);
  assert.equal(exposure(s.runtime, 'late-anchor').qualified, true, 'clear of any anchor, it qualifies');
  assert.equal(s.runtime.inspect().engine.scrollListenersActive, true, 'delivery is still in progress');

  /* The account now displays a 110px anchor over the same pixels. */
  const anchor = { getBoundingClientRect: () => ({ top: 690, bottom: 800, left: 0, right: 360, width: 360, height: 110, x: 0, y: 690 }) };
  s.env.doc.querySelectorAll = (selector) => (String(selector).indexOf('data-anchor-status') !== -1 ? [anchor] : []);

  s.env.setScroll(1);
  flush(s.env);
  assert.equal(s.runtime.inspect().viewport.anchorReservePx, 110, 'the sweep sees the new reserve');

  const before = exposure(s.runtime, 'late-anchor').timeAtLeastRequiredMs;
  s.env.advance(2000);
  assert.equal(exposure(s.runtime, 'late-anchor').timeAtLeastRequiredMs, before,
    'covered pixels stop accumulating local exposure');
});

console.log(JSON.stringify({ suite: 'runtime-viewability-proxy', passed, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { failures.forEach(line => console.error(line)); process.exit(1); }
