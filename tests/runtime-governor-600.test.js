/**
 * The Revenue Governor: 600 session archetypes.
 *
 *     node tests/runtime-governor-600.test.js
 *
 * The governor controls the advance budget and pacing from measured reader
 * behaviour. A reached reserve also has its own structural/geometry admission
 * route, covered by runtime-evolution.test.js. These cases assert that:
 *
 *   - a session that has proven nothing stays in WARMUP and keeps distant hosts cold;
 *   - an ordinary engaged read retains the planner's STANDARD advance budget;
 *   - depth and dwell open the advance budget without a financial signal;
 *   - EXPANSION is one-way, so a reader who earned inventory keeps it;
 *   - sustained flick scrolling widens spacing and stops predictive reach,
 *     without ever reducing the budget;
 *   - every transition is recorded with its reason.
 */
'use strict';

const assert = require('node:assert/strict');
const { makeEnvironment, boot, mountAd, config, report } = require('./helpers/runtime-harness');

let checks = 0;
const failures = [];
function ok(condition, label) { checks++; if (!condition) failures.push(label); }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach((cb) => cb()); }

function scene(options, decision) {
  const env = makeEnvironment(config(decision), Object.assign({
    scrollY: 0, now: 1000, innerHeight: 800, articleWords: 1600,
    plannedBodyCount: 4, renderedBodyCount: 6, structuralBodyCapacity: 6, reserveBodyCount: 2,
    contentHeight: 12000, documentHeight: 13000
  }, options || {}));
  return { env, runtime: boot(env) };
}
function ladder(s, count) {
  for (let i = 0; i < count; i++) {
    mountAd(s.runtime, s.env, {
      placement: 'article-a' + (i + 1), slot: 'g' + i, tier: i < 2 ? 'premium' : 'standard',
      top: 700 + i * 1500, near: 2000, nearMax: 3000, predictive: true, safetyMs: 600,
      inContent: true, surface: 'article'
    });
  }
}
/** Move the reader a fixed distance, taking `stepMs` of wall clock to do it. */
function scrollBy(env, px, stepMs) {
  env.env ? null : null;
  env.setScroll(env.win.pageYOffset + px);
  flush(env);
  env.advance(stepMs);
  flush(env);
}

