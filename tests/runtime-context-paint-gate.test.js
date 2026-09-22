'use strict';
/**
 * 12.7: arrival-context prior, the first-paint gate, request-time reservation
 * and the frequency cap.
 *
 * These four share a property worth testing together: each of them is allowed
 * to change WHEN a placement asks, and none of them is allowed to change
 * WHETHER it may. A gate that quietly removes supply looks identical to a gate
 * that defers it right up until the moment the reader arrives and finds a blank
 * space, so every scenario below checks the release as carefully as the hold.
 */
const { makeEnvironment, boot, mountAd, adBox, config, states } = require('./helpers/runtime-harness');

let pass = 0;
const failures = [];
function ok(condition, label, detail) {
  if (condition) { pass++; console.log('PASS ' + label); return true; }
  failures.push(label + (detail ? ' — ' + detail : ''));
  console.log('FAIL ' + label + (detail ? ' — ' + detail : ''));
  return false;
}
function equals(expected, actual, label) {
  return ok(expected === actual, label, 'esperado ' + JSON.stringify(expected) + ', obtido ' + JSON.stringify(actual));
}
function section(title) { console.log('\n' + '-'.repeat(72) + '\n' + title + '\n' + '-'.repeat(72)); }
function flush(env) { for (let i = 0; env.frames.length && i < 100; i++) env.frames.splice(0).forEach(cb => cb()); }

/** A config carrying the 12.7 server blocks, with everything else at production values. */
function ctxConfig(extra) {
  const base = config();
  base.entry_context = Object.assign({
    enabled: true, weight: 0.8, min_prior: 0.35, max_prior: 0.72,
    depth_priors: { internal: 0.62, 'google-app': 0.60, aggregator: 0.60, search: 0.46, social: 0.42, direct: 0.52, app: 0.50, other: 0.50 }
  }, (extra && extra.entry_context) || {});
  base.cwv = Object.assign({
    paint_gate: true, paint_gate_max_hold_ms: 1200, paint_gate_grace_ms: 250,
    paint_gate_near_vh: 0.5, reserve_on_request: true
  }, (extra && extra.cwv) || {});
  if (extra && extra.trial) base.trial = extra.trial;
  return base;
}

/** An environment with a referrer and, optionally, a stored reader model. */
function env(options) {
  options = options || {};
  const e = makeEnvironment(options.config || ctxConfig(), Object.assign({
    innerHeight: 800, scrollY: 0, plannedBodyCount: 3, renderedBodyCount: 3,
    structuralBodyCapacity: 3, articleWords: 2600, documentHeight: 12000, contentHeight: 11000
  }, options.env || {}));
  e.doc.referrer = options.referrer == null ? '' : options.referrer;
  e.win.location = { href: options.href || 'https://gameoverdrive.test/artigo/x', hostname: 'gameoverdrive.test' };
  /* PerformanceObserver is absent unless a scenario asks for it, so the gate
   * has to survive a browser that never reports a paint entry. */
  if (options.performanceObserver) {
    e.win.PerformanceObserver = function (callback) {
      e._paintCallback = callback;
      this.observe = () => { e._paintObserved = true; };
      this.disconnect = () => { e._paintDisconnected = true; };
    };
  }
  return e;
}

section('A origem da visita vira um prior de profundidade');

[
  ['', 'direct', 0.52],
  ['https://www.google.com/search?q=x', 'search', 0.46],
  ['https://news.google.com/foo', 'aggregator', 0.60],
  ['android-app://com.google.android.googlequicksearchbox', 'google-app', 0.60],
  ['https://l.facebook.com/', 'social', 0.42],
  ['https://t.co/abc', 'social', 0.42],
  ['https://gameoverdrive.test/outra-materia', 'internal', 0.62],
  ['https://algumblog.example/post', 'other', 0.50]
].forEach(function (row) {
  const e = env({ referrer: row[0] });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '901', tier: 'standard', top: 400, near: 900, predictive: true });
  flush(e);
  const reported = runtime.inspect().engine.governor.entryContext;
  equals(row[1], reported.source, 'Referrer "' + (row[0] || '(vazio)') + '" é classificado como ' + row[1]);
  /* O prior publicado é misturado com o neutro pelo peso, nunca aplicado cru. */
  const blended = Math.round((0.5 + (row[2] - 0.5) * 0.8) * 1000) / 1000;
  equals(blended, runtime.inspect().engine.governor.readerPrior, 'E vira o prior misturado ' + blended);
});

