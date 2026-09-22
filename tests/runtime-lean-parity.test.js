'use strict';
/**
 * The public copy must be the same engine, only quieter.
 *
 * `go-ads-runtime.lean.js` is what an anonymous reader receives: the generated
 * runtime with inspect(), explain() and the diagnostic snapshot removed, since
 * none of them can be called by anyone but a logged-in operator. That trade is
 * only acceptable while one thing stays true — the copy that decides delivery
 * for the public is byte-for-byte the same decisions as the copy that was
 * audited. A lean build that quietly requested less, or more, would be invisible
 * in production precisely because it is the copy without diagnostics.
 *
 * So this suite drives BOTH generated files through the same scenarios and
 * compares what they DID — requests, order, provider status, reservations —
 * rather than what they report. inspect() is unavailable on the lean side by
 * construction, so every assertion reads the DOM the two runtimes produced.
 */
const fs = require('node:fs');
const path = require('node:path');
const { makeEnvironment, boot, mountAd, config } = require('./helpers/runtime-harness');

const FULL = path.join(__dirname, '..', 'assets', 'js', 'go-ads-runtime.min.js');
const LEAN = path.join(__dirname, '..', 'assets', 'js', 'go-ads-runtime.lean.js');

let pass = 0;
const failures = [];
function ok(condition, label, detail) {
  if (condition) { pass++; console.log('PASS ' + label); return true; }
  failures.push(label + (detail ? ' — ' + detail : ''));
  console.log('FAIL ' + label + (detail ? ' — ' + detail : ''));
  return false;
}
function section(t) { console.log('\n' + '-'.repeat(72) + '\n' + t + '\n' + '-'.repeat(72)); }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach(cb => cb()); }

/** What a placement actually DID, read from the host the runtime left behind. */
function observed(env) {
  return env.adBoxes.concat(env.offBoxes || []).map(function (box) {
    const ins = box.children.find ? null : null;
    return {
      placement: box.getAttribute('data-go-ad-placement'),
      requested: box.getAttribute('data-go-ad-requested'),
      state: box.getAttribute('data-go-ad-state'),
      filled: box.getAttribute('data-go-ad-filled'),
      present: box.getAttribute('data-go-ad-present'),
      empty: box.getAttribute('data-go-ad-empty'),
      hidden: box.hidden === true
    };
  });
}

/**
 * One scenario, run against one generated file.
 *
 * GO_RUNTIME_SOURCE is what the shared harness reads, and it is captured when
 * the harness module is first required — so each variant runs in its own child
 * process, which is also the only way two copies of a runtime that guards on
 * `if (w.GOAdsRuntime) return;` can both be exercised in one suite.
 */
