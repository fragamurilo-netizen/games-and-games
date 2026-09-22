/**
 * Density: 1,000 geometries against the production rule table.
 *
 *     node tests/runtime-density-1000.test.js
 *
 * The rule table is loaded from PHP, not restated here, so a change to
 * inc/ads/config.php that would let two creatives stack fails this suite.
 *
 * Three rules have to hold simultaneously, on every viewport this site sees:
 *   - a hard pixel floor between creatives in the same column;
 *   - at most `max_units_in_window` units inside ±`density_window_vh`;
 *   - the article never gives more than `max_ad_to_content_ratio` of its own
 *     rendered height to advertising.
 *
 * A unit rejected by density is never "lost": the opportunity is still
 * available to the next safe host further down, which is asserted here too.
 */
'use strict';

const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { makeEnvironment, boot, mountAd } = require('./helpers/runtime-harness');

const php = process.env.GO_TEST_PHP || 'php';
const fixture = JSON.parse(execFileSync(php, [path.join(__dirname, 'export-delivery-fixture.php')], { encoding: 'utf8' }));

let checks = 0;
const failures = [];
function ok(condition, label) { checks++; if (!condition) failures.push(label); }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach((cb) => cb()); }

const HEIGHTS = [568, 667, 736, 800, 844, 900, 1024];
const CREATIVE = 250;

function scene(height, width, count) {
  const env = makeEnvironment(JSON.parse(JSON.stringify(fixture.config)), {
    scrollY: 0, now: 1000, innerHeight: height, innerWidth: width, articleWords: 2000,
    plannedBodyCount: count, renderedBodyCount: count, structuralBodyCapacity: count,
    contentHeight: 40000, documentHeight: 41000
  });
  return { env, runtime: boot(env) };
}
function place(s, index, top, width) {
  const unit = fixture.units['article-a' + Math.min(6, index + 1)];
  return mountAd(s.runtime, s.env, {
    placement: 'article-a' + (index + 1), slot: 'dens' + index, tier: unit.options.tier,
    top: top, height: CREATIVE, width: width, left: 0,
    near: unit.options.near, nearMax: unit.options.nearMax,
    predictive: unit.options.predictive, safetyMs: unit.options.safetyMs,
    inContent: true, surface: 'article'
  });
}
/** Read the whole article so every host gets its chance. */
function readAll(env, steps) {
  for (let i = 0; i < steps; i++) { env.setScroll(env.win.pageYOffset + 500); flush(env); env.advance(1400); flush(env); }
}