section('O prior de origem não vaza identidade nem sobrevive ao leitor real');

{
  const e = env({ referrer: 'https://www.google.com/search?q=termo+privado+do+leitor' });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '902', tier: 'standard', top: 400, near: 900, predictive: true });
  flush(e);
  const dump = JSON.stringify(runtime.inspect());
  ok(dump.indexOf('termo+privado') === -1 && dump.indexOf('privado') === -1, 'A busca do leitor não aparece em lugar nenhum do diagnóstico');
  ok(dump.indexOf('google.com/search') === -1, 'A URL de origem não é retida');
  equals('search', runtime.inspect().engine.governor.entryContext.source, 'Só o balde grosso sobrevive');
}

{
  /* Um leitor com histórico próprio suficiente manda; a origem é só o vazio. */
  const e = env({
    referrer: 'https://l.facebook.com/',
    env: { storagePermission: true, localStorageData: { go_ads_reader_depth_v1: JSON.stringify({ pages: 9, emaDepth: 0.81 }) } }
  });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '903', tier: 'standard', top: 400, near: 900, predictive: true });
  flush(e);
  const report = runtime.inspect().engine.governor;
  equals(0.81, report.readerPrior, 'O histórico medido do próprio leitor prevalece sobre o prior de origem');
  equals(false, report.entryContext.applied, 'E o diagnóstico diz que o prior de origem não foi aplicado');
}

{
  /* Desligado no servidor, o motor volta ao neutro de antes. */
  const e = env({ referrer: 'https://l.facebook.com/', config: ctxConfig({ entry_context: { enabled: false } }) });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '904', tier: 'standard', top: 400, near: 900, predictive: true });
  flush(e);
  equals(0.5, runtime.inspect().engine.governor.readerPrior, 'Com o prior desligado, o valor neutro 0,5 volta');
}

section('O prior de origem não abre as reservas do planner');

{
  /*
   * A expansão por "leitor que costuma ler fundo" é evidência sobre ESTE
   * leitor. Um referrer que normalmente lê fundo não é evidência sobre ele, e
   * deixá-lo abrir as reservas transformaria uma média de população em uma
   * decisão sobre uma pessoa.
   */
  const highPrior = ctxConfig({ entry_context: { depth_priors: { internal: 0.95 }, max_prior: 0.95, weight: 1 } });
  const e = env({ referrer: 'https://gameoverdrive.test/outra', config: highPrior, env: { scrollY: 0 } });
  const runtime = boot(e);
  /* Fundo da página: a posição continua pendente, então a fila segue viva e o
   * leitor pode de fato engajar ao rolar. */
  mountAd(runtime, e, { placement: 'a1', slot: '905', tier: 'standard', top: 9000, near: 900, predictive: true });
  flush(e);
  /* Profundidade acima do piso da expansão por prior (0,35) e abaixo do limiar
   * que a profundidade sozinha justifica (0,58): se a expansão abrir aqui, só
   * pode ter sido o prior. */
  e.setScroll(5000); flush(e); e.advance(500); flush(e);
  const governor = runtime.inspect().engine.governor;
  ok(governor.depth >= 0.35 && governor.depth < 0.58, 'O cenário está na faixa em que só o prior poderia abrir', 'profundidade=' + governor.depth);
  equals(0.95, governor.readerPrior, 'O prior de origem está alto o suficiente para abrir, se lhe fosse permitido');
  ok(governor.reason !== 'returning-deep-reader', 'A expansão não é justificada pela origem da visita', 'motivo=' + governor.reason);
}

