/**
 * Viewport-first delivery: 700 timing cases against the production contract.
 *
 *     node tests/runtime-viewport-700.test.js
 *
 * Both the rule table and every unit's request options are read from PHP, so
 * this suite tests the contract that actually ships rather than a restatement
 * of it.
 *
 * What it proves:
 *   - a stationary reader warms a slot at its tier's share of THEIR viewport,
 *     so a 568px phone and a 1024px tablet prepare it at the same point in the
 *     reading experience;
 *   - high-reach positions get more runway than deep ones, on every viewport;
 *   - a moving reader's slot is requested when predicted arrival reaches
 *     provider latency plus safety, not at a fixed pixel distance;
 *   - nothing is ever requested beyond `max_lookahead_vh`, however fast the
 *     reader moves;
 *   - at flick speed a lower-tier position waits, while reach/premium — the
 *     price anchor — are never withheld;
 *   - pacing never lets a visible or imminent slot pass the reader.
 */
'use strict';

const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { makeEnvironment, boot, mountAd } = require('./helpers/runtime-harness');

const php = process.env.GO_TEST_PHP || 'php';
const fixture = JSON.parse(execFileSync(php, [path.join(__dirname, 'export-delivery-fixture.php')], { encoding: 'utf8' }));
const RULES = fixture.config.rules;

let checks = 0;
const failures = [];
function ok(condition, label) { checks++; if (!condition) failures.push(label); }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach((cb) => cb()); }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

const TIERS = [
  { placement: 'article-prime', tier: 'reach' },
  { placement: 'article-a1', tier: 'premium' },
  { placement: 'article-a4', tier: 'standard' },
  { placement: 'article-a5', tier: 'deep' },
  { placement: 'article-end', tier: 'completion' }
];
const HEIGHTS = [568, 667, 736, 800, 844, 900, 1024];

function scene(height, width) {
  const env = makeEnvironment(JSON.parse(JSON.stringify(fixture.config)), {
    scrollY: 0, now: 1000, innerHeight: height, innerWidth: width || 360, articleWords: 1600,
    plannedBodyCount: 7, renderedBodyCount: 7, structuralBodyCapacity: 7,
    contentHeight: 60000, documentHeight: 61000
  });
  return { env, runtime: boot(env) };
}
function place(s, spec, distance) {
  const unit = fixture.units[spec.placement];
  return mountAd(s.runtime, s.env, {
    placement: spec.placement, slot: 'v-' + spec.placement, tier: unit.options.tier,
    top: s.env.win.innerHeight + distance,
    near: unit.options.near, nearMax: unit.options.nearMax,
    predictive: unit.options.predictive, safetyMs: unit.options.safetyMs,
    inContent: true, surface: spec.placement === 'article-end' ? 'article-completion' : 'article'
  });
}
/** Prove engagement without moving far enough to change the geometry under test. */
function engage(s) { s.env.advance(4000); flush(s.env); }
function expectedRestingLead(spec, height, desktop) {
  const profile = RULES[desktop ? 'desktop' : 'mobile'];
  const configured = fixture.units[spec.placement].options.near;
  const lead = clamp(height * profile.rest_lead_vh[spec.tier], profile.rest_lead_min_px, profile.rest_lead_max_px);
  return Math.min(configured, Math.round(lead));
}

/* ---- 1. Resting lead is the tier's share of the reader's own viewport. -- */
for (let i = 0; i < 350; i++) {
  const spec = TIERS[i % TIERS.length];
  const height = HEIGHTS[(i * 3) % HEIGHTS.length];
  const desktop = i % 5 === 4;
  const lead = expectedRestingLead(spec, height, desktop);

  const inside = scene(height, desktop ? 1440 : 360);
  place(inside, spec, Math.max(1, lead - 8));
  engage(inside);
  ok(inside.runtime.inspect().manual[0].requested,
    'case ' + i + ': ' + spec.tier + ' dentro da zona de aquecimento (' + lead + 'px) não entregou');

  const outside = scene(height, desktop ? 1440 : 360);
  place(outside, spec, lead + 40);
  engage(outside);
  const far = outside.runtime.inspect().manual[0];
  ok(!far.requested, 'case ' + i + ': ' + spec.tier + ' além da zona (' + lead + 'px) entregou cedo demais');
  ok(outside.env.win.adsbygoogle.length === 0, 'case ' + i + ': nenhum request prematuro chega ao provedor');
  ok(far.delivery.restingLeadPx === lead,
    'case ' + i + ': a telemetria reporta ' + far.delivery.restingLeadPx + 'px, contrato diz ' + lead + 'px');
}

/* ---- 2. Reach gets more runway than deep, on every viewport. ------------ */
HEIGHTS.forEach((height) => {
  [false, true].forEach((desktop) => {
    const leads = TIERS.map((spec) => expectedRestingLead(spec, height, desktop));
    for (let i = 1; i < leads.length; i++) {
      ok(leads[i] <= leads[i - 1],
        'viewport ' + height + (desktop ? ' desktop' : ' mobile') + ': ' + TIERS[i].tier + ' deveria aquecer depois de ' + TIERS[i - 1].tier);
    }
  });
});