for (let caseIndex = 0; caseIndex < 600; caseIndex++) {
  const mode = caseIndex % 6;
  const height = [568, 667, 736, 800, 844, 900][(caseIndex * 5) % 6];

  /* ---- 1. Nothing proven yet: WARMUP prepares the first screen only. ----
   * The position just under the fold is legitimate — the reader is one flick
   * from it and an empty gap there is a lost impression, not a saved one.
   * Everything past ~1.15 viewports has to be earned by engagement. */
  if (mode === 0) {
    const s = scene({ innerHeight: height });
    ladder(s, 4);
    flush(s.env);
    const view = report(s.runtime);
    ok(view.governor.state === 'warmup', 'case ' + caseIndex + ': sessão sem prova começa em WARMUP');
    const far = view.manual.filter((slot) => slot.delivery.distanceToViewport > height * 1.2);
    ok(far.length >= 2, 'case ' + caseIndex + ': o cenário tem hosts realmente distantes');
    ok(far.every((slot) => !slot.requested), 'case ' + caseIndex + ': WARMUP não alcança hosts além de ~1,15 viewport');
    ok(far.every((slot) => slot.state === 'waiting-engagement'),
      'case ' + caseIndex + ': e a recusa se chama waiting-engagement');
    ok(view.article.occupiedBody <= 1, 'case ' + caseIndex + ': WARMUP entrega no máximo a posição sob a dobra');
  }

  /* ---- 2. An ordinary engaged read: STANDARD advance budget. ------------ */
  if (mode === 1) {
    const s = scene({ innerHeight: height });
    ladder(s, 6);
    for (let step = 0; step < 10; step++) scrollBy(s.env, 420, 1400);
    const view = report(s.runtime);
    ok(view.governor.state === 'standard' || view.governor.state === 'expansion',
      'case ' + caseIndex + ': leitura normal sai de WARMUP');
    if (view.governor.state === 'standard') {
      ok(view.article.bodyBudget === 4, 'case ' + caseIndex + ': STANDARD usa o budget planejado');
      ok(view.article.occupiedBody <= view.article.structuralBodyCapacity,
        'case ' + caseIndex + ': STANDARD com reservas alcançadas nunca passa da capacidade estrutural');
    }
  }

  /* ---- 3. Proven depth opens the advance budget for reserves. ---------- */
  if (mode === 2) {
    const s = scene({ innerHeight: height, documentHeight: 6000, contentHeight: 5500 });
    ladder(s, 6);
    for (let step = 0; step < 3; step++) scrollBy(s.env, 300, 1200);
    const shallow = report(s.runtime);
    ok(shallow.article.bodyBudget === 4, 'case ' + caseIndex + ': profundidade rasa mantém o budget planejado');
    for (let step = 0; step < 12; step++) scrollBy(s.env, 420, 1500);
    const deep = report(s.runtime);
    ok(deep.governor.state === 'expansion', 'case ' + caseIndex + ': profundidade comprovada abre EXPANSION');
    ok(deep.article.bodyBudget === 6, 'case ' + caseIndex + ': EXPANSION libera exatamente as reservas renderizadas');
    ok(deep.article.bodyBudget <= deep.article.renderedBodyCount,
      'case ' + caseIndex + ': EXPANSION nunca passa do que o planner renderizou');
  }

  /* ---- 4. EXPANSION is one-way. ---------------------------------------- */
  if (mode === 3) {
    const s = scene({ innerHeight: height, documentHeight: 6000, contentHeight: 5500 });
    ladder(s, 6);
    for (let step = 0; step < 14; step++) scrollBy(s.env, 420, 1500);
    ok(report(s.runtime).governor.state === 'expansion', 'case ' + caseIndex + ': leitor profundo entra em EXPANSION');
    for (let step = 0; step < 6; step++) scrollBy(s.env, 3200, 60);
    const after = report(s.runtime);
    ok(after.governor.state === 'expansion', 'case ' + caseIndex + ': EXPANSION conquistada não é revogada');
    ok(after.article.bodyBudget === 6, 'case ' + caseIndex + ': o budget conquistado permanece');
  }

  /* ---- 5. Sustained flick: CONSERVATIVE, no budget cut. ---------------- */
  if (mode === 4) {
    const s = scene({ innerHeight: height, documentHeight: 40000, contentHeight: 39000 });
    ladder(s, 6);
    scrollBy(s.env, 200, 1200);
    for (let step = 0; step < 8; step++) scrollBy(s.env, height * 3, 40);
    const view = report(s.runtime);
    ok(view.governor.state === 'conservative',
      'case ' + caseIndex + ': flick sustentado entra em CONSERVATIVE (' + view.governor.paceViewportsPerSecond + ' vp/s)');
    ok(view.governor.reason === 'sustained-fast-scroll', 'case ' + caseIndex + ': o motivo fica registrado');
    ok(view.article.bodyBudget === 4, 'case ' + caseIndex + ': CONSERVATIVE não reduz o budget planejado');
    ok(view.rules.governor.spacing_scale.conservative > 1, 'case ' + caseIndex + ': CONSERVATIVE alarga o espaçamento');
  }

  /* ---- 6. A returning deep reader earns the reserves sooner. ----------- */
  if (mode === 5) {
    const s = scene({ innerHeight: height, documentHeight: 12000, contentHeight: 11000 });
    s.env.win.localStorage.getItem = (key) =>
      (key === 'go_ads_reader_depth_v1' ? JSON.stringify({ pages: 9, emaDepth: 0.86 }) : null);
    s.env.win.GOAdsConsent = { permitted: () => true };
    const fresh = scene({ innerHeight: height, documentHeight: 12000, contentHeight: 11000 });
    ladder(s, 6); ladder(fresh, 6);
    for (let step = 0; step < 6; step++) { scrollBy(s.env, 420, 1400); scrollBy(fresh.env, 420, 1400); }
    const returning = report(s.runtime);
    const firstVisit = report(fresh.runtime);
    ok(returning.governor.readerPrior >= 0.8, 'case ' + caseIndex + ': o prior do leitor recorrente é lido');
    ok(firstVisit.governor.readerPrior === 0.5, 'case ' + caseIndex + ': o primeiro acesso usa prior neutro');
    ok(returning.article.bodyBudget >= firstVisit.article.bodyBudget,
      'case ' + caseIndex + ': o leitor recorrente nunca recebe menos que o novo');
  }
}