{
  /* Mas o histórico real do leitor continua abrindo, como antes. */
  const e = env({
    referrer: '',
    env: { storagePermission: true, scrollY: 0, localStorageData: { go_ads_reader_depth_v1: JSON.stringify({ pages: 12, emaDepth: 0.86 }) } }
  });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '906', tier: 'standard', top: 9000, near: 900, predictive: true });
  flush(e);
  e.setScroll(5000); flush(e); e.advance(500); flush(e);
  const measured = runtime.inspect().engine.governor;
  ok(measured.depth >= 0.35 && measured.depth < 0.58, 'Na mesma faixa do cenário anterior', 'profundidade=' + measured.depth);
  equals('returning-deep-reader', measured.reason, 'O histórico próprio do leitor continua abrindo a expansão');
}

section('O portão de primeira pintura adia o distante e libera o resto');

{
  /* Longe da dobra, sem rolagem: exatamente o caso que disputa com o LCP. */
  const e = env({ performanceObserver: true });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '910', tier: 'standard', top: 1400, near: 1600, predictive: true });
  flush(e);
  equals('waiting-first-paint', states(runtime).a1, 'Uma posição a quase duas telas espera a primeira pintura');
  equals(false, runtime.inspect().paintGate.released, 'E o portão está de fato fechado');

  /* A entrada de LCP mais a carência libera. */
  e._paintCallback();
  e.advance(300); flush(e);
  equals(true, runtime.inspect().paintGate.released, 'A entrada de LCP mais a carência abre o portão');
  equals('largest-contentful-paint', runtime.inspect().paintGate.releasedBy, 'E o diagnóstico diz por quê');
  equals(true, runtime.inspect().manual[0].requested, 'A posição adiada pede assim que o portão abre');
}

{
  /* Perto da dobra: nunca adiada, porque o leitor está prestes a chegar. */
  const e = env({ performanceObserver: true });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '911', tier: 'standard', top: 1000, near: 1600, predictive: true });
  flush(e);
  equals(true, runtime.inspect().manual[0].requested, 'Uma posição a 0,25 viewport da dobra não é adiada');
}

{
  /*
   * Crítica na MESMA geometria em que a posição padrão acima ficou retida
   * (top 1400, uma viewport de 800). Comparar os dois na mesma distância é o
   * que prova que a isenção é da prioridade, e não da posição.
   */
  const e = env({ performanceObserver: true });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'site-masthead', slot: '912', tier: 'reach', top: 1400, near: 1600, predictive: true, critical: true, inContent: false });
  flush(e);
  equals(true, runtime.inspect().manual[0].requested, 'Inventário crítico não espera a primeira pintura onde o padrão esperou');
  equals(0, runtime.inspect().paintGate.deferrals, 'E não conta como adiamento');
}

{
  /* Sem PerformanceObserver o teto ainda libera: nada fica preso. */
  const e = env({ performanceObserver: false });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '913', tier: 'standard', top: 1400, near: 1600, predictive: true });
  flush(e);
  equals('waiting-first-paint', states(runtime).a1, 'Sem observador o portão ainda fecha');
  e.advance(1300); flush(e);
  equals(true, runtime.inspect().paintGate.released, 'E o teto o abre sozinho');
  equals('ceiling', runtime.inspect().paintGate.releasedBy, 'O motivo registrado é o teto');
  equals(true, runtime.inspect().manual[0].requested, 'A posição adiada acaba pedindo');
}

{
  /* Rolar finaliza o LCP no navegador; tem de finalizar o portão também. */
  const e = env({ performanceObserver: true });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '914', tier: 'standard', top: 1400, near: 1600, predictive: true });
  flush(e);
  equals('waiting-first-paint', states(runtime).a1, 'Parte fechado');
  e.setScroll(120); flush(e);
  equals(true, runtime.inspect().paintGate.released, 'A primeira rolagem abre o portão');
  equals('scroll', runtime.inspect().paintGate.releasedBy, 'E o motivo é a rolagem');
}

