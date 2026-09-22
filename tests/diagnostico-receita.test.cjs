/**
 * deployment/diagnostico-receita.js roda de verdade.
 *
 * O script é uma ferramenta que vai para a mão de outra pessoa, colada num
 * console de produção. Checar sintaxe não prova nada: o que precisa ser provado
 * é que ele distingue as causas que ele afirma distinguir, e que ele não
 * explode quando a página não é uma matéria ou quando o motor nem carregou —
 * que é exatamente o caso em que alguém mais precisa dele.
 *
 * Roda com um DOM mínimo, sem jsdom, porque o script só usa um punhado de APIs.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const SOURCE = fs.readFileSync(path.join(__dirname, '..', 'deployment', 'diagnostico-receita.js'), 'utf8');

let pass = 0;
const failures = [];
function ok(cond, label, detail) {
  if (cond) { pass++; return true; }
  failures.push(label + (detail ? ' — ' + detail : ''));
  return false;
}
function section(t) { console.log('\n' + '-'.repeat(72) + '\n' + t + '\n' + '-'.repeat(72)); }

/* --------------------------------------------------------------- DOM mínimo */
function makeHost(placement, state, height, inTemplate) {
  return {
    _attrs: { 'data-go-ad-placement': placement, 'data-go-ad-state': state },
    getAttribute(name) { return Object.prototype.hasOwnProperty.call(this._attrs, name) ? this._attrs[name] : null; },
    getBoundingClientRect() { return { height: height, width: 360, x: 0, y: 0 }; },
    querySelector(sel) { return inTemplate && sel.indexOf('template') !== -1 ? {} : null; },
  };
}

function run(opts) {
  const hosts = opts.hosts || [];
  const templates = hosts.filter((h) => h.querySelector('template[data-go-ad-pending]'));
  const logs = [];

  const document = {
    querySelectorAll(sel) {
      if (sel === '[data-go-ad-placement]') return hosts;
      if (sel.indexOf('template') !== -1) return templates;
      return [];
    },
    querySelector(sel) {
      if (sel.indexOf('data-go-manual-ads-root') !== -1) return opts.articleRoot || null;
      return null;
    },
  };

  const sandbox = {
    window: { innerWidth: opts.width || 390, innerHeight: 844, GOAdsRuntime: opts.runtime || undefined },
    document,
    location: { pathname: opts.pathname || '/uma-materia/' },
    console: { log: (s) => logs.push(String(s)) },
  };
  sandbox.window.document = document;
  sandbox.globalThis = sandbox;

  const returned = vm.runInNewContext(SOURCE, sandbox, { filename: 'diagnostico-receita.js' });
  return { text: logs.join('\n'), returned };
}

function runtimeWith(counts, version) {
  return { version: version || '12.7.0-context-paint-gate', inspect: () => ({ counts }) };
}

const BASE = {
  mounted: 0, eligibleViewport: 0, ineligibleViewport: 0, requested: 0, responded: 0,
  providerPresent: 0, filled: 0, optimized: 0, unfilled: 0, requestErrors: 0,
  waiting: 0, awaitingProvider: 0, localViewable: 0, waitReasons: {},
};
const counts = (over) => Object.assign({}, BASE, over);

/* ------------------------------------------------------------------ casos */

section('1. Motor não carregou — o caso em que o script mais importa');
{
  const r = run({ runtime: null, hosts: [makeHost('article-a1', null, 0, true), makeHost('article-a2', null, 0, true)] });
  ok(/MOTOR: NÃO CARREGADO/.test(r.text), 'Diz claramente que o motor não carregou');
  ok(/PROBLEMAS:/.test(r.text), 'Reporta como problema');
  ok(/perda maior possível/.test(r.text), 'Explica a gravidade em vez de só constatar');
  ok(!/POSIÇÕES/.test(r.text), 'Não tenta seguir adiante sem motor');
  ok(r.returned === undefined, 'Sai cedo sem devolver inspeção');
}

section('2. Página saudável — não inventa problema');
{
  const r = run({
    runtime: runtimeWith(counts({ mounted: 5, eligibleViewport: 5, requested: 5, responded: 5, providerPresent: 4, filled: 4, unfilled: 1, localViewable: 4 })),
    hosts: [makeHost('article-prime', 'filled', 280), makeHost('article-a1', 'filled', 250)],
    articleRoot: { dataset: { goAdPlanBodyWords: '1400', goAdPlanBodyCapacity: '7', goAdPlanPlannedBody: '5', goAdPlanRenderedBody: '7', goAdPlanEligibleCandidates: '9', goAdPlanArticleType: 'news', goAdPlanProfile: 'standard_editorial' } },
  });
  ok(/Nada anômalo nesta página/.test(r.text), 'Não inventa problema onde não há');
  ok(/Receita = pageviews x RPM/.test(r.text), 'Reaponta para tráfego quando a entrega está boa');
  ok(/Palavras do corpo:\s+1400/.test(r.text), 'Lê os atributos do planner');
  ok(/perfil MOBILE/.test(r.text), 'Identifica o perfil de dispositivo');
}

