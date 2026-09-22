/**
 * Browser runtime — core delivery contract.
 *
 *     node tests/runtime.test.js
 *
 * Drives the production runtime through the shared DOM double: the gate
 * ladder, provider lifecycle, latency learning, reservation behaviour and the
 * telemetry surface an operator debugs with.
 */
'use strict';

const assert = require('node:assert/strict');
const { makeEnvironment, boot, mountAd, config, report, states, El } = require('./helpers/runtime-harness');

let pass = 0;
const failures = [];
function ok(condition, label, detail) {
  if (condition) { pass++; return true; }
  failures.push(label + (detail ? ' — ' + detail : ''));
  return false;
}
function equals(expected, actual, label) {
  return ok(expected === actual, label, 'esperado ' + JSON.stringify(expected) + ', obtido ' + JSON.stringify(actual));
}
function section(title) { console.log('\n' + '-'.repeat(72) + '\n' + title + '\n' + '-'.repeat(72)); }
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach((cb) => cb()); }

function scene(options, decision, ruleOverrides) {
  const env = makeEnvironment(config(decision, ruleOverrides), Object.assign({
    scrollY: 0, now: 1000, innerHeight: 800, articleWords: 1400,
    plannedBodyCount: 5, renderedBodyCount: 6, structuralBodyCapacity: 6,
    reserveBodyCount: 1, contentHeight: 9000, documentHeight: 10000
  }, options || {}));
  return { env, runtime: boot(env) };
}
function place(scene_, spec) {
  return mountAd(scene_.runtime, scene_.env, Object.assign({
    near: 2000, nearMax: 3000, predictive: true, safetyMs: 600, inContent: true, surface: 'article'
  }, spec));
}

/* ------------------------------------------------------------------ gates */

section('A escada de portões nomeia cada recusa');
{
  const s = scene();
  place(s, { placement: 'article-a4', slot: '111', tier: 'standard', top: 6000 });
  s.env.advance(3000); flush(s.env);
  const view = report(s.runtime);
  equals(false, view.manual[0].requested, 'Um slot cinco telas abaixo não é solicitado');
  ok(/^waiting-/.test(view.manual[0].state), 'A recusa se identifica', view.manual[0].state);
  equals(0, s.env.win.adsbygoogle.length, 'Nenhum request chega ao provedor');
}

section('Um host visível é sempre solicitado');
{
  const s = scene();
  place(s, { placement: 'article-prime', slot: '222', tier: 'reach', top: 300 });
  flush(s.env);
  const view = report(s.runtime);
  equals(true, view.manual[0].requested, 'O host dentro da viewport pede imediatamente');
  equals('filled', view.manual[0].status, 'O provedor responde filled');
  equals(1, s.env.win.adsbygoogle.length, 'Exatamente um push por placement');
}

section('Um placement nunca é solicitado duas vezes');
{
  const s = scene();
  const box = place(s, { placement: 'article-prime', slot: '333', tier: 'reach', top: 200 });
  flush(s.env);
  for (let i = 0; i < 40; i++) { s.env.onScroll(); flush(s.env); s.env.advance(250); }
  equals(1, s.env.win.adsbygoogle.length, 'Scroll repetido não gera segundo request');
  s.runtime.mount(box, { near: 2000, tier: 'reach', priority: 'normal' });
  flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, 'Um segundo mount do mesmo box é ignorado');
}

section('O mesmo slot id não é disputado por dois hosts');
{
  const s = scene();
  place(s, { placement: 'article-a1', slot: 'dupe', tier: 'premium', top: 100 });
  place(s, { placement: 'article-a2', slot: 'dupe', tier: 'premium', top: 4200 });
  flush(s.env);
  for (let i = 0; i < 10; i++) { s.env.setScroll(s.env.win.pageYOffset + 700); flush(s.env); s.env.advance(400); }
  equals(1, s.env.win.adsbygoogle.length, 'Apenas um dos dois hosts alcança o provedor');
  const second = report(s.runtime).manual.find((x) => x.placement === 'article-a2');
  ok(second.state === 'alternative-already-requested' || !second.requested, 'O segundo host se declara alternativa já solicitada', second.state);
}

/* ------------------------------------------------- provider finality */

section('Somente `unfilled` explícito é vazio');
{
  const s = scene();
  place(s, { placement: 'article-a4', slot: 'nostatus', tier: 'standard', top: 200, answer: '__NO_STATUS__' });
  flush(s.env);
  const slot = report(s.runtime).manual[0];
  equals(true, slot.requested, 'O request acontece');
  equals('', slot.status, 'Sem data-ad-status o resultado é desconhecido, não vazio');
  equals('requested', slot.state, 'O estado permanece "requested", nunca "unfilled"');
}