{
  /* Desligado no servidor: comportamento idêntico ao de 12.6. */
  const e = env({ config: ctxConfig({ cwv: { paint_gate: false } }), performanceObserver: true });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '915', tier: 'standard', top: 1400, near: 1600, predictive: true });
  flush(e);
  equals(true, runtime.inspect().manual[0].requested, 'Com o portão desligado nada é adiado');
  equals(false, runtime.inspect().paintGate.enabled, 'E o diagnóstico diz que ele não está armado');
}

section('O espaço do criativo é reservado antes de ele chegar');

{
  /* Abaixo da viewport: reservar ali não mexe em nada que o leitor veja. */
  const e = env({ performanceObserver: true, env: { providerDelayMs: 900 } });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '920', tier: 'standard', top: 1000, near: 1600, predictive: true });
  flush(e);
  const record = runtime.inspect().manual[0];
  equals(true, record.requested, 'A posição pede');
  ok(record.predictedReserve > 0, 'E reserva a altura prevista no momento do pedido', 'reserva=' + record.predictedReserve);
  ok(record.predictedReserve >= 180 && record.predictedReserve <= 360, 'A reserva fica na faixa de um display responsivo', 'reserva=' + record.predictedReserve);
}

{
  /* Dentro da viewport: reservar ali empurraria o texto que está sendo lido. */
  const e = env({ performanceObserver: true, env: { providerDelayMs: 900 } });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '921', tier: 'standard', top: 300, near: 1600, predictive: true });
  flush(e);
  const record = runtime.inspect().manual[0];
  equals(true, record.requested, 'A posição visível pede normalmente');
  equals(null, record.predictedReserve, 'Mas nada é reservado sob os olhos do leitor');
}

{
  /*
   * Um host que não pode colapsar não recebe reserva.
   *
   * Uma unidade sem reserva de servidor E sem `collapse_unfilled` não tem como
   * devolver o espaço: reservar ali transformaria uma resposta vazia em um
   * buraco permanente no meio da matéria — exatamente o que a escada de reserva
   * zero existe para evitar. Nenhuma unidade entregue está nessa situação; a
   * guarda existe para que criar uma não crie a armadilha.
   */
  const e = env({ performanceObserver: true, env: { providerDelayMs: 900 } });
  const runtime = boot(e);
  /* A classe tem de sumir ANTES do mount: activate() a consulta no pedido. */
  const box = adBox({ placement: 'a1', slot: '923', tier: 'standard', surface: 'article', top: 1000 });
  box.classList.remove('go-ad-slot--collapse-unfilled');
  box.parentElement = e.content;
  e.adBoxes.push(box);
  e.pushTargets.push(box.children[0].content.firstElementChild);
  runtime.mount(box, { near: 1600, nearMax: 3000, predictive: true, safetyMs: 600, tier: 'standard', priority: 'normal', sizes: [], gate: false, fixed: false, media: '' });
  flush(e);
  equals(true, runtime.inspect().manual[0].requested, 'O host não colapsável pede normalmente');
  equals(null, runtime.inspect().manual[0].predictedReserve, 'Mas não recebe reserva que não conseguiria devolver');
}

{
  /* Desligado no servidor: volta ao comportamento anterior. */
  const e = env({ config: ctxConfig({ cwv: { reserve_on_request: false } }), env: { providerDelayMs: 900 } });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '922', tier: 'standard', top: 1000, near: 1600, predictive: true });
  flush(e);
  equals(null, runtime.inspect().manual[0].predictedReserve, 'Com a reserva desligada nada é reservado');
}

section('Um limite de frequência vale onde foi declarado');