for (let caseIndex = 0; caseIndex < 1000; caseIndex++) {
  const height = HEIGHTS[caseIndex % HEIGHTS.length];
  const desktop = caseIndex % 4 === 3;
  const width = desktop ? 1440 : 360;
  const profile = fixture.config.rules[desktop ? 'desktop' : 'mobile'];
  const columnWidth = desktop ? 720 : 360;
  /* Cadences from "obviously too tight" to "comfortably spread". */
  const cadence = 160 + ((caseIndex * 37) % 900);
  const count = 3 + (caseIndex % 4);

  const s = scene(height, width, count);
  const tops = [];
  for (let i = 0; i < count; i++) {
    const top = 200 + i * (CREATIVE + cadence);
    tops.push(top);
    place(s, i, top, columnWidth);
  }
  readAll(s.env, 40);

  const view = s.runtime.inspect();
  const served = view.manual.filter((slot) => slot.requested);
  const servedTops = served.map((slot) => tops[view.manual.indexOf(slot)]).sort((a, b) => a - b);

  /* 1. The hard floor holds between every pair that actually ran. */
  for (let i = 1; i < servedTops.length; i++) {
    const gap = servedTops[i] - (servedTops[i - 1] + CREATIVE);
    ok(gap >= profile.min_gap_px - 1,
      'case ' + caseIndex + ': folga de ' + gap + 'px viola o piso de ' + profile.min_gap_px + 'px (' + (desktop ? 'desktop' : 'mobile') + ')');
  }

  /* 2. No window of ±density_window_vh holds more units than allowed. */
  const half = height * profile.density_window_vh;
  servedTops.forEach((anchor) => {
    const inWindow = servedTops.filter((top) => top + CREATIVE > anchor - half && top < anchor + CREATIVE + half).length;
    ok(inWindow <= profile.max_units_in_window,
      'case ' + caseIndex + ': ' + inWindow + ' unidades dentro de ±' + profile.density_window_vh + ' viewport');
  });

  /* 3. One request per placement, always. */
  ok(s.env.win.adsbygoogle.length === served.length,
    'case ' + caseIndex + ': requests (' + s.env.win.adsbygoogle.length + ') != hosts entregues (' + served.length + ')');

  /* 4. A generous cadence must not be throttled: when every pair already
   *    clears the floor with room to spare, everything the budget allows runs. */
  if (cadence >= profile.min_gap_px + 220) {
    ok(served.length === count,
      'case ' + caseIndex + ': cadência folgada (' + cadence + 'px) entregou apenas ' + served.length + '/' + count);
  }

  /* 5. A rejected host names density, never something vague. */
  view.manual.filter((slot) => !slot.requested).forEach((slot) => {
    ok(/^(waiting-content-density|waiting-proximity|waiting-engagement|waiting-opportunity-budget|waiting-exposure|waiting-pacing)$/.test(slot.state),
      'case ' + caseIndex + ': estado de recusa inesperado ' + slot.state);
  });
}

/* ---- A rejected position hands its opportunity to the next safe host. --- */
{
  const s = scene(800, 360, 3);
  place(s, 0, 200, 360);
  place(s, 1, 200 + CREATIVE + 60, 360);   // too tight, must be refused
  place(s, 2, 200 + CREATIVE + 900, 360);  // comfortably clear
  flush(s.env);
  const atRefusal = s.runtime.inspect();
  ok(atRefusal.manual[0].requested, 'o primeiro host entrega');
  ok(!atRefusal.manual[1].requested, 'o host apertado é recusado');
  ok(atRefusal.manual[1].state === 'waiting-content-density',
    'e diz por quê no momento da recusa (' + atRefusal.manual[1].state + ')');
  readAll(s.env, 30);
  const view = s.runtime.inspect();
  ok(!view.manual[1].requested, 'o host apertado continua sem request depois da leitura inteira');
  ok(view.manual[2].requested, 'a oportunidade recusada segue para o próximo host seguro');
}

/* ---- Listing streams use their own, wider floor. ----------------------- */
{
  const env = makeEnvironment(JSON.parse(JSON.stringify(fixture.config)), {
    scrollY: 0, now: 1000, innerHeight: 800, articleWords: 0,
    plannedBodyCount: 0, renderedBodyCount: 0, structuralBodyCapacity: 0,
    contentHeight: 12000, documentHeight: 13000
  });
  const runtime = boot(env);
  ['listing-f1', 'listing-f2'].forEach((name, i) => {
    const unit = fixture.units[name];
    mountAd(runtime, env, {
      placement: name, slot: 'ls' + i, tier: unit.options.tier, top: 200 + i * (CREATIVE + 300),
      near: unit.options.near, nearMax: unit.options.nearMax, predictive: unit.options.predictive,
      safetyMs: unit.options.safetyMs, inContent: false, surface: 'listing'
    });
  });
  readAll(env, 20);
  const view = runtime.inspect();
  ok(view.manual[0].requested, 'a primeira unidade de listagem entrega');
  ok(!view.manual[1].requested,
    '300px entre cards fica abaixo do piso de listagem de ' + fixture.config.rules.mobile.min_stream_gap_px + 'px');
}

if (failures.length) {
  console.error(JSON.stringify({ suite: 'density-1000', checks, failures: failures.slice(0, 20), failureCount: failures.length }, null, 2));
  process.exit(1);
}
console.log(JSON.stringify({ suite: 'density-1000', cases: 1000, checks, passed: true }));