section('Um no-fill libera a oportunidade; um `unfill-optimized` não');
{
  const s = scene({ plannedBodyCount: 1, renderedBodyCount: 1, structuralBodyCapacity: 1 });
  place(s, { placement: 'article-prime', slot: 'empty', tier: 'reach', top: 100, answer: 'unfilled' });
  place(s, { placement: 'article-a1', slot: 'next', tier: 'premium', top: 700 });
  flush(s.env);
  const view = states(s.runtime);
  ok(/^unfilled-/.test(view['article-prime']), 'O host vazio entra em estado de colapso', view['article-prime']);
  equals(2, s.env.win.adsbygoogle.length, 'A oportunidade liberada é usada pelo próximo host seguro');

  const t = scene({ plannedBodyCount: 1, renderedBodyCount: 1, structuralBodyCapacity: 1 });
  place(t, { placement: 'article-prime', slot: 'opt', tier: 'reach', top: 100, answer: 'unfill-optimized' });
  place(t, { placement: 'article-a1', slot: 'next2', tier: 'premium', top: 700 });
  flush(t.env);
  equals('optimized', states(t.runtime)['article-prime'], 'unfill-optimized é conteúdo presente do Google');
  equals(1, t.env.win.adsbygoogle.length, 'Conteúdo presente continua ocupando a oportunidade');
}

section('Silêncio do provedor libera a oportunidade por tempo, nunca por suposição');
{
  const s = scene({ plannedBodyCount: 1, renderedBodyCount: 1, structuralBodyCapacity: 1 });
  place(s, { placement: 'article-prime', slot: 'silent', tier: 'reach', top: 100, answer: '__NO_STATUS__' });
  place(s, { placement: 'article-a1', slot: 'after', tier: 'premium', top: 800 });
  flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, 'Enquanto o budget está ocupado o segundo host espera');
  s.env.advance(4000); flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, 'Quatro segundos ainda não liberam a oportunidade');
  s.env.advance(6000); flush(s.env);
  equals(2, s.env.win.adsbygoogle.length, 'Depois de stuck_release_ms a oportunidade vai para o próximo host');
  const silent = report(s.runtime).manual.find((x) => x.placement === 'article-prime');
  equals('provider-no-response', silent.state, 'O host silencioso se declara sem resposta');
  equals('', silent.status, 'E nunca é reclassificado como vazio');
  equals(true, silent.delivery.opportunityReleased, 'A liberação fica auditável na telemetria');
  equals(1, report(s.runtime).counts.releasedStuck, 'E é contada uma única vez');
}

/* ------------------------------------------------------------- density */

section('Densidade: dois criativos nunca encostam');
{
  const s = scene({ plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6 });
  place(s, { placement: 'article-prime', slot: 'd1', tier: 'reach', top: 100 });
  place(s, { placement: 'article-a1', slot: 'd2', tier: 'premium', top: 260 });
  flush(s.env);
  const view = states(s.runtime);
  equals('filled', view['article-prime'], 'O primeiro host entrega');
  equals('waiting-content-density', view['article-a1'], 'O host a 160px é recusado pela densidade');
  equals(1, s.env.win.adsbygoogle.length, 'E nenhum request extra acontece');
}

section('Densidade: o mesmo par passa com a folga do planner');
{
  const s = scene({ plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6 });
  place(s, { placement: 'article-prime', slot: 'd3', tier: 'reach', top: 100 });
  place(s, { placement: 'article-a1', slot: 'd4', tier: 'premium', top: 100 + 250 + 260 });
  flush(s.env);
  equals(2, s.env.win.adsbygoogle.length, 'Com 260px de conteúdo real entre criativos os dois entregam');
}

section('Densidade: no máximo três unidades por janela de viewport');
{
  const s = scene({ plannedBodyCount: 7, renderedBodyCount: 7, structuralBodyCapacity: 7, innerHeight: 800 });
  [0, 1, 2, 3].forEach((i) => place(s, {
    placement: 'article-a' + (i + 1), slot: 'w' + i, tier: 'standard', top: 60 + i * 520
  }));
  flush(s.env);
  const requested = report(s.runtime).manual.filter((x) => x.requested).length;
  ok(requested <= 3, 'A quarta unidade dentro de ±0,9 viewport é recusada', 'solicitadas=' + requested);
}