/* ---- Depth + dwell is a real, independent route to EXPANSION. ----------
 * It is the route a careful reader takes: moderate depth, a long time on the
 * page. Until 4.6 the reading clock stopped the moment the reader engaged, so
 * this path could never fire and only the deep-scroll route existed. */
{
  const s = scene({ documentHeight: 9000, contentHeight: 8500, innerHeight: 800 });
  ladder(s, 6);
  /* Reach ~50% depth: past the expansion depth bar, short of the deep bar. */
  scrollBy(s.env, 4100, 1500);
  const early = report(s.runtime);
  ok(early.governor.depth >= 0.40 && early.governor.depth < 0.58,
    'profundidade entre as duas barras (' + early.governor.depth + ')');
  ok(early.governor.state === 'standard', 'só a profundidade média ainda não abre EXPANSION');
  ok(early.article.bodyBudget === 4, 'e o budget segue o planejado');
  /* Now simply read, without moving. */
  for (let i = 0; i < 6; i++) { s.env.advance(5000); flush(s.env); }
  const late = report(s.runtime);
  ok(late.governor.readingMs >= 18000,
    'o relógio de leitura continuou correndo depois do engajamento (' + late.governor.readingMs + 'ms)');
  ok(late.governor.state === 'expansion', 'profundidade + permanência abrem EXPANSION (' + late.governor.state + ')');
  ok(late.governor.reason === 'depth-and-dwell', 'e o motivo é exatamente esse (' + late.governor.reason + ')');
  ok(late.article.bodyBudget === 6, 'as reservas do planner ficam disponíveis');
}

/* ---- A backgrounded tab never becomes an engaged reader. --------------- */
{
  const s = scene({ innerHeight: 800 });
  /* Hidden from the first paint, the way a background-opened tab arrives. */
  s.env.doc.visibilityState = 'hidden';
  s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  ladder(s, 6);
  for (let i = 0; i < 6; i++) { s.env.advance(4000); flush(s.env); }
  ok(report(s.runtime).governor.state === 'warmup',
    'vinte e quatro segundos ocultos não engajam o leitor (' + report(s.runtime).governor.state + ')');
  ok(s.env.win.adsbygoogle.length === 0, 'e nenhum request acontece em segundo plano');
  s.env.doc.visibilityState = 'visible';
  s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  flush(s.env);
  s.env.advance(3000); flush(s.env);
  ok(report(s.runtime).governor.state !== 'warmup', 'ao voltar, o relógio de engajamento recomeça do tempo restante');
}

/* ---- A backgrounded tab does not accumulate reading time. -------------- */
{
  const s = scene({ documentHeight: 9000, contentHeight: 8500, innerHeight: 800 });
  ladder(s, 6);
  scrollBy(s.env, 4100, 1500);
  s.env.doc.visibilityState = 'hidden';
  s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  for (let i = 0; i < 8; i++) { s.env.advance(5000); flush(s.env); }
  s.env.doc.visibilityState = 'visible';
  s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  flush(s.env);
  const view = report(s.runtime);
  ok(view.governor.state !== 'expansion',
    'quarenta segundos em segundo plano não compram inventário (' + view.governor.state + ')');
  ok(view.governor.readingMs < 18000,
    'e o relógio de leitura fica parado enquanto a aba está oculta (' + view.governor.readingMs + 'ms)');
}

/* ---- Transitions are always explainable. ------------------------------ */
{
  const s = scene({ documentHeight: 6000, contentHeight: 5500 });
  ladder(s, 6);
  for (let step = 0; step < 14; step++) scrollBy(s.env, 420, 1500);
  const log = report(s.runtime).governor.transitions;
  ok(log.length >= 1, 'o log de transições existe');
  log.forEach((entry, i) => {
    ok(typeof entry.from === 'string' && typeof entry.to === 'string' && entry.from !== entry.to,
      'transição ' + i + ' registra origem e destino distintos');
    ok(typeof entry.reason === 'string' && entry.reason.length > 0, 'transição ' + i + ' registra um motivo');
    ok(typeof entry.depth === 'number', 'transição ' + i + ' registra a profundidade no momento');
  });
  ok(s.runtime.explain().indexOf('governador') !== -1, 'explain() descreve o governador em texto');
}

if (failures.length) {
  console.error(JSON.stringify({ suite: 'governor-600', checks, failures: failures.slice(0, 20), failureCount: failures.length }, null, 2));
  process.exit(1);
}
console.log(JSON.stringify({ suite: 'governor-600', cases: 600, checks, passed: true }));
