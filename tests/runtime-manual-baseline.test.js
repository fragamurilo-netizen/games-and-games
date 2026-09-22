/** Stable manual delivery and value-per-request ordering; no ad network. */
'use strict';
const assert = require('node:assert/strict');
const { makeEnvironment, boot, mountAd, adBox, config } = require('./helpers/runtime-harness');
let passed = 0;
const failures = [];
function test(name, fn) {
  try { fn(); passed++; console.log('PASS ' + name); }
  catch (error) { failures.push(name + ': ' + error.stack); console.error('FAIL ' + name + ': ' + error.message); }
}
function flush(env) {
  for (let i = 0; env.frames.length && i < 100; i++) env.frames.splice(0).forEach(fn => fn());
  assert.equal(env.frames.length, 0, 'the queue must settle without polling');
}
function scene(decision, options, beforeBoot) {
  const cfg = config(Object.assign({ generated_at: Math.floor(Date.now() / 1000), model_samples: 3000 }, decision || {}),
    { mobile: { request_spacing_ms: 90 }, desktop: { request_spacing_ms: 70 } });
  cfg.profiles.peak.lookahead_scale = 1.04;
  const env = makeEnvironment(cfg,
    Object.assign({ now: 1000, scrollY: 0, innerWidth: 1440, innerHeight: 1200,
      plannedBodyCount: 1, renderedBodyCount: 2, structuralBodyCapacity: 2,
      articleWords: 2400, contentHeight: 18000, documentHeight: 19000 }, options || {}));
  if (beforeBoot) beforeBoot(env);
  return { env, runtime: boot(env) };
}
function place(s, spec) {
  return mountAd(s.runtime, s.env, Object.assign({ placement: 'article-a1', slot: 'first',
    tier: 'standard', surface: 'article', top: 1350, height: 250, near: 2200, predictive: false }, spec || {}));
}

test('Revenue per request is not discounted by coverage a second time when ordering one advance opportunity', () => {
  const s = scene({ slot_value: { highValue: 1.1, lowValue: 1.0 }, slot_coverage: { highValue: 0.7, lowValue: 1.2 } }, {},
    env => { env.doc.visibilityState = 'hidden'; });
  place(s, { slot: 'highValue', top: 1350 });
  place(s, { placement: 'article-a2', slot: 'lowValue', top: 1850 });
  flush(s.env);
  s.env.doc.visibilityState = 'visible'; s.env.doc.dispatchEvent({ type: 'visibilitychange' }); flush(s.env);
  const view = s.runtime.inspect();
  assert.equal(JSON.stringify(view.manual.filter(r => r.requested).map(r => r.slot)), '["highValue"]');
  assert.equal(view.manual[1].state, 'waiting-opportunity-budget');
  assert.equal(view.manual[0].economics.coverage, 0.7, 'coverage remains available for diagnosis');
  assert.equal(view.manual[1].economics.coverage, 1.2);
  assert.equal(view.manual[0].economics.expectedValue, 1.012);
  assert.equal(view.manual[1].economics.expectedValue, 0.92);
  assert.equal(s.env.win.adsbygoogle.length, 1, 'no additional advance budget');
});

const regimes = [
  ['harvest', 1, 0.70, 1.18], ['supply_deficit', 2, 0.65, 1.25], ['balanced', 0, 1, 1.06],
  ['price_compression', 0, 1.10, 1.04], ['coverage_stress', 0, 1.25, 1.02], ['demand_collapse', 0, 1.15, 1.00],
  ['unknown', 2, 0.55, 2.00], ['manual_fixed', 0, 1, 1]
].map(([regime, supply_bias, pacing_scale, multiplier]) => ({ regime, supply_bias, pacing_scale,
  tier_lookahead: { reach: multiplier, premium: multiplier, standard: multiplier, deep: multiplier, completion: multiplier } }));

