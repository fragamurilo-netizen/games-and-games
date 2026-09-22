/**
 * Top Scroll smart 5th/6th-fill contract.
 *
 * Fills 1-4 are normal. Fill 5 requires 3+ pageviews in the current tab
 * session OR 60s active reading. Fill 6 requires 4+ pageviews OR 120s active.
 * The rolling 24h cap remains 6 confirmed fills and there is never a refresh.
 */
'use strict';

const { makeEnvironment, boot, mountAd, config, report } = require('./helpers/runtime-harness');

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
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach((cb) => cb()); }
function history(n) {
  const t = Date.now();
  return JSON.stringify(Array.from({ length: n }, (_, i) => t - (n - i) * 1000));
}
function session(pages, activeMs) {
  return JSON.stringify({ pages, activeMs, updatedAt: Date.now() });
}
function scene(fills, pagesBefore, activeMs, environmentOverrides, slotOverrides) {
  const slot = '7792311754';
  const env = makeEnvironment(config(), Object.assign({
    scrollY: 0, now: 1000, innerHeight: 800, articleWords: 1400,
    plannedBodyCount: 0, renderedBodyCount: 0, structuralBodyCapacity: 0,
    storagePermission: true,
    localStorageData: { ['go_adsense_topscroll_24h_' + slot]: history(fills) },
    sessionStorageData: { go_ads_topscroll_session_v1: session(pagesBefore || 0, activeMs || 0) }
  }, environmentOverrides || {}));
  const runtime = boot(env);
  const box = mountAd(runtime, env, Object.assign({
    placement: 'topscroll', slot, tier: 'reach', top: 20, critical: true,
    inContent: false, surface: 'topscroll', near: 3000, nearMax: 3000,
    frequencyMax: 6, smartFrequency: true, smartFreeFills: 4,
    smartFifthPages: 3, smartFifthMs: 60000,
    smartSixthPages: 4, smartSixthMs: 120000, smartSessionIdleMs: 1800000
  }, slotOverrides || {}));
  flush(env);
  return { env, runtime, box };
}

console.log('\n------------------------------------------------------------------------\nTop Scroll inteligente\n------------------------------------------------------------------------');

{
  const s = scene(3, 0, 0);
  equals(1, s.env.win.adsbygoogle.length, 'O 4º preenchimento continua normal');
  const r = report(s.runtime).manual[0];
  equals('filled', r.status, 'O 4º pode preencher sem gate de sessão');
  equals(1, r.delivery.smartSessionPages, 'Mesmo antes do 5º o motor já abre a sessão inteligente');
}

{
  const s = scene(4, 1, 0); // current page becomes page 2
  equals(0, s.env.win.adsbygoogle.length, 'O 5º não entra numa sessão ainda fraca');
  equals('waiting-session-engagement', report(s.runtime).manual[0].state, 'O motivo da espera é explícito');
  s.env.advance(59900); flush(s.env);
  equals(0, s.env.win.adsbygoogle.length, '59,9s ainda não liberam o 5º');
  s.env.advance(200); flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, '60s ativos liberam o 5º sem refresh');
}

{
  const s = scene(4, 2, 0); // current page becomes page 3
  equals(1, s.env.win.adsbygoogle.length, 'A 3ª página da sessão libera o 5º imediatamente');
  const r = report(s.runtime).manual[0];
  equals(3, r.delivery.smartSessionPages, 'A telemetria registra 3 páginas na sessão');
  equals(5, r.delivery.smartNextFill, 'A telemetria identifica o 5º preenchimento');
}

{
  const s = scene(5, 2, 0); // current page becomes page 3, still below 4
  equals(0, s.env.win.adsbygoogle.length, 'O 6º espera numa sessão de apenas 3 páginas');
  equals('waiting-session-engagement', report(s.runtime).manual[0].state, 'O 6º usa o mesmo gate explícito');
}

{
  const s = scene(5, 3, 0); // current page becomes page 4
  equals(1, s.env.win.adsbygoogle.length, 'A 4ª página da sessão libera o 6º imediatamente');
  const r = report(s.runtime).manual[0];
  equals(4, r.delivery.smartSessionPages, 'A telemetria registra 4 páginas na sessão');
  equals(6, r.delivery.smartNextFill, 'A telemetria identifica o 6º preenchimento');
}

{
  const s = scene(5, 0, 120000);
  equals(1, s.env.win.adsbygoogle.length, '120s ativos acumulados liberam o 6º mesmo sem 4 páginas');
}

{
  const s = scene(6, 10, 600000);
  equals(0, s.env.win.adsbygoogle.length, 'Seis preenchimentos confirmados fecham a cota de 24h');
  equals('frequency-capped', report(s.runtime).manual[0].state, 'O teto de 6 continua absoluto na configuração');
  equals(true, s.box.hidden, 'O host capped é removido da experiência');
}

{
  const key = 'go_adsense_topscroll_24h_7792311754';
  const wall = Date.now();
  const rolling = [wall - 86400001].concat([1, 2, 3, 4, 5].map(n => wall - n * 1000));
  const s = scene(0, 3, 0, { localStorageData: { [key]: JSON.stringify(rolling) } });
  equals(1, s.env.win.adsbygoogle.length, 'Registro com mais de24h deixa de ocupar a janela móvel');
  const after = JSON.parse(s.env.win.localStorage.getItem(key));
  equals(6, after.length, 'Janela conserva cinco registros válidos e o novo preenchimento');
  ok(after.every(t => t > wall - 86400000), 'Registro expirado é excluído ao persistir o novo preenchimento');
}

{
  const s = scene(4, 0, 0);
  equals(0, s.env.win.adsbygoogle.length, 'Aba começa aguardando engajamento');
  /* Simulate a second tab updating the shared localStorage value. This is a
   * read-before-request check, not an atomic guarantee across simultaneous bids. */
  s.env.win.localStorage.setItem('go_adsense_topscroll_24h_7792311754', history(6));
  s.env.setScroll(0); flush(s.env);
  equals('frequency-capped', report(s.runtime).manual[0].state, 'Próxima avaliação relê preenchimentos confirmados em outra aba');
  equals(0, s.env.win.adsbygoogle.length, 'Histórico compartilhado atualizado bloqueia a solicitação ainda não feita');
}

{
  const key = 'go_adsense_topscroll_24h_7792311754';
  const stored = history(6), tabSession = session(4, 120000);
  const s = scene(0, 0, 0, { storagePermission: false,
    localStorageData: { [key]: stored }, sessionStorageData: { go_ads_topscroll_session_v1: tabSession } });
  equals(stored, s.env.win.localStorage.getItem(key), 'Sem permissão, não zera nem regrava histórico local existente');
  equals(tabSession, s.env.win.sessionStorage.getItem('go_ads_topscroll_session_v1'), 'Sem permissão, não altera engajamento persistido');
  equals(0, report(s.runtime).manual[0].delivery.smartSessionPages, 'Sem permissão, não lê histórico da sessão para liberar extras');
}

{
  const key = 'go_adsense_topscroll_24h_7792311754';
  const stored = history(3);
  const s = scene(0, 0, 0, { localStorageData: { [key]: stored } }, { answer: 'unfilled' });
  equals(1, s.env.win.adsbygoogle.length, 'Falha de preenchimento faz somente a solicitação original');
  equals(stored, s.env.win.localStorage.getItem(key), 'Unfilled não consome um preenchimento da cota');
  s.env.advance(30000); flush(s.env);
  equals(1, s.env.win.adsbygoogle.length, 'Unfilled não provoca refresh para completar a cota');
}

console.log('\n' + pass + ' asserções passaram.');
if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}