section('Densidade: colunas independentes não se bloqueiam');
{
  const s = scene({ innerWidth: 1400, plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6 });
  place(s, { placement: 'article-prime', slot: 'c1', tier: 'reach', top: 100, width: 700, left: 0 });
  place(s, { placement: 'sidebar-desktop', slot: 'c2', tier: 'premium', top: 100, width: 300, left: 900, inContent: false, surface: 'article-sidebar' });
  flush(s.env);
  equals(2, s.env.win.adsbygoogle.length, 'Um rail lateral e a coluna do artigo coexistem na mesma faixa vertical');
}

/* ------------------------------------------------------------- budget */

section('Budget: reservas alcançadas usam somente a capacidade segura do planner');
{
  const s = scene({ plannedBodyCount: 2, renderedBodyCount: 4, structuralBodyCapacity: 4 });
  [0, 1, 2, 3].forEach((i) => place(s, {
    placement: 'article-a' + (i + 1), slot: 'b' + i, tier: 'standard', top: 100 + i * 900
  }));
  for (let i = 0; i < 6; i++) { s.env.setScroll(s.env.win.pageYOffset + 700); flush(s.env); s.env.advance(400); }
  const result = report(s.runtime);
  equals(4, result.article.occupiedBody, 'As reservas alcançadas entram sem exigir o estado EXPANSION');
  equals(2, result.article.bodyBudget, 'O orçamento antecipado do governador continua no valor planejado');
  equals(2, result.manual.filter(slot => slot.delivery.budgetPath === 'reached-reserve').length,
    'As duas solicitações adicionais registram a admissão por chegada');
  ok(result.article.occupiedBody <= result.article.structuralBodyCapacity,
    'A entrega continua limitada à capacidade estrutural declarada');
}

section('Budget: superfícies fora do corpo têm orçamento próprio');
{
  const s = scene({ plannedBodyCount: 0, renderedBodyCount: 0, structuralBodyCapacity: 0 });
  place(s, { placement: 'topscroll', slot: 'crit', tier: 'reach', top: 40, critical: true, inContent: false, surface: 'topscroll' });
  place(s, { placement: 'article-end', slot: 'end', tier: 'completion', top: 620, inContent: false, surface: 'article-completion' });
  flush(s.env);
  equals(2, s.env.win.adsbygoogle.length, 'Topo crítico e completion não consomem o budget do corpo');
}

/* ------------------------------------------------------------ lifecycle */

section('Reserva de altura: um criativo menor não encolhe a página em uso');
{
  const s = scene();
  const box = place(s, { placement: 'article-prime', slot: 'r1', tier: 'reach', top: 200, height: 250 });
  flush(s.env);
  const before = report(s.runtime).manual[0].reservation;
  ok(before >= 250, 'A reserva acompanha o criativo entregue', String(before));
}

section('Página em segundo plano nunca cria impressão');
{
  const s = scene();
  s.env.doc.visibilityState = 'hidden';
  place(s, { placement: 'article-prime', slot: 'h1', tier: 'reach', top: 100 });
  flush(s.env);
  equals(0, s.env.win.adsbygoogle.length, 'Com a aba oculta nada é solicitado');
  equals('waiting-page-visible', states(s.runtime)['article-prime'], 'E o motivo fica explícito');
  s.env.doc.visibilityState = 'visible';
  (s.env.doc._listeners && s.env.doc._listeners.visibilitychange || []).forEach((cb) => cb());
  s.env.doc.dispatchEvent({ type: 'visibilitychange' });
  flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, 'Ao voltar para o primeiro plano o host entrega');
}

/* --------------------------------------------------------- latency model */

section('Latência é aprendida só de respostas com conteúdo');
{
  const s = scene({ plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6, providerDelayMs: 300 });
  place(s, { placement: 'article-prime', slot: 'l1', tier: 'reach', top: 100, answer: 'unfilled' });
  flush(s.env); s.env.advance(600); flush(s.env);
  const afterEmpty = report(s.runtime).snapshot;
  equals(0, afterEmpty.responsePresentSamples, 'Um no-fill não vira amostra de latência de render');
  ok(afterEmpty.responseAllSamples >= 1, 'Mas continua registrado para diagnóstico', JSON.stringify(afterEmpty.responseAllSamples));
  ok(afterEmpty.responseEstimateMs >= 1000, 'Uma resposta vazia rápida não encurta a estimativa conservadora', String(afterEmpty.responseEstimateMs));

  const t = scene({ plannedBodyCount: 6, renderedBodyCount: 6, structuralBodyCapacity: 6, providerDelayMs: 1800 });
  ['p1', 'p2', 'p3'].forEach((slot, i) => place(t, { placement: 'article-a' + (i + 1), slot: slot, tier: 'standard', top: 100 + i * 2400 }));
  for (let i = 0; i < 12; i++) { t.env.setScroll(t.env.win.pageYOffset + 700); flush(t.env); t.env.advance(700); }
  const learned = report(t.runtime).snapshot;
  ok(learned.responsePresentSamples >= 2, 'Respostas com criativo alimentam o modelo', String(learned.responsePresentSamples));
  ok(learned.responseEstimateMs >= 1500, 'Um provedor lento é aprendido como lento', String(learned.responseEstimateMs));
  const slot = report(t.runtime).manual[0];
  ok(slot.delivery.responseMs >= 1500, 'A latência real por slot é observável', String(slot.delivery.responseMs));
}

