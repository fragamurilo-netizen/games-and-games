/**
 * Overdrive — diagnóstico de perda de receita, para colar no console.
 *
 * POR QUE ISTO EXISTE
 * -------------------
 * Ninguém que olha o tema de fora consegue dizer por que uma página rendeu
 * pouco. "Poucas impressões" tem pelo menos cinco causas diferentes, e elas
 * pedem correções opostas:
 *
 *   1. o motor não carregou            -> zero pedidos, zero tudo
 *   2. o planner não criou a posição   -> problema de conteúdo/estrutura
 *   3. a posição existe e não pediu    -> portão de entrega (densidade, leitor)
 *   4. pediu e o Google não preencheu  -> demanda, não configuração
 *   5. preencheu e ninguém viu         -> viewability, e aí RPM cai sozinho
 *
 * Subir densidade conserta (2). Não conserta nenhuma das outras, e piora (5).
 * Este script diz em qual delas você está, na página que você está vendo.
 *
 * COMO USAR
 * ---------
 * Abra uma matéria publicada, em janela anônima (deslogado), role até o fim
 * com calma, espere uns 10 segundos e cole isto no console do navegador.
 * Prefira o modo dispositivo do DevTools num tamanho de celular, porque é
 * onde está a audiência.
 *
 * Ele é somente leitura: não pede anúncio, não altera nada na página e não
 * envia nada para lugar nenhum.
 *
 * O QUE ELE NÃO É
 * ---------------
 * Não é Active View, não é impressão paga e não é receita. "Visível" aqui é
 * observação local do DOM. Um número bom aqui não promete dinheiro; um número
 * ruim aqui explica dinheiro que não veio.
 */