{
  /*
   * persistFill() grava o preenchimento de qualquer posição que declare um
   * limite. Até 12.6 só o Top Scroll lia esse histórico de volta, então um
   * limite configurado em outra unidade acumulava dias de dados que nada
   * jamais aplicava — o operador via a opção, a opção não existia.
   */
  const day = Date.now();
  const e = env({
    env: {
      storagePermission: true,
      localStorageData: { 'go_adsense_topscroll_24h_930': JSON.stringify([day - 1000, day - 2000]) }
    }
  });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'article-hero-overlay', slot: '930', tier: 'premium', top: 200, near: 1200, predictive: true, frequencyMax: 2 });
  flush(e);
  equals('frequency-capped', states(runtime)['article-hero-overlay'], 'Uma posição fora do Top Scroll também respeita o limite que declarou');
  equals(false, runtime.inspect().manual[0].requested, 'E não pede');
}

{
  const e = env({ env: { storagePermission: true, localStorageData: { 'go_adsense_topscroll_24h_931': JSON.stringify([Date.now() - 1000]) } } });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'article-hero-overlay', slot: '931', tier: 'premium', top: 200, near: 1200, predictive: true, frequencyMax: 3 });
  flush(e);
  equals(true, runtime.inspect().manual[0].requested, 'Abaixo do limite, a posição pede normalmente');
}

section('A altura lembrada reserva o que a unidade realmente recebe');

/*
 * O caso medido: o masthead reserva 132px e o criativo chega com 250px, o que
 * empurra a matéria inteira para baixo — 0,036 de CLS acima da dobra, quase
 * todo o deslocamento da página. Reservar 282px sempre só trocaria isso por um
 * buraco quando vier criativo curto, então o motor lembra a altura que a
 * unidade de fato recebe e reserva essa na visita seguinte.
 *
 * O harness COPIA localStorageData ao construir o ambiente, então escrita e
 * leitura são exercitadas separadamente: uma visita que aprende, e uma visita
 * que recebe o armazenamento já preenchido, como um leitor que volta.
 */
function heightConfig(overrides) {
  const cfg = ctxConfig();
  cfg.height_memory = Object.assign({ enabled: true, storage_key: 'go_ads_slot_height_v1',
    min_samples: 2, ema_alpha: 0.4, max_px: 400, ttl_ms: 604800000 }, overrides || {});
  return cfg;
}
function mastheadVisit(cfg, storage, permitted) {
  const e = env({ config: cfg, env: { storagePermission: permitted !== false, localStorageData: storage || {}, providerDelayMs: 200 } });
  /* O host do masthead declara reserva no CSS do tema (132px no mobile). O
   * duplo do DOM devolve 0 para todo mundo, e a memória de altura só age onde
   * já existe reserva — então esse valor precisa existir aqui também. */
  const base = e.win.getComputedStyle();
  e.win.getComputedStyle = function (node) {
    return (node && typeof node.getAttribute === 'function' && node.getAttribute('data-go-ad-placement') === 'site-masthead')
      ? Object.assign({}, base, { minHeight: '132px' })
      : base;
  };
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'site-masthead', slot: '3572313419', tier: 'reach', top: 200, near: 600, predictive: true, critical: true, inContent: false });
  flush(e); e.advance(500); flush(e);
  return runtime.inspect().manual[0];
}
function seeded(height, samples) {
  return { go_ads_slot_height_v1: JSON.stringify({ '3572313419': { h: height, n: samples, t: Date.now() } }) };
}

{
  /* Visita que aprende: nada é aplicado, mas a altura entregue passa a ser conhecida. */
  const learned = mastheadVisit(heightConfig({ min_samples: 1 }), {});
  equals(null, learned.rememberedReserve, 'Na visita que aprende, a reserva declarada continua valendo');
  equals(250, learned.rememberedHeight, 'E a altura realmente entregue passa a ser conhecida');
}

{
  /* Leitor que volta: o armazenamento já traz a altura, e o host a reserva. */
  const returning = mastheadVisit(heightConfig(), seeded(250, 4));
  equals(282, returning.rememberedReserve, 'O leitor que volta reserva a altura que a unidade recebe (250 + faixa)');
  ok(returning.requested === true, 'E a unidade pede normalmente');
}

