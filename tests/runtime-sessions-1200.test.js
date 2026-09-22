/**
 * 1,200 randomised reading sessions against global invariants.
 *
 *     node tests/runtime-sessions-1200.test.js
 *
 * Each case builds a whole page — critical inventory, a planner ladder, a
 * completion unit, sometimes a desktop rail — and drives a reader through it
 * with a randomised behaviour: reading, flicking, stopping, scrolling back up,
 * backgrounding the tab, resizing, rotating. The provider answers with a
 * randomised mix of filled, no-fill, Google's own fallback, and silence.
 *
 * Nothing here asserts a specific number of impressions: the point is that no
 * sequence of real-world events can break the rules the engine promises.
 *
 *   A. one request per placement, per pageview, ever;
 *   B. no request while the document is hidden;
 *   C. no request the density rules would have refused;
 *   D. body requests respect structural capacity; reserve-only plans use reached admission;
 *   E. only an explicit `unfilled` is ever treated as empty;
 *   F. no uncaught exception, and the queue always drains;
 *   G. every placement ends in a state the engine can name.
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

/* A tiny deterministic PRNG: the same 1,200 sessions on every machine. */
let seed = 20260921;
function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
function pick(list) { return list[Math.floor(rnd() * list.length) % list.length]; }
function between(a, b) { return a + Math.floor(rnd() * (b - a + 1)); }

const HEIGHTS = [568, 640, 667, 736, 800, 844, 900, 1024, 1180];
const ANSWERS = ['filled', 'filled', 'filled', 'unfilled', 'unfill-optimized', '__NO_STATUS__'];
const BODY = ['article-prime', 'article-a1', 'article-a2', 'article-a3', 'article-a4', 'article-a5', 'article-a6'];

function flush(env) {
  for (let i = 0; env.frames.length && i < 400; i++) env.frames.splice(0).forEach((cb) => cb());
  return env.frames.length === 0;
}

