/** Manager-only, on-demand DOM report; never reads creative iframe contents. */
(function () {
  'use strict';
  var panel, output, snapshot, summary;
  var proseSelector = '[data-go-manual-ads-root="article"], [data-go-single-content], [itemprop="articleBody"], .go-single__content, .go-article__content';
  var auxiliarySelector = '.go-channel-invite, .go-inline-related, .go-recirc, [data-go-related-block], .go-single__cta, .go-article__cta, .go-author-box, .goc-article-compare, .ged-reader-tool';
  function nodes(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
  function identity(node) {
    return node ? { tag: node.tagName, id: (node.id || '').slice(0, 160), classes: String(node.getAttribute('class') || '').slice(0, 700) } : null;
  }
  function geometry(node) {
    var rect = node.getBoundingClientRect(), css = window.getComputedStyle(node);
    var round = function (n) { return Math.round(n * 10) / 10; };
    var value = identity(node);
    value.rect = { top: round(rect.top), left: round(rect.left), width: round(rect.width), height: round(rect.height) };
    value.css = {};
    ['display', 'visibility', 'opacity', 'position', 'overflow-x', 'overflow-y', 'contain', 'content-visibility', 'transform', 'height', 'min-height', 'max-height', 'width', 'max-width'].forEach(function (key) {
      value.css[key] = css.getPropertyValue(key);
    });
    return value;
  }
  function editorialParagraph(node) {
    return !node.closest(auxiliarySelector + ', [data-go-ad-placement], .google-auto-placed, ins.adsbygoogle');
  }
  function statusTotals() {
    return { total: 0, filled: 0, 'unfill-optimized': 0, unfilled: 0, unknown: 0 };
  }
  function markerTotals() { return { markers: 0, insStatuses: statusTotals() }; }
  function collectManualStartup() {
    var runtime = window.GOAdsRuntime, boot = window.GOAdsRuntimeBoot || {};
    var hosts = nodes('[data-go-ad-placement]'), templates = 0, requested = 0, statuses = statusTotals();
    hosts.forEach(function (host) {
      if (host.querySelector('template[data-go-ad-pending]')) templates++;
      if (host.getAttribute('data-go-ad-requested') === '1') requested++;
      nodes('ins.adsbygoogle', host).forEach(function (ins) { countStatus(statuses, ins.getAttribute('data-ad-status')); });
    });
    var ready = !!(runtime && typeof runtime.mount === 'function' && typeof runtime.scan === 'function');
    return {
      apiAvailable: ready,
      runtimeVersion: ready ? String(runtime.version || '') : null,
      inlineScriptPresent: !!document.getElementById('go-ads-manual-runtime'),
      configAvailable: !!(window.GOAdsYieldConfig && typeof window.GOAdsYieldConfig === 'object' && !Array.isArray(window.GOAdsYieldConfig)),
      recoveryState: typeof boot.state === 'string' ? boot.state : 'not-needed-or-not-started',
      recoveryError: typeof boot.error === 'string' ? boot.error.slice(0, 240) : null,
      manualHosts: hosts.length, hostsWithPendingTemplate: templates, hostsMarkedRequested: requested,
      activeInsStatuses: statuses,
      diagnosis: !ready && hosts.length ? 'Há hosts manuais, mas a API do motor não está disponível; o motivo original exige o estado do script e os erros do navegador.' : ready ? 'Motor inicializado; consulte os estados por posição para distinguir espera, solicitação e resposta.' : 'Nenhum motor ou host manual observado nesta captura.',
      scope: 'Leitura local. Presença do script não prova execução; template pendente não é no-fill. Nenhuma recuperação é disparada por este painel.'
    };
  }
  function countStatus(totals, status) {
    totals.total++;
    totals[status === 'filled' || status === 'unfill-optimized' || status === 'unfilled' ? status : 'unknown']++;
  }
  function prosePosition(node, paragraphs) {
    var previous = null, next = null, containing = null;
    paragraphs.forEach(function (paragraph) {
      if (paragraph.contains(node)) { containing = paragraph; return; }
      var order = paragraph.compareDocumentPosition(node);
      if (order & 1) return; // Disconnected nodes have no meaningful sequence.
      if (order & 4) previous = paragraph;
      else if (order & 2 && !next) next = paragraph;
    });
    return {
      prosePosition: containing ? 'inside-p' : previous && next ? 'between' : previous ? 'after-last' : next ? 'before-first' : 'no-p',
      previousEditorialParagraph: identity(previous), nextEditorialParagraph: identity(next),
      containingEditorialParagraph: identity(containing)
    };
  }
  function collectArticle() {
    // Read-only and on demand. No fetch, provider push, observer, storage, or
    // creative iframe access. Counts describe this DOM, never Google's auction.
    var roots = nodes(proseSelector), root = roots[0] || null, referenceParagraphs = [];
    var markerSummary = {
      total: 0, sampled: 0, sampleLimit: 100, truncated: false,
      insStatusScope: 'INS pertencentes aos marcadores Google encontrados; não é o total de anúncios do site.',
      byRegion: { 'article-prose': markerTotals(), auxiliary: markerTotals(), 'manual-host': markerTotals(), 'outside-article': markerTotals() },
      byProsePosition: { 'before-first': markerTotals(), 'after-last': markerTotals(), between: markerTotals(), 'inside-p': markerTotals(), 'no-p': markerTotals() },
      insStatuses: statusTotals()
    };
    var report = {
      capturedAt: new Date().toISOString(),
      page: window.location.origin + window.location.pathname,
      readyState: document.readyState, documentVisibility: document.visibilityState,
      viewport: { width: window.innerWidth, height: window.innerHeight, scrollY: Math.round(window.scrollY || 0) },
      theme: window.GOAdsDiagnosticsConfig || {},
      scope: 'DOM observado na navegação atual. Não comprova elegibilidade Google, configuração da conta, receita ou Active View.',
      articleRoots: roots.length,
      supportRequestedClassCount: nodes('.go-author-lead__body').length,
      supportRequestedClassInArticle: root ? root.matches('.go-author-lead__body') || !!root.querySelector('.go-author-lead__body') : null,
      scripts: [], article: null, manualStartup: collectManualStartup(),
      autoPlacementMarkers: [], autoPlacementMarkerSummary: markerSummary, unclassifiedAdsenseElements: 0
    };
    report.scripts = nodes('script[src]').filter(function (node) { return /\/adsbygoogle\.js(?:[?#]|$)/.test(node.getAttribute('src') || ''); }).map(function (node) {
      var url;
      try { url = new URL(node.src, window.location.href); } catch (_) { return { invalidUrl: true }; }
      return { url: url.origin + url.pathname, clientQualified: url.searchParams.has('client'), async: node.async, defer: node.defer, type: node.type || 'text/javascript', cfasync: node.getAttribute('data-cfasync') };
    });
    if (root) {
      var paragraphs = nodes('p', root).filter(editorialParagraph), ancestors = [], parent = root;
      // Empty paragraphs remain in the structural count but cannot establish a
      // boundary of prose. This is DOM order, never a claim of visible text.
      referenceParagraphs = paragraphs.filter(function (node) { return (node.textContent || '').trim().length > 0; });
      while (parent && ancestors.length < 10) { ancestors.push(geometry(parent)); parent = parent.parentElement; }
      var lengths = paragraphs.map(function (node) { return (node.textContent || '').trim().length; }).sort(function (a, b) { return a - b; });
      var ids = Object.create(null);
      nodes('[id]', root).forEach(function (node) { ids[node.id] = (ids[node.id] || 0) + 1; });
      report.article = {
        ancestors: ancestors, directChildren: root.children.length,
        directParagraphs: paragraphs.filter(function (node) { return node.parentElement === root; }).length,
        editorialParagraphs: paragraphs.length,
        proseReferenceParagraphs: referenceParagraphs.length,
        paragraphCharacters: lengths.reduce(function (sum, n) { return sum + n; }, 0),
        medianParagraphCharacters: lengths.length ? (lengths[Math.floor((lengths.length - 1) / 2)] + lengths[Math.floor(lengths.length / 2)]) / 2 : 0,
        headings: nodes('h2,h3', root).length, images: nodes('img', root).length,
        figures: nodes('figure', root).length, tables: nodes('table', root).length,
        embeds: nodes('iframe,object,embed', root).length,
        auxiliaryBlocks: nodes(auxiliarySelector, root).length,
        manualHosts: nodes('[data-go-ad-placement]', root).length,
        duplicateIds: Object.keys(ids).filter(function (id) { return ids[id] > 1; }).map(function (id) { return { id: id, count: ids[id] }; }),
        // Geometry is capped for a small export; aggregate counts cover all p.
        paragraphSample: paragraphs.slice(0, 100).map(function (node, index) {
          var value = geometry(node); value.index = index; value.characters = (node.textContent || '').trim().length;
          value.parent = identity(node.parentElement); value.nextElement = identity(node.nextElementSibling); return value;
        })
      };
    }
    var markers = nodes('.google-auto-placed');
    markerSummary.total = markers.length;
    markerSummary.sampled = Math.min(markers.length, markerSummary.sampleLimit);
    markerSummary.truncated = markers.length > markerSummary.sampleLimit;
    markers.forEach(function (node, index) {
      var inside = !!(root && root.contains(node));
      var auxiliary = node.closest(auxiliarySelector), manual = node.closest('[data-go-ad-placement]');
      var region = auxiliary ? 'auxiliary' : manual ? 'manual-host' : inside ? 'article-prose' : 'outside-article';
      var position = region === 'article-prose' ? prosePosition(node, referenceParagraphs) : {
        prosePosition: null, previousEditorialParagraph: null, nextEditorialParagraph: null, containingEditorialParagraph: null
      };
      var insNodes = nodes('ins.adsbygoogle', node);
      if (node.matches('ins.adsbygoogle')) insNodes.unshift(node);
      // A nested marker owns its own INS: totals count each element only once.
      var insRecords = insNodes.filter(function (ins) { return ins.closest('.google-auto-placed') === node; }).map(function (ins) {
        var status = ins.getAttribute('data-ad-status');
        countStatus(markerSummary.insStatuses, status);
        countStatus(markerSummary.byRegion[region].insStatuses, status);
        if (position.prosePosition) countStatus(markerSummary.byProsePosition[position.prosePosition].insStatuses, status);
        return { slot: ins.getAttribute('data-ad-slot'), status: status, processed: ins.getAttribute('data-adsbygoogle-status') };
      });
      markerSummary.byRegion[region].markers++;
      if (position.prosePosition) markerSummary.byProsePosition[position.prosePosition].markers++;
      if (index >= markerSummary.sampleLimit) return;
      var value = geometry(node);
      value.region = region;
      Object.keys(position).forEach(function (key) { value[key] = position[key]; });
      value.parent = identity(node.parentElement);
      value.previousElement = identity(node.previousElementSibling);
      value.nextElement = identity(node.nextElementSibling);
      value.auxiliaryParent = identity(auxiliary);
      value.ins = insRecords;
      report.autoPlacementMarkers.push(value);
    });
    report.unclassifiedAdsenseElements = nodes('ins.adsbygoogle').filter(function (node) {
      return !node.closest('[data-go-ad-placement], .google-auto-placed');
    }).length;
    report.limitations = [
      'Marcadores google-auto-placed são observações parciais; sua ausência não prova ausência de todos os formatos Google.',
      'Região article-prose preserva o agrupamento antigo: raiz editorial fora de auxiliares/manuais. Só prosePosition=between identifica um intervalo na ordem DOM entre P editoriais com texto, sem comprovar visibilidade ou adjacência direta.',
      'Os totais abrangem todos os marcadores encontrados; a geometria e os detalhes são amostrados até sampleLimit. INS em marcadores aninhados são contados uma única vez, no marcador mais próximo.',
      'filled, unfill-optimized e unfilled são atributos DOM separados. Processamento done, dimensão ou iframe não comprovam filled; nenhum desses indicadores comprova receita ou impressão paga.',
      'A captura feita como administrador pode diferir da navegação anônima e do HTML em cache.',
      'A leitura não altera o DOM editorial nem lê ou modifica google_ama_config; configurações/exclusões da conta e recrawl continuam desconhecidos.',
      'Dimensões e estilos refletem o instante da captura; não constituem medição de Core Web Vitals nem de visibilidade oficial.'
    ];
    return report;
  }
  window.GOAdsDiagnostics = { collectArticle: collectArticle, collectManualStartup: collectManualStartup };
  function refresh() {
    try {
      snapshot = window.GOAdsRuntime && window.GOAdsRuntime.inspect ? window.GOAdsRuntime.inspect() : null;
    } catch (error) { snapshot = { runtimeError: String(error && error.message || error) }; }
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) snapshot = { scope: 'Motor manual não carregado nesta página; consulte modo e contexto.' };
    try { snapshot.articleStructure = collectArticle(); } catch (error) { snapshot.articleStructure = { error: String(error && error.message || error) }; }
    output.textContent = JSON.stringify(snapshot, null, 2);
    if (summary) {
      var c = snapshot && snapshot.counts && snapshot.counts.manual ? snapshot.counts.manual : {};
      var cells = [
        ['Montados', c.mounted], ['Elegíveis', c.eligibleViewport], ['Solicitados', c.requested], ['Com resposta', c.responded],
        ['Processados pelo Google', c.providerAccepted], ['Sem resposta', c.awaitingProvider],
        ['Oportunidades liberadas', c.releasedStuck],
        ['Presentes', c.providerPresent], ['Preenchidos', c.filled], ['Otimizados', c.optimized], ['No-fill', c.unfilled],
        ['Aguardando solicitação', c.pendingEligible], ['Visíveis localmente por 1s', c.localViewable]
      ];
      var e = snapshot && snapshot.engine ? snapshot.engine : null;
      if (e) {
        var gov = e.governor || {}, dc = e.decision || {}, ar = e.article || {}, rules = e.rules || {};
        cells.push(['Dispositivo', rules.device || '—']);
        cells.push(['Governador', (gov.state || '—') + ' · ' + (gov.reason || '')]);
        cells.push(['Profundidade', Math.round((gov.depth || 0) * 100) + '%']);
        cells.push(['Ritmo', (gov.paceViewportsPerSecond || 0) + ' vp/s']);
        cells.push(['Leitor engajado', e.readerEngaged ? 'sim · ' + (e.engagedBy || '') : 'não']);
        cells.push(['Topo em leilão', e.criticalInFlight]);
        cells.push(['Daypart', (ar.daypart || '—') + ' · ' + (ar.hour == null ? '—' : ar.hour + 'h')]);
        cells.push(['Regime', (dc.regime || 'unknown') + ' · ' + (dc.confidence || 'none')]);
        cells.push(['Pulso financeiro', dc.fresh ? 'atual' : 'fallback']);
        cells.push(['Viés de oferta', '+' + (dc.supplyBias || 0)]);
        cells.push(['Orçamento do corpo', ar.bodyBudget]);
        cells.push(['Planner (plan/rend/cap)', (ar.plannedBodyCount || 0) + '/' + (ar.renderedBodyCount || 0) + '/' + (ar.structuralBodyCapacity || 0)]);
        cells.push(['Ocupados total/corpo', (ar.occupiedTotal || 0) + '/' + (ar.occupiedBody || 0)]);
        cells.push(['Tipo do artigo', ar.type || '—']);
        cells.push(['Sinal de entrega', ar.auctionSignal || 'neutral']);
        cells.push(['Espaçamento mínimo', (rules.min_gap_px || 0) + 'px / ' + (rules.min_stream_gap_px || 0) + 'px']);
        cells.push(['Motivos', (dc.reasons || []).join(' · ') || '—']);
      }
      var waiting = c.waitReasons || {};
      Object.keys(waiting).forEach(function (reason) { cells.push([reason, waiting[reason]]); });
      var body = snapshot.articleStructure || {}, prose = body.article || {};
      cells.push(['Modo do tema', (body.theme || {}).deliveryMode || '—']);
      var startup = body.manualStartup || {};
      cells.push(['Motor manual', startup.apiAvailable ? 'inicializado' : 'indisponível']);
      cells.push(['Script do motor no HTML', startup.inlineScriptPresent ? 'presente' : 'ausente']);
      cells.push(['Recuperação do motor', startup.recoveryState || '—']);
      cells.push(['Hosts manuais no documento', startup.manualHosts]);
      cells.push(['Hosts ainda em template', startup.hostsWithPendingTemplate]);
      cells.push(['Parágrafos editoriais', prose.editorialParagraphs]);
      cells.push(['Classe apontada pelo Google', body.supportRequestedClassCount]);
      cells.push(['Scripts AdSense no DOM', (body.scripts || []).length]);
      var markers = body.autoPlacementMarkerSummary || {}, regions = markers.byRegion || {}, positions = markers.byProsePosition || {}, states = markers.insStatuses || {};
      cells.push(['Marcadores Google no DOM', markers.total]);
      cells.push(['Marcadores detalhados / limite', (markers.sampled || 0) + ' / ' + (markers.sampleLimit || 0) + (markers.truncated ? ' · amostra' : '')]);
      [['article-prose', 'Marcadores na raiz editorial'], ['auxiliary', 'Marcadores em auxiliares'], ['manual-host', 'Marcadores em hosts manuais'], ['outside-article', 'Marcadores fora da raiz']].forEach(function (entry) {
        cells.push([entry[1], (regions[entry[0]] || {}).markers]);
      });
      [['between', 'Marcadores entre P'], ['before-first', 'Marcadores antes do primeiro P'], ['after-last', 'Marcadores após o último P'], ['inside-p', 'Marcadores dentro de P'], ['no-p', 'Marcadores sem P de referência']].forEach(function (entry) {
        cells.push([entry[1], (positions[entry[0]] || {}).markers]);
      });
      cells.push(['INS em marcadores: filled', states.filled]);
      cells.push(['INS em marcadores: unfill-optimized', states['unfill-optimized']]);
      cells.push(['INS em marcadores: unfilled', states.unfilled]);
      cells.push(['INS em marcadores: status desconhecido', states.unknown]);
      cells.push(['INS filled entre P (DOM)', ((positions.between || {}).insStatuses || {}).filled]);
      summary.innerHTML = cells.map(function (cell) {
        var value = typeof cell[1] === 'number' ? cell[1] : (typeof cell[1] === 'string' ? String(cell[1]).replace(/[&<>"']/g, function (ch) { return '&#' + ch.charCodeAt(0) + ';'; }) : '—');
        return '<div style="padding:9px 10px;border:1px solid #dcdcde;border-radius:8px;background:#f8f8fa"><small style="display:block;color:#646970">' + cell[0] + '</small><strong style="font-size:18px">' + value + '</strong></div>';
      }).join('');
    }
  }
  document.addEventListener('click', function (event) {
    if (!event.target.closest || !event.target.closest('#wp-admin-bar-go-ads-inspect a')) return;
    event.preventDefault();
    if (!panel) {
      panel = document.createElement('dialog');
      panel.style.cssText = 'width:min(880px,90vw);max-height:80vh;padding:24px;border:1px solid #888;border-radius:12px;background:#fff;color:#15151a;z-index:2147483647;box-sizing:border-box;';
      panel.setAttribute('aria-label', 'Diagnóstico local de anúncios');
      var title = document.createElement('h2'); title.textContent = 'Anúncios: diagnóstico local';
      var note = document.createElement('p'); note.textContent = 'Leitura local do corpo, ancestrais e marcadores. Funciona também sem o motor manual. Entre P descreve ordem DOM entre parágrafos editoriais com texto, não visibilidade. O JSON distingue antes/depois da prosa, auxiliares e exterior; separa filled de unfill-optimized. Totais cobrem todos os marcadores; detalhes têm limite de amostra. Não mede receita, impressões oficiais, Active View ou configuração do Google. Não altera anúncios, criativos ou o armazenamento do Google.';
      summary = document.createElement('div'); summary.style.cssText = 'display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:8px;margin:14px 0;';
      output = document.createElement('pre'); output.style.cssText = 'white-space:pre-wrap;overflow-wrap:anywhere;max-height:48vh;overflow:auto;font:12px/1.5 monospace;text-align:left;background:#f4f4f7;padding:12px;';
      var refreshButton = document.createElement('button'); refreshButton.type = 'button'; refreshButton.textContent = 'Atualizar leitura'; refreshButton.addEventListener('click', refresh);
      var download = document.createElement('button'); download.type = 'button'; download.textContent = 'Exportar JSON';
      download.addEventListener('click', function () {
        refresh();
        var url = URL.createObjectURL(new Blob([JSON.stringify(snapshot, null, 2)], { type: 'application/json' }));
        var link = document.createElement('a'); link.href = url; link.download = 'overdrive-ads-dom.json'; link.click();
        window.setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
      });
      var explainButton = document.createElement('button'); explainButton.type = 'button'; explainButton.textContent = 'Explicar decisão';
      explainButton.addEventListener('click', function () {
        output.textContent = (window.GOAdsRuntime && window.GOAdsRuntime.explain)
          ? window.GOAdsRuntime.explain()
          : 'Runtime não encontrado nesta página.';
      });
      var close = document.createElement('button'); close.type = 'button'; close.textContent = 'Fechar';
      close.addEventListener('click', function () { if (panel.close) panel.close(); else panel.removeAttribute('open'); });
      [refreshButton, explainButton, download, close].forEach(function (button) { button.style.cssText = 'padding:8px 14px;margin:6px 8px 0 0;cursor:pointer;'; });
      panel.append(title, note, summary, output, refreshButton, explainButton, download, close); document.body.appendChild(panel);
    }
    refresh();
    if (panel.showModal) { if (!panel.open) panel.showModal(); } else panel.setAttribute('open', '');
  });
})();