(function () {
  'use strict';

  var R = window.GOAdsRuntime;
  var out = [];
  var problems = [];
  function line(s) { out.push(s); }
  function problem(s) { problems.push(s); }

  line('=== Overdrive · diagnóstico de receita ===');
  line('URL: ' + location.pathname);
  line('Viewport: ' + window.innerWidth + 'x' + window.innerHeight +
       (window.innerWidth <= 767 ? '  (perfil MOBILE)' : window.innerWidth >= 1101 ? '  (perfil DESKTOP)' : '  (entre os dois)'));
  line('');

  /* ---------------------------------------------------- 1. o motor carregou? */
  var hosts = document.querySelectorAll('[data-go-ad-placement]');
  var stillTemplate = document.querySelectorAll('[data-go-ad-placement] template[data-go-ad-pending]');

  if (!R) {
    line('MOTOR: NÃO CARREGADO.');
    line('  Hosts no documento: ' + hosts.length + ', ainda em template: ' + stillTemplate.length);
    problem('O motor manual não inicializou nesta página. Enquanto isso, NENHUMA ' +
            'posição manual pede anúncio — nem as antigas. É a perda maior possível e ' +
            'não tem nada a ver com densidade. Verifique cache/CDN servindo HTML antigo, ' +
            'otimizador de JS combinando ou adiando o script, ou CSP.');
    console.log(out.concat('', 'PROBLEMAS:', problems.map(function (p, i) { return (i + 1) + ') ' + p; })).join('\n'));
    return;
  }

  line('MOTOR: ' + R.version);
  if (stillTemplate.length) {
    problem(stillTemplate.length + ' host(s) continuam em <template>, ou seja, nunca foram montados. ' +
            'Se você já rolou a página inteira, isso é uma posição perdida, não uma posição esperando.');
  }

  var i = R.inspect();
  var c = i.counts || {};

  /* --------------------------------------------- 2. o planner criou posição? */
  var root = document.querySelector('[data-go-manual-ads-root="article"]');
  line('');
  line('--- PLANNER (o que o servidor decidiu ANTES do navegador) ---');
  if (!root) {
    line('  (não é uma matéria, ou o root do artigo não está no documento)');
  } else {
    var d = root.dataset;
    var words = +d.goAdPlanBodyWords || 0;
    var cap = +d.goAdPlanBodyCapacity || 0;
    var planned = +d.goAdPlanPlannedBody || 0;
    var rendered = +d.goAdPlanRenderedBody || 0;
    var eligible = +d.goAdPlanEligibleCandidates || 0;
    line('  Palavras do corpo:        ' + words);
    line('  Tipo de matéria:          ' + (d.goAdPlanArticleType || '?') + '   perfil: ' + (d.goAdPlanProfile || '?'));
    line('  Candidatos elegíveis:     ' + eligible);
    line('  Teto estrutural do corpo: ' + cap);
    line('  Planejadas / renderizadas: ' + planned + ' / ' + rendered);
    if (eligible > 0 && cap > 0 && eligible < cap) {
      problem('O artigo só ofereceu ' + eligible + ' fronteira(s) segura(s) para um teto de ' + cap + '. ' +
              'Aqui o limite é a ESTRUTURA do texto, não a política de anúncios: parágrafos muito ' +
              'longos, blocos grandes sem quebra, ou tabelas/embeds ocupando o miolo. Subir densidade ' +
              'não cria fronteira que o texto não tem.');
    }
    if (words && words < 240) {
      line('  (matéria curta: por contrato o corpo fica sem inventário abaixo de 240 palavras)');
    }
  }

  /* -------------------------------------------- 3/4/5. o funil de entrega */
  line('');
  line('--- ENTREGA (o que o navegador fez com as posições) ---');
  line('  Montadas:                 ' + (c.mounted || 0));
  line('  Elegíveis neste viewport: ' + (c.eligibleViewport || 0) + '   (fora do viewport: ' + (c.ineligibleViewport || 0) + ')');
  line('  Solicitadas:              ' + (c.requested || 0));
  line('  Responderam:              ' + (c.responded || 0) + '   (aguardando resposta: ' + (c.awaitingProvider || 0) + ')');
  line('    preenchidas:            ' + (c.filled || 0));
  line('    otimizadas (vazias):    ' + (c.optimized || 0));
  line('    unfilled:               ' + (c.unfilled || 0));
  line('  Erros de request:         ' + (c.requestErrors || 0));
  line('  Visíveis localmente:      ' + (c.localViewable || 0) + '   (proxy de DOM, NÃO é Active View)');
  line('  Esperando algum portão:   ' + (c.waiting || 0));

  var wr = c.waitReasons || {};
  var reasons = Object.keys(wr);
  if (reasons.length) {
    line('');
    line('  Por que estão esperando:');
    reasons.sort(function (a, b) { return wr[b] - wr[a]; }).forEach(function (k) {
      line('    ' + k + ': ' + wr[k]);
    });
  }

  /* ---------------------------------------------------- leitura das causas */
  var requested = c.requested || 0;
  var responded = c.responded || 0;
  var present = c.providerPresent || 0;
  var mounted = c.mounted || 0;

  if (mounted && !requested) {
    problem('Há ' + mounted + ' posição(ões) montada(s) e NENHUMA pediu anúncio. Se você já rolou ' +
            'a página até o fim, isto é entrega travada, não leitura curta. Olhe os motivos de espera acima.');
  }
  if (requested && responded && present === 0) {
    problem('Todas as ' + responded + ' respostas vieram VAZIAS. Isso é demanda do Google, não ' +
            'configuração do tema. Unidade recém-criada leva dias para começar a preencher — ' +
            'não julgue uma unidade nova pela primeira semana.');
  }
  if (requested && (c.unfilled || 0) / Math.max(1, responded) > 0.6) {
    problem('Mais de 60% das respostas vieram unfilled. Se isso se repetir em várias matérias e ' +
            'vários dias, o problema é preço/demanda daquelas posições, e mais posições não resolve.');
  }
  if (present && (c.localViewable || 0) / present < 0.5) {
    problem('Menos da metade dos criativos presentes chegou a ficar visível localmente. Impressão que ' +
            'ninguém vê derruba o RPM de impressão e o quanto o comprador paga depois. Aqui MENOS ' +
            'posições, mais fundo, rende mais que mais posições.');
  }
  if ((c.requestErrors || 0) > 0) {
    problem((c.requestErrors) + ' posição(ões) com erro de request. Causa comum: unidade pedida com ' +
            'largura disponível zero, por CSS escondendo o host sem o portão de viewport correspondente.');
  }

  /* --------------------------------------------------- inventário por posição */
  line('');
  line('--- POSIÇÕES ---');
  Array.prototype.forEach.call(hosts, function (h) {
    var st = h.getAttribute('data-go-ad-state') || (h.querySelector('template[data-go-ad-pending]') ? 'em-template' : '—');
    var rect = h.getBoundingClientRect();
    line('  ' + (h.getAttribute('data-go-ad-placement') + '                         ').slice(0, 26) +
         ' ' + (st + '            ').slice(0, 22) +
         ' altura=' + Math.round(rect.height) + 'px');
  });

  /* ----------------------------------------------------------- overlays */
  line('');
  line('--- FORMATOS OFICIAIS DO GOOGLE (âncora/vinheta) ---');
  var anchor = document.querySelector('ins.adsbygoogle[data-anchor-status], .google-auto-placed');
  line('  Detectado na página: ' + (anchor ? 'sim' : 'não') +
       '   (ausência aqui não prova que está desligado na conta)');

  line('');
  line('=== RESUMO ===');
  if (!problems.length) {
    line('Nada anômalo nesta página. Se a receita está baixa mesmo assim, a causa não está ' +
         'na entrega — está em quantas pessoas chegam. Receita = pageviews x RPM.');
  } else {
    problems.forEach(function (p, n) { line((n + 1) + ') ' + p); });
  }

  console.log(out.join('\n'));
  return i;
})();