section('3. Distingue as causas, que é a razão de existir');
{
  const nada = run({ runtime: runtimeWith(counts({ mounted: 6, eligibleViewport: 6, waiting: 6, waitReasons: { 'waiting-content-density': 4, 'waiting-reader': 2 } })), hosts: [] });
  ok(/NENHUMA pediu anúncio/.test(nada.text), 'Montado sem pedido é sinalizado');
  ok(/waiting-content-density: 4/.test(nada.text), 'Mostra o portão que está segurando');

  const vazio = run({ runtime: runtimeWith(counts({ mounted: 4, requested: 4, responded: 4, unfilled: 4 })), hosts: [] });
  ok(/respostas vieram VAZIAS/.test(vazio.text), 'Tudo unfilled é sinalizado');
  ok(/demanda do Google, não/.test(vazio.text), 'E atribuído a demanda, não a configuração do tema');
  ok(!/densidade/.test(vazio.text.split('=== RESUMO ===')[1] || ''), 'Não sugere densidade quando a causa é demanda');

  const cego = run({ runtime: runtimeWith(counts({ mounted: 6, requested: 6, responded: 6, providerPresent: 6, filled: 6, localViewable: 1 })), hosts: [] });
  ok(/visível localmente/.test(cego.text), 'Baixa viewability é sinalizada');
  ok(/MENOS\s+posições/.test(cego.text), 'E a recomendação é reduzir, não aumentar');

  const erro = run({ runtime: runtimeWith(counts({ mounted: 3, requested: 3, requestErrors: 2, responded: 1, providerPresent: 1, filled: 1, localViewable: 1 })), hosts: [] });
  ok(/erro de request/.test(erro.text), 'Erros de request são sinalizados');
  ok(/largura disponível zero/.test(erro.text), 'Com a causa mais provável nomeada');
}

section('4. Estrutura do texto limitando o planner');
{
  const r = run({
    runtime: runtimeWith(counts({ mounted: 3, requested: 3, responded: 3, providerPresent: 3, filled: 3, localViewable: 3 })),
    hosts: [],
    articleRoot: { dataset: { goAdPlanBodyWords: '2900', goAdPlanBodyCapacity: '9', goAdPlanPlannedBody: '3', goAdPlanRenderedBody: '3', goAdPlanEligibleCandidates: '3', goAdPlanArticleType: 'guide', goAdPlanProfile: 'standard_editorial' } },
  });
  ok(/fronteira\(s\) segura\(s\) para um teto de 9/.test(r.text), 'Artigo longo com poucas fronteiras é sinalizado');
  ok(/Subir densidade\s+não cria fronteira/.test(r.text), 'E o script recusa explicitamente a solução errada');
}

section('5. Não explode fora de uma matéria');
{
  const r = run({ runtime: runtimeWith(counts({ mounted: 2, requested: 2, responded: 2, providerPresent: 2, filled: 2, localViewable: 2 })), hosts: [], articleRoot: null, pathname: '/' });
  ok(/não é uma matéria/.test(r.text), 'Diz que não há artigo em vez de falhar');
  ok(typeof r.returned === 'object' && r.returned !== null, 'Ainda devolve a inspeção para uso manual');
}

section('6. É somente leitura');
{
  /* O script usa Array#push internamente; o que ele nunca pode fazer é
   * enfileirar uma solicitacao no adsbygoogle. */
  ok(!/adsbygoogle[\s\S]{0,40}\.push\s*\(/.test(SOURCE), 'Nunca enfileira request no adsbygoogle');
  ok(!/window\.adsbygoogle|adsbygoogle\s*=/.test(SOURCE), 'Nunca toca na fila do provedor');
  ok(!/fetch\(|XMLHttpRequest|sendBeacon|navigator\.send/.test(SOURCE), 'Não envia nada para lugar nenhum');
  ok(!/setAttribute|innerHTML|appendChild|removeChild|\.remove\(\)/.test(SOURCE), 'Não altera o DOM');
  ok(!/localStorage|sessionStorage|document\.cookie/.test(SOURCE), 'Não guarda nada no navegador');
}

console.log('\n' + '='.repeat(72));
console.log(pass + ' asserções passaram, ' + failures.length + ' falharam');
failures.forEach((f) => console.log('  FALHA: ' + f));
console.log('='.repeat(72));
process.exit(failures.length ? 1 : 0);