test('Legacy global regimes produce the same order and physical request interval on both devices', () => {
  for (const width of [360, 1440]) {
    const runs = regimes.map(input => {
      const s = scene(input, { innerWidth: width, plannedBodyCount: 2, renderedBodyCount: 2, structuralBodyCapacity: 2 });
      place(s, { slot: 'first', top: 1300 });
      place(s, { placement: 'article-a2', slot: 'second', top: 1900 }); flush(s.env);
      assert.equal(s.env.win.adsbygoogle.length, 1);
      for (let ms = 0; ms < 200 && s.env.win.adsbygoogle.length < 2; ms++) { s.env.advance(1); flush(s.env); }
      assert.equal(s.env.win.adsbygoogle.length, 2);
      const view = s.runtime.inspect();
      assert.equal(view.engine.decision.regime, 'manual_fixed');
      assert.equal(view.engine.decision.financialControlsApplied, false);
      assert.equal(view.engine.decision.supplyBias, 0);
      assert.equal(view.engine.decision.pacingScale, 1);
      assert.ok(Object.values(view.engine.decision.tierLookahead).every(value => value === 1));
      const result = view.manual.map(r => ({ slot: r.slot, ms: r.timeToRequestMs, distance: r.delivery.distanceAtRequest }));
      return JSON.stringify(result);
    });
    assert.ok(runs.every(run => run === runs[0]), 'all global regimes must give identical request timing at width ' + width);
    assert.equal(JSON.parse(runs[0])[1].ms, width < 1101 ? 95 : 75, 'base interval plus the existing 5ms wake tolerance');
  }
});

test('Advance expansion remains at 40% plus 18s or 58% depth regardless of the global regime', () => {
  for (const input of regimes) {
    const s = scene(input, { innerHeight: 1000, scrollY: 3900, documentHeight: 11000 });
    place(s, { top: 8000 }); flush(s.env); s.env.advance(20000); flush(s.env);
    assert.notEqual(s.runtime.inspect().engine.governor.state, 'expansion', input.regime + ' must not open at 39%');
    s.env.setScroll(4000); flush(s.env);
    assert.equal(s.runtime.inspect().engine.governor.state, 'expansion', input.regime + ' must not delay 40% plus dwell');
    const deep = scene(input, { innerHeight: 1000, scrollY: 5500, documentHeight: 11000 });
    place(deep, { top: 8000 }); flush(deep.env);
    assert.notEqual(deep.runtime.inspect().engine.governor.state, 'expansion', input.regime + ' must not open at 55% without dwell');
    deep.env.setScroll(5800); flush(deep.env);
    assert.equal(deep.runtime.inspect().engine.governor.state, 'expansion', input.regime + ' opens at 58%');
  }
});

test('Predictive lead follows the same local motion/latency geometry under every global regime', () => {
  const runs = regimes.map(input => {
    const s = scene(input); place(s, { top: 2600, predictive: true }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 0);
    s.env.advance(200); s.env.setScroll(500); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 1);
    const r = s.runtime.inspect().manual[0];
    return JSON.stringify({ requested: r.requested, at: r.timeToRequestMs, lead: r.delivery.dynamicNearAtRequest,
      distance: r.delivery.distanceAtRequest, responseEstimate: r.delivery.responseEstimateMs });
  });
  assert.ok(runs.every(run => run === runs[0]));
});

test('A legacy REST endpoint in cached HTML never causes a per-page GET or a delivery update', () => {
  let fetches = 0;
  const s = scene(regimes[0], {}, env => {
    env.win.GOAdsYieldConfig.regime_endpoint = 'https://example.test/wp-json/go-ads/v1/yield-regime';
    env.win.fetch = () => { fetches++; return Promise.resolve({ ok: true, json: () => Promise.resolve(regimes[5]) }); };
    env.win.requestIdleCallback = callback => { callback(); };
  });
  place(s, { top: 4000 }); flush(s.env); s.env.advance(3600000); flush(s.env);
  assert.equal(fetches, 0);
  assert.equal(s.runtime.inspect().engine.decision.perPageFetch, false);
  assert.equal(s.runtime.inspect().engine.decision.remoteDecisionApplied, false);
});

test('Missing, sampleless, stale and distant-future unit models fall back to neutral values without blocking a visible ad', () => {
  const wall = Math.floor(Date.now() / 1000);
  for (const model of [{ generated_at: 0 }, { generated_at: wall - 86401 }, { generated_at: wall + 301 }, { generated_at: wall, model_samples: 0 }]) {
    const s = scene(Object.assign({ slot_value: { first: 2.6 }, slot_coverage: { first: 0.7 }, slot_viewability: { first: 0.2 }, tier_value: { standard: 2.2 } }, model));
    place(s, { top: 100 }); flush(s.env);
    const view = s.runtime.inspect(), econ = view.manual[0].economics;
    assert.equal(s.env.win.adsbygoogle.length, 1);
    assert.equal(view.engine.decision.fresh, false);
    assert.equal(econ.slotValue, 1); assert.equal(econ.coverage, 1); assert.equal(econ.historicViewability, null);
    assert.equal(econ.expectedValue, 1);
  }
});