{
  /* Uma amostra só não basta: min_samples protege contra um tamanho isolado. */
  const tooFew = mastheadVisit(heightConfig({ min_samples: 3 }), seeded(250, 2));
  equals(null, tooFew.rememberedReserve, 'Abaixo de min_samples a memória não é aplicada');
}

{
  /* A memória nunca encolhe a reserva declarada, só a aumenta. */
  const shorter = mastheadVisit(heightConfig(), seeded(60, 9));
  equals(null, shorter.rememberedReserve, 'Uma altura menor que a declarada não reduz a reserva');
}

{
  /* E não pode inventar um buraco: o teto limita o que a memória consegue pedir. */
  const huge = mastheadVisit(heightConfig({ max_px: 300 }), seeded(2000, 9));
  ok(huge.rememberedReserve <= 332, 'O teto limita a reserva que a memória pode produzir',
    'reserva=' + huge.rememberedReserve);
}

{
  /* Sem permissão de armazenamento, nada é lembrado nem aplicado. */
  const anonymous = mastheadVisit(heightConfig(), seeded(250, 9), false);
  equals(null, anonymous.rememberedHeight, 'Sem consentimento a altura não é lida');
  equals(null, anonymous.rememberedReserve, 'Nem aplicada');
}

{
  /* Desligado no servidor: comportamento anterior. */
  const off = mastheadVisit(heightConfig({ enabled: false }), seeded(250, 9));
  equals(null, off.rememberedReserve, 'Com a memória desligada a reserva declarada vale');
}

{
  /* Um host sem reserva declarada nunca vira buraco por causa da memória. */
  const cfg = heightConfig();
  const e = env({ config: cfg, env: { storagePermission: true, providerDelayMs: 200,
    localStorageData: { go_ads_slot_height_v1: JSON.stringify({ '900002': { h: 300, n: 9, t: Date.now() } }) } } });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'article-a1', slot: '900002', tier: 'standard', top: 1000, near: 1600, predictive: true });
  flush(e);
  equals(null, runtime.inspect().manual[0].rememberedReserve, 'A escada do corpo, que declara reserva zero, não recebe reserva da memória');
}

section('O braço do dia é repassado, nunca escolhido');

{
  const e = env({ config: ctxConfig({ trial: { trial: 'lead-trial', arm: 'lead', baseline: false, block: 7, unit: 'calendar-day' } }) });
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '940', tier: 'standard', top: 300, near: 1200, predictive: true });
  flush(e);
  const trial = runtime.inspect().trial;
  equals('lead', trial.arm, 'O runtime reporta o braço que o servidor mandou');
  equals('calendar-day', trial.unit, 'E a unidade de atribuição declarada');

  /* Dois documentos com a mesma carga têm de reportar o mesmo braço: o
   * navegador não participa da escolha. */
  const other = env({ config: ctxConfig({ trial: { trial: 'lead-trial', arm: 'lead', baseline: false, block: 7, unit: 'calendar-day' } }) });
  const otherRuntime = boot(other);
  mountAd(otherRuntime, other, { placement: 'a1', slot: '941', tier: 'standard', top: 300, near: 1200, predictive: true });
  flush(other);
  equals('lead', otherRuntime.inspect().trial.arm, 'Outro documento com a mesma carga reporta o mesmo braço');
}

{
  const e = env();
  const runtime = boot(e);
  mountAd(runtime, e, { placement: 'a1', slot: '942', tier: 'standard', top: 300, near: 1200, predictive: true });
  flush(e);
  equals(null, runtime.inspect().trial, 'Sem teste no servidor, o runtime não inventa um braço');
}

console.log('\n' + JSON.stringify({ suite: 'runtime-context-paint-gate', passed: pass, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { failures.forEach(f => console.log('  FALHA: ' + f)); process.exit(1); }