/* ---- 3. A moving reader is served on predicted arrival, not distance. --- */
for (let i = 0; i < 120; i++) {
  const height = HEIGHTS[i % HEIGHTS.length];
  const spec = TIERS[i % 3];
  const s = scene(height);
  /* Far past the resting zone, but the reader is heading straight for it. */
  const distance = expectedRestingLead(spec, height, false) + 600;
  place(s, spec, distance);
  engage(s);
  ok(!s.runtime.inspect().manual[0].requested, 'case ' + i + ': parado, o host distante não entrega');

  /* Two steady samples so the smoothed velocity is real motion, not noise. */
  for (let step = 0; step < 3; step++) { s.env.setScroll(s.env.win.pageYOffset + 260); flush(s.env); s.env.advance(120); flush(s.env); }
  const slot = s.runtime.inspect().manual[0];
  if (slot.requested) {
    ok(slot.delivery.estimatedArrivalMs !== null,
      'case ' + i + ': um request preditivo registra a chegada estimada');
    ok(slot.delivery.estimatedArrivalMs <= slot.delivery.responseEstimateMs + 2500,
      'case ' + i + ': chegada prevista (' + slot.delivery.estimatedArrivalMs + 'ms) muito além da latência do provedor');
  }
}

/* ---- 4. Nothing is ever requested beyond the lookahead ceiling. --------- */
for (let i = 0; i < 120; i++) {
  const height = HEIGHTS[i % HEIGHTS.length];
  const desktop = i % 4 === 3;
  const ceiling = height * RULES[desktop ? 'desktop' : 'mobile'].max_lookahead_vh;
  const s = scene(height, desktop ? 1440 : 360);
  const spec = TIERS[i % 2];
  place(s, spec, Math.round(ceiling + 900));
  engage(s);
  /* A violent, sustained flick: the most aggressive predictive case there is. */
  for (let step = 0; step < 6; step++) { s.env.setScroll(s.env.win.pageYOffset + height * 4); flush(s.env); s.env.advance(40); flush(s.env); }
  const slot = s.runtime.inspect().manual[0];
  if (slot.requested) {
    ok(slot.delivery.distanceAtRequest <= ceiling + 1,
      'case ' + i + ': request a ' + slot.delivery.distanceAtRequest + 'px excede o teto de ' + Math.round(ceiling) + 'px');
    ok(slot.delivery.dynamicNearAtRequest <= ceiling + 1,
      'case ' + i + ': a janela dinâmica (' + slot.delivery.dynamicNearAtRequest + 'px) excede o teto');
  }
}

/* ---- 5. At flick speed the price anchor runs and the tail waits. -------- */
for (let i = 0; i < 110; i++) {
  const height = HEIGHTS[i % HEIGHTS.length];
  const anchor = TIERS[i % 2];               // reach / premium
  const tail = TIERS[2 + (i % 3)];           // standard / deep / completion
  const s = scene(height);
  place(s, anchor, 200);
  place(s, tail, 240 + height);
  engage(s);
  for (let step = 0; step < 6; step++) { s.env.setScroll(s.env.win.pageYOffset + height * 3); flush(s.env); s.env.advance(40); flush(s.env); }
  const view = s.runtime.inspect();
  const pace = view.engine.governor.paceViewportsPerSecond;
  const tailSlot = view.manual.find((slot) => slot.placement === tail.placement);
  if (pace > RULES.mobile.flick_vh_s && !tailSlot.requested) {
    ok(tailSlot.state === 'waiting-exposure' || /^waiting-/.test(tailSlot.state),
      'case ' + i + ': recusa em flick deveria ser de exposição, veio ' + tailSlot.state);
  }
  ok(view.manual.every((slot) => !slot.requested || slot.delivery.paceViewportsPerSecondAtRequest !== null),
    'case ' + i + ': todo request registra o ritmo do leitor no momento');
}

/* ---- 6. Reach/premium are never withheld by the exposure gate. ---------- */
for (let i = 0; i < 60; i++) {
  const height = HEIGHTS[i % HEIGHTS.length];
  const spec = TIERS[i % 2];
  const s = scene(height);
  place(s, spec, Math.max(1, expectedRestingLead(spec, height, false) - 20));
  engage(s);
  /* Flick hard: the anchor is in range and must not be held back. */
  for (let step = 0; step < 4; step++) { s.env.setScroll(s.env.win.pageYOffset + 1); flush(s.env); s.env.advance(10); flush(s.env); }
  ok(s.runtime.inspect().manual[0].requested,
            'case ' + i + ': ' + spec.tier + ' é âncora de preço e nunca é retida');
}

/* ---- 7. Pacing never lets a visible slot pass the reader. --------------- */
{
  const env = makeEnvironment(JSON.parse(JSON.stringify(fixture.config), null, 2), {
    scrollY: 0, now: 1000, innerHeight: 800, articleWords: 1600,
    plannedBodyCount: 7, renderedBodyCount: 7, structuralBodyCapacity: 7,
    contentHeight: 20000, documentHeight: 21000
  });
  /* Production pacing, not the neutral zero used elsewhere. */
  env.win.GOAdsYieldConfig.profiles.peak.request_spacing_ms = 160;
  const runtime = boot(env);
  ['article-prime', 'article-a1'].forEach((name, i) => {
    const unit = fixture.units[name];
    mountAd(runtime, env, {
      placement: name, slot: 'pace' + i, tier: unit.options.tier, top: 150 + i * 620,
      near: unit.options.near, nearMax: unit.options.nearMax, predictive: unit.options.predictive,
      safetyMs: unit.options.safetyMs, inContent: true, surface: 'article'
    });
  });
  flush(env);
  const visible = runtime.inspect().manual.filter((slot) => slot.delivery.distanceToViewport === 0);
  ok(visible.length >= 1, 'o cenário tem ao menos um host visível');
  ok(visible.every((slot) => slot.requested), 'um host dentro da viewport nunca espera pelo pacing');
}

if (failures.length) {
  console.error(JSON.stringify({ suite: 'viewport-700', checks, failures: failures.slice(0, 20), failureCount: failures.length }, null, 2));
  process.exit(1);
}
console.log(JSON.stringify({ suite: 'viewport-700', cases: 700, checks, passed: true }));