test('Valid historical unit priors expire after 24h without a request refresh or a network lookup', () => {
  const originalNow = Date.now;
  let wall = 1800000000000;
  Date.now = () => wall;
  try {
    const s = scene({ generated_at: wall / 1000, slot_value: { first: 1.7 }, slot_coverage: { first: 0.8 }, slot_viewability: { first: 0.4 } });
    place(s, { top: 100 }); flush(s.env);
    let view = s.runtime.inspect();
    assert.equal(view.engine.decision.fresh, true); assert.equal(view.manual[0].economics.slotValue, 1.7);
    wall += 86401000;
    view = s.runtime.inspect();
    assert.equal(view.engine.decision.fresh, false); assert.equal(view.manual[0].economics.slotValue, 1);
    assert.equal(s.env.win.adsbygoogle.length, 1);
    assert.equal(view.engine.decision.freshnessSource, 'unit-model-generation-not-report-capture');
  } finally { Date.now = originalNow; }
});

test('A retained safe reserve can request when reached even if every primary host was rejected by the composer', () => {
  for (const innerWidth of [360, 1440]) {
    const s = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 });
    place(s, { top: 100 }); flush(s.env);
    const view = s.runtime.inspect();
    assert.equal(s.env.win.adsbygoogle.length, 1);
    assert.equal(view.engine.article.bodyBudget, 0, 'no general advance budget is invented');
    assert.equal(view.manual[0].delivery.budgetPath, 'reached-reserve');
    assert.equal(view.manual[0].delivery.reachedReserveReason, 'in-useful-viewport');
    place(s, { placement: 'article-a2', slot: 'extra', top: 850 }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 1, 'one rendered structural position is still the maximum');
  }
});

test('Reserve-only output remains cold away from the reader and cannot bypass missing plan telemetry or capacity', () => {
  for (const innerWidth of [360, 1440]) {
    const cold = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 });
    place(cold, { top: 1500 }); flush(cold.env);
    assert.equal(cold.env.win.adsbygoogle.length, 0, 'in lead range but not reached');
    assert.equal(cold.runtime.inspect().manual[0].state, 'waiting-opportunity-budget');
    for (const [renderedBodyCount, structuralBodyCapacity] of [[0, 1], [1, 0]]) {
      const s = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount, structuralBodyCapacity });
      // The shared DOM double defaults zero capacity to rendered; make the intended telemetry explicit.
      s.env.content.setAttribute('data-go-ad-plan-rendered-body', String(renderedBodyCount));
      s.env.content.setAttribute('data-go-ad-plan-body-capacity', String(structuralBodyCapacity));
      place(s, { top: 100 }); flush(s.env); assert.equal(s.env.win.adsbygoogle.length, 0);
    }
    const noPlan = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 }, env => {
      env.content.removeAttribute('data-go-ad-plan-planned-body'); env.content.removeAttribute('data-go-ad-plan-body-capacity');
    });
    place(noPlan, { top: 100 }); flush(noPlan.env); assert.equal(noPlan.env.win.adsbygoogle.length, 0);
  }
});

test('A reached reserve with no primary still obeys density and delayed consent without duplicate requests', () => {
  for (const innerWidth of [360, 1440]) {
    const crowded = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 });
    place(crowded, { placement: 'site-masthead', slot: 'critical', surface: 'masthead', critical: true, inContent: false, top: 0 });
    place(crowded, { top: 300 }); flush(crowded.env);
    assert.equal(crowded.env.win.adsbygoogle.length, 1);
    assert.equal(crowded.runtime.inspect().manual[1].state, 'waiting-content-density');
    const s = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 });
    let granted = false; s.env.win.GOAdsConsent = { permitted: () => granted };
    const box = adBox({ placement: 'article-a1', slot: 'consent-reserve', surface: 'article', tier: 'standard', top: 100 });
    box.parentElement = s.env.content; s.env.adBoxes.push(box); s.env.pushTargets.push(box.children[0].content.firstElementChild);
    s.runtime.mount(box, { near: 1850, tier: 'standard', gate: true }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 0);
    assert.equal(s.runtime.inspect().manual[0].state, 'waiting-consent');
    granted = true; s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 1);
    s.env.doc.dispatchEvent({ type: 'go:ads-consent-update' }); s.runtime.mount(box, {}); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 1);
  }
});

console.log(JSON.stringify({ suite: 'runtime-manual-baseline', passed, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { console.error(failures.join('\n\n')); process.exitCode = 1; }