/* ------------------------------------------------------------ telemetry */

section('Telemetria expõe a decisão inteira, sem dados pessoais');
{
  const s = scene();
  place(s, { placement: 'article-prime', slot: 't1', tier: 'reach', top: 100 });
  flush(s.env);
  const view = report(s.runtime);
  ok(!!view.governor.state, 'O estado do governador é observável');
  ok(Array.isArray(view.governor.transitions), 'As transições ficam registradas');
  ok(typeof view.article.bodyBudget === 'number', 'O budget do corpo é observável');
  ok(typeof view.article.plannedBodyCount === 'number', 'A telemetria do planner chega ao navegador');
  ok(!!view.rules.device, 'O perfil de dispositivo em uso é observável', view.rules.device);
  equals(240, view.rules.min_gap_px, 'As regras vigentes são as da configuração central');
  const slot = view.manual[0];
  ok(slot.delivery.restingLeadPx > 0, 'A distância de aquecimento é observável');
  ok(slot.economics.expectedValue >= 0, 'O valor esperado é observável');
  const json = JSON.stringify(s.runtime.inspect());
  ok(json.indexOf('earnings') === -1 && json.indexOf('page_rpm') === -1, 'Nenhum valor financeiro vaza para o navegador');
  ok(typeof s.runtime.explain() === 'string' && s.runtime.explain().length > 80, 'explain() descreve a decisão em texto');
}

section('O runtime declara o modelo de entrega manual');
{
  const s = scene();
  const view = s.runtime.inspect();
  ok(view.deliveryModel.indexOf('manual') !== -1, 'A entrega in-page é manual', view.deliveryModel);
  ok(view.counts.auto === undefined, 'Não existe mais contabilidade de Auto Ads in-page');
}

/* ------------------------------------------------- a âncora da conta */

/*
 * O motor não coloca, não move e não conta sobreposições — mas não pode fingir
 * que elas não estão na tela. A âncora fica presa no rodapé da viewport, então
 * a região que o leitor realmente enxerga é menor que `innerHeight`. O que se
 * mede aqui é só isso: que a altura útil encolhe exatamente o tanto que a
 * âncora ocupa, que ela é MEDIDA e não presumida, e que sem âncora nada muda.
 */
section('A altura útil desconta a âncora da conta');
{
  const semAncora = scene();
  place(semAncora, { placement: 'article-a3', slot: 'sa', tier: 'standard', top: 780, height: 250 });
  semAncora.env.advance(1500); flush(semAncora.env);
  const leadSem = semAncora.runtime.inspect().manual[0].delivery.restingLeadPx;

  const comAncora = scene({ anchorHeight: 90 });
  place(comAncora, { placement: 'article-a3', slot: 'ca', tier: 'standard', top: 780, height: 250 });
  comAncora.env.advance(1500); flush(comAncora.env);
  const leadCom = comAncora.runtime.inspect().manual[0].delivery.restingLeadPx;

  ok(leadCom < leadSem, 'Com âncora, a posição de cauda é pedida mais perto da viewport',
    'sem=' + leadSem + 'px com=' + leadCom + 'px');
  ok(leadSem - leadCom <= 90, 'E o encolhimento não passa da altura real da âncora',
    String(leadSem - leadCom));

  /* Markup que o AdSense não marcou como âncora não reserva nada: se o
   * seletor deixar de casar um dia, o motor volta ao comportamento anterior
   * em vez de encolher a viewport por engano. */
  const desconhecido = scene();
  desconhecido.env.doc.querySelectorAll = () => [];
  place(desconhecido, { placement: 'article-a3', slot: 'dk', tier: 'standard', top: 780, height: 250 });
  desconhecido.env.advance(1500); flush(desconhecido.env);
  ok(desconhecido.runtime.inspect().manual[0].delivery.restingLeadPx === leadSem,
    'Sem âncora reconhecível, a reserva é zero e nada muda');
}

console.log('\n' + '='.repeat(72));
console.log(pass + ' asserções passaram, ' + failures.length + ' falharam');
failures.forEach((f) => console.log('  FALHA: ' + f));
console.log('='.repeat(72));
process.exit(failures.length ? 1 : 0);