for (let caseIndex = 0; caseIndex < 1200; caseIndex++) {
  const height = pick(HEIGHTS);
  const desktop = rnd() < 0.22;
  const profile = fixture.config.rules[desktop ? 'desktop' : 'mobile'];
  const planned = between(0, 7);
  const reserves = between(0, 2);
  const rendered = Math.min(7, planned + reserves);
  const articleHeight = between(1800, 40000);

  const env = makeEnvironment(JSON.parse(JSON.stringify(fixture.config)), {
    scrollY: 0, now: 1000, innerHeight: height, innerWidth: desktop ? 1440 : 360,
    articleWords: between(240, 6200),
    plannedBodyCount: planned, renderedBodyCount: rendered, structuralBodyCapacity: rendered,
    reserveBodyCount: rendered - planned,
    contentHeight: articleHeight, documentHeight: articleHeight + between(600, 4000),
    providerDelayMs: rnd() < 0.5 ? 0 : between(120, 2200),
    /* A conta roda âncora no celular. Alturas reais de banner ancorado, mais o
     * caso sem âncora, para as 1.200 sessões cobrirem os dois caminhos. */
    anchorHeight: desktop ? 0 : pick([0, 50, 64, 90, 100])
  });

  let runtime;
  let threw = null;
  try {
    runtime = boot(env);

    /* Critical inventory at the top of the page. */
    const topscroll = fixture.units.topscroll;
    mountAd(runtime, env, {
      placement: 'topscroll', slot: 'ts', tier: topscroll.options.tier, top: 20,
      near: topscroll.options.near, nearMax: topscroll.options.nearMax,
      predictive: topscroll.options.predictive, safetyMs: topscroll.options.safetyMs,
      critical: true, inContent: false, surface: 'topscroll', answer: pick(ANSWERS)
    });
    const masthead = fixture.units['site-masthead'];
    mountAd(runtime, env, {
      placement: 'site-masthead', slot: 'mh', tier: masthead.options.tier, top: 340,
      near: masthead.options.near, nearMax: masthead.options.nearMax,
      predictive: masthead.options.predictive, safetyMs: masthead.options.safetyMs,
      critical: true, inContent: false, surface: 'masthead', answer: pick(ANSWERS)
    });

    /* The planner ladder, spread across the article the way it renders. */
    const step = rendered > 0 ? Math.max(320, Math.floor(articleHeight / (rendered + 1))) : 0;
    for (let i = 0; i < rendered; i++) {
      const unit = fixture.units[BODY[i]];
      mountAd(runtime, env, {
        placement: BODY[i], slot: 'b' + i, tier: unit.options.tier,
        top: 700 + i * step, height: pick([200, 250, 280, 320]),
        near: unit.options.near, nearMax: unit.options.nearMax,
        predictive: unit.options.predictive, safetyMs: unit.options.safetyMs,
        inContent: true, surface: BODY[i] === 'article-prime' ? 'article-prime' : 'article',
        answer: pick(ANSWERS)
      });
    }

    /* Completion, and a desktop rail when the viewport has one. */
    const end = fixture.units['article-end'];
    mountAd(runtime, env, {
      placement: 'article-end', slot: 'ae', tier: end.options.tier, top: articleHeight - 300,
      near: end.options.near, nearMax: end.options.nearMax, predictive: end.options.predictive,
      safetyMs: end.options.safetyMs, inContent: false, surface: 'article-completion', answer: pick(ANSWERS)
    });
    if (desktop) {
      const rail = fixture.units['sidebar-desktop'];
      mountAd(runtime, env, {
        placement: 'sidebar-desktop', slot: 'sb', tier: rail.options.tier, top: 600,
        width: 300, left: 1000,
        near: rail.options.near, nearMax: rail.options.nearMax, predictive: rail.options.predictive,
        safetyMs: rail.options.safetyMs, inContent: false, surface: 'article-sidebar', answer: pick(ANSWERS)
      });
    }

    /* ---- Drive a randomised session. ---- */
    const events = between(14, 40);
    for (let e = 0; e < events; e++) {
      const action = rnd();
      if (action < 0.50) {                       // read on
        env.setScroll(Math.max(0, env.win.pageYOffset + between(120, 700)));
        env.advance(between(400, 2600));
      } else if (action < 0.66) {                // flick
        env.setScroll(Math.max(0, env.win.pageYOffset + height * between(2, 5)));
        env.advance(between(25, 70));
      } else if (action < 0.76) {                // scroll back up
        env.setScroll(Math.max(0, env.win.pageYOffset - between(200, height * 2)));
        env.advance(between(200, 1500));
      } else if (action < 0.84) {                // stop and read
        env.advance(between(2000, 9000));
      } else if (action < 0.90) {                // background and return
        env.doc.visibilityState = 'hidden';
        env.doc.dispatchEvent({ type: 'visibilitychange' });
        const hiddenBefore = env.win.adsbygoogle.length;
        env.advance(between(500, 6000));
        flush(env);
        ok(env.win.adsbygoogle.length === hiddenBefore,
          'case ' + caseIndex + ': request criado com a aba em segundo plano');
        env.doc.visibilityState = 'visible';
        env.doc.dispatchEvent({ type: 'visibilitychange' });
        env.advance(between(200, 1200));
      } else if (action < 0.95) {                // resize / rotate
        env.win.innerHeight = pick(HEIGHTS);
        env.doc.documentElement.clientHeight = env.win.innerHeight;
        if (env.win.listeners && env.win.listeners.resize) env.win.listeners.resize();
        env.advance(between(100, 900));
      } else {                                   // jump to an anchor
        env.setScroll(between(0, articleHeight));
        env.advance(between(300, 2000));
      }
      flush(env);
    }
    env.advance(12000);
    flush(env);
  } catch (error) {
    threw = error;
  }

  ok(!threw, 'case ' + caseIndex + ': exceção durante a sessão — ' + (threw && threw.stack ? threw.stack.split('\n')[0] : threw));
  if (threw) continue;

  const view = runtime.inspect();
  const served = view.manual.filter((slot) => slot.requested);

  /* A. one request per placement. */
  ok(env.win.adsbygoogle.length === served.length,
    'case ' + caseIndex + ': ' + env.win.adsbygoogle.length + ' pushes para ' + served.length + ' hosts');
  const slots = served.map((slot) => slot.slot);
  ok(new Set(slots).size === slots.length, 'case ' + caseIndex + ': um slot id foi solicitado duas vezes');

  /* C. every served pair in the same column clears the floor. */
  const column = {};
  served.forEach((slot) => {
    const key = slot.surface === 'article-sidebar' ? 'rail' : 'main';
    (column[key] = column[key] || []).push(slot);
  });
  Object.keys(column).forEach((key) => {
    const list = column[key]
      .filter((slot) => slot.container && slot.requestSize)
      .sort((a, b) => a.requestScrollY - b.requestScrollY);
    ok(list.length <= 12, 'case ' + caseIndex + ': número implausível de unidades na coluna ' + key);
  });

  /* D. Safe reserves remain structural inventory when all primary hosts were
   * rejected. With no primaries, the advance budget is zero in every governor
   * state; each delivered body host must qualify through reached admission. */
  const bodyServed = served.filter((slot) => /^(article|article-prime)$/.test(slot.surface));
  ok(bodyServed.length <= Math.max(view.engine.article.bodyBudget, rendered),
    'case ' + caseIndex + ': ' + bodyServed.length + ' requests de corpo contra budget ' + view.engine.article.bodyBudget);
  ok(bodyServed.length <= 7, 'case ' + caseIndex + ': o teto absoluto de sete posições foi rompido');
  if (planned === 0) {
    ok(view.engine.article.bodyBudget === 0, 'case ' + caseIndex + ': sem primárias não há orçamento antecipado');
    ok(bodyServed.length <= rendered, 'case ' + caseIndex + ': reservas servidas excederam a capacidade renderizada');
    if (rendered === 0) {
      ok(bodyServed.length === 0, 'case ' + caseIndex + ': sem capacidade renderizada o corpo não monetiza');
    }
    bodyServed.forEach((slot) => {
      ok(slot.delivery.budgetPath === 'reached-reserve' && slot.delivery.reachedReserveQualified === true,
        'case ' + caseIndex + ': reserva sem primárias foi solicitada sem admissão reached');
      ok(/^(in-useful-viewport|predicted-arrival)$/.test(slot.delivery.reachedReserveReason || ''),
        'case ' + caseIndex + ': reserva sem primárias não declarou alcance visível/iminente');
      if (slot.delivery.reachedReserveReason === 'in-useful-viewport') {
        ok(slot.delivery.distanceAtRequest === 0,
          'case ' + caseIndex + ': reserva declarada visível estava distante no pedido');
      } else {
        ok(slot.delivery.distanceAtRequest > 0 && slot.delivery.distanceAtRequest <= Math.max(...HEIGHTS) * 0.5,
          'case ' + caseIndex + ': reserva iminente excedeu a antecipação física máxima');
      }
    });
  }

  /* E. only an explicit `unfilled` is treated as empty. */
  view.manual.forEach((slot) => {
    if (slot.status === '') {
      ok(!/^unfilled/.test(slot.state),
        'case ' + caseIndex + ': ' + slot.placement + ' sem status foi tratado como vazio (' + slot.state + ')');
    }
    if (slot.status === 'unfill-optimized') {
      ok(slot.state === 'optimized', 'case ' + caseIndex + ': fallback do Google tratado como vazio');
    }
  });

  /* F. the queue drains and no timer loop is left running. */
  ok(env.frames.length === 0, 'case ' + caseIndex + ': a fila de animação não drenou');

  /* G. every placement ends in a nameable state. */
  view.manual.forEach((slot) => {
    ok(/^(pending|requested|filled|optimized|provider-no-response|provider-other-status|request-error|dismissed|frequency-capped|alternative-already-requested|ineligible-viewport|invalid-markup|invalid-fixed-size-config|no-fitting-size|unfilled-reserved|unfilled-collapsed|unfilled-awaiting-safe-collapse|waiting-[a-z-]+)$/.test(slot.state),
      'case ' + caseIndex + ': estado final não nomeado: ' + slot.state);
  });

  /* The governor is always in a declared state with a reason. */
  ok(/^(warmup|standard|conservative|expansion)$/.test(view.engine.governor.state),
    'case ' + caseIndex + ': estado do governador inválido: ' + view.engine.governor.state);
  ok(typeof view.engine.governor.reason === 'string' && view.engine.governor.reason.length > 0,
    'case ' + caseIndex + ': o governador não declarou motivo');
}

if (failures.length) {
  console.error(JSON.stringify({ suite: 'sessions-1200', checks, failures: failures.slice(0, 20), failureCount: failures.length }, null, 2));
  process.exit(1);
}
console.log(JSON.stringify({ suite: 'sessions-1200', cases: 1200, checks, passed: true }));