function runScenario(name) {
  const scenarios = {
    /* A full read: critical first, then the body ladder as the reader arrives. */
    'read-through': function (runtime, env) {
      mountAd(runtime, env, { placement: 'topscroll', slot: '1', tier: 'reach', top: 20, near: 900, critical: true, inContent: false });
      mountAd(runtime, env, { placement: 'article-prime', slot: '2', tier: 'reach', top: 1200, near: 1850, predictive: true, surface: 'article' });
      mountAd(runtime, env, { placement: 'article-a1', slot: '3', tier: 'premium', top: 2600, near: 1650, predictive: true, surface: 'article' });
      mountAd(runtime, env, { placement: 'article-a2', slot: '4', tier: 'standard', top: 4200, near: 1450, predictive: true, surface: 'article' });
      flush(env);
      for (let step = 0; step < 8; step++) { env.setScroll(700 * (step + 1)); flush(env); env.advance(400); flush(env); }
    },
    /* An empty response must collapse the same way in both copies. */
    'unfilled-collapse': function (runtime, env) {
      mountAd(runtime, env, { placement: 'article-prime', slot: '11', tier: 'reach', top: 900, near: 1850, predictive: true, surface: 'article', answer: 'unfilled' });
      mountAd(runtime, env, { placement: 'article-a1', slot: '12', tier: 'premium', top: 3000, near: 1650, predictive: true, surface: 'article', answer: 'filled' });
      flush(env);
      for (let step = 0; step < 6; step++) { env.setScroll(800 * (step + 1)); flush(env); env.advance(500); flush(env); }
    },
    /* A silent provider releases its opportunity on the same clock. */
    'silent-provider': function (runtime, env) {
      mountAd(runtime, env, { placement: 'article-prime', slot: '21', tier: 'reach', top: 600, near: 1850, predictive: true, surface: 'article', answer: '__NO_STATUS__' });
      mountAd(runtime, env, { placement: 'article-a1', slot: '22', tier: 'premium', top: 2200, near: 1650, predictive: true, surface: 'article' });
      flush(env);
      env.advance(9000); flush(env);
      for (let step = 0; step < 5; step++) { env.setScroll(800 * (step + 1)); flush(env); env.advance(400); flush(env); }
    },
    /* Density must reject the same candidate in both copies. */
    'density-reject': function (runtime, env) {
      mountAd(runtime, env, { placement: 'article-prime', slot: '31', tier: 'reach', top: 500, near: 1850, predictive: true, surface: 'article' });
      mountAd(runtime, env, { placement: 'article-a1', slot: '32', tier: 'premium', top: 560, near: 1650, predictive: true, surface: 'article' });
      mountAd(runtime, env, { placement: 'article-a2', slot: '33', tier: 'standard', top: 620, near: 1450, predictive: true, surface: 'article' });
      flush(env);
      for (let step = 0; step < 4; step++) { env.setScroll(600 * (step + 1)); flush(env); env.advance(400); flush(env); }
    }
  };
  const env = makeEnvironment(config(), {
    innerHeight: 800, scrollY: 0, plannedBodyCount: 4, renderedBodyCount: 4,
    structuralBodyCapacity: 4, articleWords: 2600, documentHeight: 14000,
    contentHeight: 13000, providerDelayMs: 300, storagePermission: true
  });
  const runtime = boot(env);
  scenarios[name](runtime, env);
  return observed(env);
}

if (process.env.GO_LEAN_SCENARIO) {
  process.stdout.write(JSON.stringify(runScenario(process.env.GO_LEAN_SCENARIO)));
  process.exit(0);
}

section('A cópia pública decide a entrega exatamente como a auditada');

const { execFileSync } = require('node:child_process');
function variant(file, scenario) {
  const out = execFileSync(process.execPath, [__filename], {
    encoding: 'utf8',
    env: Object.assign({}, process.env, { GO_RUNTIME_SOURCE: file, GO_LEAN_SCENARIO: scenario })
  });
  return JSON.parse(out);
}

ok(fs.existsSync(LEAN), 'A cópia pública enxuta existe');
ok(fs.existsSync(FULL), 'A cópia completa existe');
ok(fs.statSync(LEAN).size < fs.statSync(FULL).size, 'A cópia enxuta é menor',
  Math.round(fs.statSync(LEAN).size / 1024) + 'kB vs ' + Math.round(fs.statSync(FULL).size / 1024) + 'kB');

['read-through', 'unfilled-collapse', 'silent-provider', 'density-reject'].forEach(function (scenario) {
  const full = variant(FULL, scenario);
  const lean = variant(LEAN, scenario);
  ok(JSON.stringify(full) === JSON.stringify(lean), 'Entrega idêntica no cenário: ' + scenario,
    'completa=' + JSON.stringify(full) + ' enxuta=' + JSON.stringify(lean));
  /* Uma paridade vazia não prova nada: o cenário tem de ter entregue algo. */
  ok(full.some(function (p) { return p.requested === '1'; }), 'O cenário realmente pediu anúncio: ' + scenario);
});

section('E a cópia pública não carrega a superfície do operador');

const leanSource = fs.readFileSync(LEAN, 'utf8');
const fullSource = fs.readFileSync(FULL, 'utf8');
ok(fullSource.indexOf('localExposureRequiredRatio') !== -1, 'A completa carrega o diagnóstico do operador');
ok(leanSource.indexOf('localExposureRequiredRatio') === -1, 'A enxuta não carrega o diagnóstico do operador');
ok(leanSource.indexOf('@lean:') === -1, 'Os marcadores de build não vazam para a cópia gerada');

console.log('\n' + JSON.stringify({ suite: 'runtime-lean-parity', passed: pass, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { failures.forEach(f => console.log('  FALHA: ' + f)); process.exit(1); }
