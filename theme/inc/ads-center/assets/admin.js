(function(){
  'use strict';
  var D = window.GOAC_DATA || {};
  var SVGNS = 'http://www.w3.org/2000/svg';
  var COLORS = { accent: '#421aff', 'accent-light': '#7c63ff', forecast: '#c4b8ff', orange: '#d9480f', muted: '#8c8f94', grid: '#ececef', axis: '#c3c4c7', goal: '#b32d2e', band: 'rgba(66,26,255,0.12)', cross: '#1d2327' };
  var MONTHS = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
  var WEEKDAYS = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

  function qs(sel, ctx){ return (ctx || document).querySelector(sel); }
  function qsa(sel, ctx){ return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }
  function isNum(v){ return typeof v === 'number' && isFinite(v); }
  function el(tag, cls, text, parent){ var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined && text !== null) e.textContent = text; if (parent) parent.appendChild(e); return e; }
  function svg(tag, attrs, parent){ var e = document.createElementNS(SVGNS, tag); Object.keys(attrs || {}).forEach(function(k){ if (attrs[k] !== null && attrs[k] !== undefined) e.setAttribute(k, attrs[k]); }); if (parent) parent.appendChild(e); return e; }
  function nulls(n){ var a = []; for (var i = 0; i < n; i++) a.push(null); return a; }

  /* ------------------------------------------------------------ Formatação */
  var nfCache = {};
  function nf(opts){ var k = JSON.stringify(opts); if (!nfCache[k]) { try { nfCache[k] = new Intl.NumberFormat('pt-BR', opts); } catch (e) { nfCache[k] = new Intl.NumberFormat(undefined, opts); } } return nfCache[k]; }
  function prefix(cur){ var map = { BRL: 'R$ ', USD: 'US$ ', EUR: '€ ', GBP: '£ ' }; cur = String(cur || '').toUpperCase(); return map[cur] || (cur ? cur + ' ' : ''); }
  function fmt(v, format, cur, compact){
    if (!isNum(v)) return '—';
    var abs = Math.abs(v), sign = v < 0 ? '-' : '';
    switch (format) {
      case 'money':
        if (compact && abs >= 10000) return sign + prefix(cur) + nf({ notation: 'compact', maximumFractionDigits: 1 }).format(abs);
        var dec = compact && abs >= 100 ? 0 : 2;
        return sign + prefix(cur) + nf({ minimumFractionDigits: dec, maximumFractionDigits: dec }).format(abs);
      case 'percent': return nf({ minimumFractionDigits: compact ? 0 : 1, maximumFractionDigits: compact ? 1 : 2 }).format(v * 100) + '%';
      case 'decimal': return nf({ maximumFractionDigits: 2 }).format(v);
      default:
        if (compact && abs >= 10000) return sign + nf({ notation: 'compact', maximumFractionDigits: 1 }).format(abs);
        return nf({ maximumFractionDigits: 0 }).format(v);
    }
  }
  function parseDate(s){ var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s || ''); return m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])) : null; }
  function labelText(label, type, long, pre){
    var s = String(label), d, m;
    if (type === 'date' || type === 'group') {
      d = parseDate(s);
      if (d) { var dd = ('0' + d.getUTCDate()).slice(-2), mm = ('0' + (d.getUTCMonth() + 1)).slice(-2); return long ? WEEKDAYS[d.getUTCDay()] + ', ' + dd + '/' + mm + '/' + d.getUTCFullYear() : dd + '/' + mm; }
      if (type === 'date') return s;
    }
    if (type === 'month' || type === 'group') {
      m = /^(\d{4})-(\d{2})$/.exec(s);
      if (m) return MONTHS[+m[2] - 1] + '/' + (long ? m[1] : m[1].slice(2));
      if (type === 'month') return s;
      return s.replace('-T', ' · T');
    }
    return (pre || '') + s;
  }
  function movingAverage(values, win){
    var out = [], sum = 0, count = 0, queue = [];
    values.forEach(function(v){
      var x = isNum(v) ? v : 0; queue.push(x); sum += x; count++;
      if (queue.length > win) { sum -= queue.shift(); count--; }
      out.push(queue.length === win ? sum / win : null);
    });
    return out;
  }

  /* ------------------------------------------------------------ Gráficos SVG */
  function niceMax(max){
    if (!(max > 0)) return 1;
    var exp = Math.pow(10, Math.floor(Math.log(max) / Math.LN10)), f = max / exp;
    var steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
    for (var i = 0; i < steps.length; i++) if (f <= steps[i] + 1e-9) return steps[i] * exp;
    return 10 * exp;
  }
  function colorOf(s){ return COLORS[s.color] || s.color || COLORS.accent; }
  function barPath(x, y, w, h){
    h = Math.max(h, 0.75); var r = Math.min(4, w / 2, h);
    return 'M' + x + ',' + (y + h) + 'V' + (y + r) + 'Q' + x + ',' + y + ' ' + (x + r) + ',' + y + 'H' + (x + w - r) + 'Q' + (x + w) + ',' + y + ' ' + (x + w) + ',' + (y + r) + 'V' + (y + h) + 'Z';
  }
  function legendKey(item, parent){
    var li = el('span', 'goac-legend-item', null, parent);
    var key = el('i', 'goac-legend-key is-' + (item.type === 'line' ? 'line' : 'bar') + (item.dashed ? ' is-dashed' : ''), null, li);
    if (item.type === 'line') key.style.borderColor = item.color; else key.style.background = item.color;
    el('span', null, item.name, li);
  }

  function renderChart(box, cfg){
    box.innerHTML = '';
    var labels = cfg.labels || [], n = labels.length, series = (cfg.series || []).filter(Boolean);
    if (!n) { el('p', 'goac-chart-fallback', 'Sem dados para exibir.', box); return; }
    var legend = [];
    series.forEach(function(s){
      if ((s.values || []).some(isNum)) legend.push({ name: s.name, type: s.type, color: colorOf(s), dashed: s.dashed });
      if (s.type === 'bar' && (s.forecast || []).some(isNum)) legend.push({ name: cfg.forecastLabel || 'Previsão', type: 'bar', color: COLORS.forecast });
    });
    if (cfg.goal && isNum(cfg.goal.value)) legend.push({ name: cfg.goal.label, type: 'line', color: COLORS.goal, dashed: true });
    if (legend.length > 1) { var lg = el('div', 'goac-legend', null, box); legend.forEach(function(item){ legendKey(item, lg); }); }

    var width = Math.max(240, box.clientWidth || 600), height = cfg.height || 260;
    var max = 0;
    series.forEach(function(s){ ['values', 'forecast', 'high'].forEach(function(k){ (s[k] || []).forEach(function(v){ if (isNum(v) && v > max) max = v; }); }); });
    if (cfg.goal && isNum(cfg.goal.value)) max = Math.max(max, cfg.goal.value);
    var yMax = isNum(cfg.yMax) && cfg.yMax >= max ? cfg.yMax : niceMax(max * 1.04), tickCount = height < 170 ? 2 : 4, ticks = [];
    for (var t = 0; t <= tickCount; t++) ticks.push(yMax * t / tickCount);
    var longest = ticks.reduce(function(a, v){ var s = fmt(v, cfg.format, cfg.currency, true); return s.length > a ? s.length : a; }, 0);
    var pad = { l: Math.min(96, 14 + longest * 6.6), r: 14, t: 12, b: 26 };
    var cw = width - pad.l - pad.r, ch = height - pad.t - pad.b, band = cw / n;
    var root = el('div', 'goac-chart-canvas', null, box);
    var s = svg('svg', { width: width, height: height, viewBox: '0 0 ' + width + ' ' + height, role: 'img', 'aria-label': cfg.ariaLabel || 'Gráfico' }, root);
    function xc(i){ return pad.l + band * (i + 0.5); }
    function yv(v){ return pad.t + ch - (Math.max(0, v) / yMax) * ch; }

    ticks.forEach(function(v){
      var y = Math.round(yv(v)) + 0.5;
      svg('line', { x1: pad.l, x2: width - pad.r, y1: y, y2: y, stroke: v === 0 ? COLORS.axis : COLORS.grid, 'stroke-width': 1 }, s);
      svg('text', { x: pad.l - 8, y: y + 4, 'text-anchor': 'end', 'class': 'goac-svg-tick' }, s).textContent = fmt(v, cfg.format, cfg.currency, true);
    });
    var minGap = cfg.labelType === 'text' ? 44 : 54, step = Math.max(1, Math.ceil(minGap / band));
    for (var i = 0; i < n; i++) {
      var isLast = i === n - 1;
      if (i % step !== 0 && !isLast) continue;
      if (isLast && i % step !== 0 && (i % step) < step * 0.6) continue;
      svg('text', { x: xc(i), y: height - 8, 'text-anchor': 'middle', 'class': 'goac-svg-tick' }, s).textContent = labelText(labels[i], cfg.labelType, false, cfg.labelPrefix);
    }
    if (cfg.today) {
      var ti = labels.indexOf(cfg.today);
      if (ti >= 0 && ti < n - 1) svg('line', { x1: xc(ti) + band / 2, x2: xc(ti) + band / 2, y1: pad.t, y2: pad.t + ch, stroke: COLORS.axis, 'stroke-width': 1, 'stroke-dasharray': '2 3' }, s);
    }

    var bars = series.filter(function(x){ return x.type === 'bar'; }), nb = Math.max(1, bars.length);
    var bw = Math.max(1.5, Math.min(24, (band * 0.74 - (nb - 1) * 2) / nb));
    bars.forEach(function(sr, si){
      var offset = (si - (nb - 1) / 2) * (bw + 2);
      for (var i = 0; i < n; i++) {
        var v = sr.values ? sr.values[i] : null, f = sr.forecast ? sr.forecast[i] : null, x = xc(i) + offset - bw / 2;
        if (isNum(f) && f > 0) svg('path', { d: barPath(x, yv(f), bw, yv(0) - yv(f)), fill: COLORS.forecast }, s);
        if (isNum(v) && v > 0) svg('path', { d: barPath(x, yv(v), bw, yv(0) - yv(v)), fill: colorOf(sr), 'fill-opacity': labels[i] === cfg.today && isNum(f) ? 1 : (labels[i] === cfg.today ? 0.7 : 1) }, s);
        if (isNum(f) && sr.low && sr.high && isNum(sr.low[i]) && isNum(sr.high[i]) && bw >= 4) {
          var cx = x + bw / 2, y1 = yv(sr.low[i]), y2 = yv(sr.high[i]), cap = Math.min(6, bw / 2);
          svg('path', { d: 'M' + cx + ',' + y1 + 'V' + y2 + 'M' + (cx - cap) + ',' + y2 + 'H' + (cx + cap) + 'M' + (cx - cap) + ',' + y1 + 'H' + (cx + cap), stroke: COLORS['accent-light'], 'stroke-width': 1.25, fill: 'none' }, s);
        }
      }
    });

    series.filter(function(x){ return x.type === 'line'; }).forEach(function(sr){
      var color = colorOf(sr), vals = sr.values || [];
      if (sr.low && sr.high) {
        var top = [], bottom = [];
        for (var i = 0; i < n; i++) if (isNum(sr.low[i]) && isNum(sr.high[i])) { top.push([xc(i), yv(sr.high[i])]); bottom.push([xc(i), yv(sr.low[i])]); }
        if (top.length > 1) svg('path', { d: 'M' + top.map(function(p){ return p.join(','); }).join('L') + 'L' + bottom.reverse().map(function(p){ return p.join(','); }).join('L') + 'Z', fill: COLORS.band, stroke: 'none' }, s);
      }
      var d = '', open = false, lastI = -1;
      for (var j = 0; j < n; j++) {
        if (isNum(vals[j])) { d += (open ? 'L' : 'M') + xc(j) + ',' + yv(vals[j]); open = true; lastI = j; } else { open = false; }
      }
      if (d) svg('path', { d: d, fill: 'none', stroke: color, 'stroke-width': 2, 'stroke-linejoin': 'round', 'stroke-linecap': 'round', 'stroke-dasharray': sr.dashed ? '6 4' : null }, s);
      if (lastI >= 0 && n <= 120) svg('circle', { cx: xc(lastI), cy: yv(vals[lastI]), r: 4, fill: color, stroke: '#fff', 'stroke-width': 2 }, s);
    });

    if (cfg.goal && isNum(cfg.goal.value)) {
      var gy = yv(cfg.goal.value);
      svg('line', { x1: pad.l, x2: width - pad.r, y1: gy, y2: gy, stroke: COLORS.goal, 'stroke-width': 1.5, 'stroke-dasharray': '6 4' }, s);
      svg('text', { x: width - pad.r, y: gy - 6, 'text-anchor': 'end', 'class': 'goac-svg-goal' }, s).textContent = cfg.goal.label + ': ' + fmt(cfg.goal.value, cfg.format, cfg.currency);
    }

    var cross = svg('line', { y1: pad.t, y2: pad.t + ch, stroke: COLORS.cross, 'stroke-width': 1, opacity: 0, 'pointer-events': 'none' }, s);
    var overlay = svg('rect', { x: pad.l, y: pad.t, width: cw, height: ch, fill: 'transparent', tabindex: 0, 'aria-label': 'Explorar valores: use as setas' }, s);
    var tip = el('div', 'goac-tooltip', null, root); tip.hidden = true;
    var current = -1;
    function row(color, type, dashed, value, name){
      var r = el('div', 'goac-tooltip-row', null, tip);
      var k = el('i', 'goac-legend-key is-line' + (dashed ? ' is-dashed' : ''), null, r); k.style.borderColor = color;
      el('strong', null, value, r); el('span', null, name, r);
    }
    function show(i){
      if (i < 0 || i >= n) return;
      current = i; var x = xc(i);
      cross.setAttribute('x1', x); cross.setAttribute('x2', x); cross.setAttribute('opacity', 0.28);
      tip.innerHTML = '';
      el('div', 'goac-tooltip-title', labelText(labels[i], cfg.labelType, true, cfg.labelPrefix) + (labels[i] === cfg.today ? ' · parcial' : ''), tip);
      series.forEach(function(sr){
        var f2 = sr.format || cfg.format, v = sr.values ? sr.values[i] : null, f = sr.forecast ? sr.forecast[i] : null;
        if (isNum(v)) {
          var txt = fmt(v, f2, cfg.currency);
          if (sr.type === 'line' && sr.low && isNum(sr.low[i]) && isNum(sr.high[i])) txt += ' (' + fmt(sr.low[i], f2, cfg.currency) + ' – ' + fmt(sr.high[i], f2, cfg.currency) + ')';
          row(colorOf(sr), sr.type, sr.dashed, txt, sr.name);
        }
        if (isNum(f)) row(COLORS.forecast, 'bar', false, fmt(f, f2, cfg.currency) + (sr.low && isNum(sr.low[i]) && isNum(sr.high[i]) ? ' (' + fmt(sr.low[i], f2, cfg.currency) + ' – ' + fmt(sr.high[i], f2, cfg.currency) + ')' : ''), cfg.forecastLabel || 'Previsão');
      });
      if (cfg.goal && isNum(cfg.goal.value)) row(COLORS.goal, 'line', true, fmt(cfg.goal.value, cfg.format, cfg.currency), cfg.goal.label);
      tip.hidden = false;
      var tw = tip.offsetWidth, left = x + 14;
      if (left + tw > width) left = x - tw - 14;
      tip.style.left = Math.max(0, left) + 'px'; tip.style.top = pad.t + 'px';
    }
    function hide(){ cross.setAttribute('opacity', 0); tip.hidden = true; }
    overlay.addEventListener('pointermove', function(e){ var r = s.getBoundingClientRect(); show(Math.max(0, Math.min(n - 1, Math.floor((e.clientX - r.left - pad.l) / band)))); });
    overlay.addEventListener('pointerleave', hide);
    overlay.addEventListener('focus', function(){ show(current >= 0 ? current : n - 1); });
    overlay.addEventListener('blur', hide);
    overlay.addEventListener('keydown', function(e){
      if (e.key === 'ArrowLeft') { show(Math.max(0, current - 1)); e.preventDefault(); }
      else if (e.key === 'ArrowRight') { show(Math.min(n - 1, current + 1)); e.preventDefault(); }
      else if (e.key === 'Escape') { hide(); }
    });
  }

  function chartHeight(box, fallback){ var h = parseInt(box.style.minHeight, 10); return h > 80 ? h - 36 : fallback; }

  /** Gráficos com várias métricas (Visão geral e Dias): monta a configuração a partir do conjunto de dados. */
  function datasetConfig(box){
    var ds; try { ds = JSON.parse(box.getAttribute('data-goac-dataset') || '{}'); } catch (e) { return null; }
    if (!ds.metrics) return null;
    var key = box.getAttribute('data-metric') || 'earnings', m = ds.metrics[key] || ds.metrics.earnings;
    var actual = isNum(ds.actualCount) ? ds.actualCount : (m.values || []).length;
    var range = box.getAttribute('data-range') || 'all', start = range === 'all' ? 0 : Math.max(0, actual - parseInt(range, 10));
    var values = (m.values || []).slice(start, actual), fc = m.forecast || [], hasF = fc.some(isNum);
    var future = hasF ? fc.length : 0, labels = ds.labels.slice(start, actual + future);
    var series = [{ name: m.name, type: 'bar', format: m.format, values: values.concat(nulls(future)), forecast: hasF ? nulls(values.length).concat(fc) : null, low: hasF && m.low ? nulls(values.length).concat(m.low) : null, high: hasF && m.high ? nulls(values.length).concat(m.high) : null }];
    var ma = ds.ma === undefined ? 7 : ds.ma;
    if (ma > 0 && actual >= ma * 2) series.push({ name: 'Média móvel ' + ma + ' dias', type: 'line', color: 'orange', format: m.format, values: movingAverage(m.values || [], ma).slice(start, actual).concat(nulls(future)) });
    if (m.compare) series.push({ name: m.compareName || 'Período anterior', type: 'line', color: 'muted', format: m.format, values: m.compare.slice(start, actual).concat(nulls(future)) });
    return { labels: labels, labelType: ds.labelType || 'date', format: m.format, currency: ds.currency || D.currency, today: ds.today, series: series, height: chartHeight(box, 290), forecastLabel: 'Previsão' };
  }

  function drawBox(box){
    try {
      if (box.hasAttribute('data-goac-dataset')) { var cfg = datasetConfig(box); if (cfg) renderChart(box, cfg); return; }
      var c = JSON.parse(box.getAttribute('data-goac-chart') || '{}');
      if (!c.currency) c.currency = D.currency;
      renderChart(box, c);
    } catch (err) {
      box.innerHTML = ''; el('p', 'goac-chart-fallback', 'Não foi possível desenhar o gráfico.', box);
      if (window.console) console.error('GOAC chart', err);
    }
  }
  function drawAll(){ qsa('.goac-chart').forEach(drawBox); }

  function initSwitches(){
    qsa('[data-goac-switch]').forEach(function(group){
      var target = document.getElementById(group.getAttribute('data-target')), attr = group.getAttribute('data-goac-switch');
      if (!target) return;
      group.addEventListener('click', function(e){
        var b = e.target.closest('button'); if (!b || !group.contains(b)) return;
        qsa('button', group).forEach(function(x){ x.classList.toggle('is-active', x === b); x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); });
        target.setAttribute('data-' + attr, b.getAttribute('data-value'));
        drawBox(target);
      });
    });
  }

  /* ------------------------------------------------------------ Tabelas */
  function initTables(ctx){
    qsa('table.goac-sortable', ctx).forEach(function(table){
      if (table.getAttribute('data-goac-sort-ready')) return;
      table.setAttribute('data-goac-sort-ready', '1');
      var heads = qsa('thead tr:first-child th', table);
      heads.forEach(function(th, idx){
        function sort(){
          var tbody = table.tBodies[0]; if (!tbody) return;
          var type = th.getAttribute('data-sort-type') || 'text', was = th.getAttribute('aria-sort');
          var dir = was ? (was === 'descending' ? 'ascending' : 'descending') : (type === 'num' ? 'descending' : 'ascending');
          heads.forEach(function(h){ h.removeAttribute('aria-sort'); });
          th.setAttribute('aria-sort', dir);
          var rows = qsa(':scope > tr', tbody);
          function val(tr){ var c = tr.children[idx]; if (!c) return ''; return c.hasAttribute('data-sort') ? c.getAttribute('data-sort') : c.textContent.trim(); }
          rows.sort(function(a, b){
            var va = val(a), vb = val(b), r;
            if (type === 'num') {
              var na = va === '' ? null : parseFloat(va), nb = vb === '' ? null : parseFloat(vb);
              if (na === null || isNaN(na)) return (nb === null || isNaN(nb)) ? 0 : 1;
              if (nb === null || isNaN(nb)) return -1;
              r = na - nb;
            } else {
              r = String(va).localeCompare(String(vb), 'pt-BR', { numeric: true, sensitivity: 'base' });
            }
            return dir === 'ascending' ? r : -r;
          });
          rows.forEach(function(r){ tbody.appendChild(r); });
        }
        th.addEventListener('click', sort);
        th.addEventListener('keydown', function(e){ if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sort(); } });
      });
    });
    qsa('[data-goac-table-search]', ctx).forEach(function(input){
      var table = document.getElementById(input.getAttribute('data-goac-table-search'));
      if (!table || input.getAttribute('data-goac-ready')) return;
      input.setAttribute('data-goac-ready', '1');
      input.addEventListener('input', function(){
        var q = input.value.trim().toLowerCase();
        qsa('tbody tr', table).forEach(function(tr){ tr.hidden = !!q && tr.textContent.toLowerCase().indexOf(q) === -1; });
      });
    });
  }

  /* ------------------------------------------------------------ AJAX */
  function post(action, params){
    var body = new URLSearchParams();
    body.set('action', action); body.set('nonce', D.nonce || '');
    Object.keys(params || {}).forEach(function(k){ if (params[k] !== undefined && params[k] !== null && params[k] !== '') body.set(k, params[k]); });
    return fetch(D.ajax, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }, body: body.toString() })
      .then(function(r){ return r.json().catch(function(){ throw new Error('resposta inválida (HTTP ' + r.status + ')'); }); })
      .then(function(res){ if (!res || !res.success) throw new Error((res && res.data && res.data.message) || 'falha na requisição'); return res.data; });
  }

  function initLive(){
    var block = qs('[data-goac-live-block]');
    if (!block || !D.connected) return;
    var last = Date.now(), every = Math.max(1, Number(D.refreshMinutes) || 5) * 60000, busy = false;
    function refresh(){
      if (busy) return; busy = true;
      block.classList.add('is-updating');
      post('goac_live_snapshot', {}).then(function(data){
        block.innerHTML = data.html;
        var f = qs('#goac-fetched');
        if (f) { f.textContent = data.fetchedAt + (data.error ? ' · não atualizou: ' + data.error : ''); f.classList.toggle('goac-live-error', !!data.error); }
      }).catch(function(err){
        var f = qs('#goac-fetched'); if (f) { f.textContent = 'Falha ao atualizar: ' + err.message; f.classList.add('goac-live-error'); }
      }).then(function(){ busy = false; last = Date.now(); block.classList.remove('is-updating'); });
    }
    setInterval(function(){ if (document.visibilityState === 'visible' && Date.now() - last >= every) refresh(); }, 15000);
    document.addEventListener('visibilitychange', function(){ if (document.visibilityState === 'visible' && Date.now() - last >= every) refresh(); });
  }

  function initBackfill(){
    var boxes = qsa('[data-goac-backfill]');
    if (!boxes.length || !D.connected) return;
    var failures = 0;
    function update(data){
      boxes.forEach(function(b){
        var bar = qs('.goac-meter i', b); if (bar) bar.style.width = Math.round((data.progress || 0) * 100) + '%';
        var t = qs('[data-goac-backfill-text]', b); if (t) t.textContent = data.text;
      });
    }
    function step(){
      post('goac_backfill_step', {}).then(function(data){
        failures = 0; update(data);
        if (data.state === 'running') { setTimeout(step, data.locked ? 5000 : 800); return; }
        boxes.forEach(function(b){
          var t = qs('[data-goac-backfill-text]', b); if (!t) return;
          t.appendChild(document.createTextNode(' '));
          var a = el('a', 'button button-small', 'Recarregar', t); a.href = window.location.href;
        });
      }).catch(function(err){
        failures++;
        update({ progress: 0, text: 'Importação pausada: ' + err.message + (failures < 5 ? ' (tentando de novo…)' : '') });
        if (failures < 5) setTimeout(step, 10000 * failures);
      });
    }
    step();
  }

  function loadAsync(box){
    var params = { block: box.getAttribute('data-goac-async') };
    if (params.block === 'top') { params.dimension = box.getAttribute('data-dimension'); params.period = box.getAttribute('data-period'); }
    box.classList.add('is-loading');
    return post('goac_async', params).then(function(d){ box.innerHTML = d.html; initTables(box); })
      .catch(function(err){ box.innerHTML = ''; el('p', 'goac-empty-inline', 'Não foi possível carregar: ' + err.message, box); })
      .then(function(){ box.classList.remove('is-loading'); });
  }

  function initAsync(){
    qsa('[data-goac-async]').forEach(loadAsync);
    qsa('.goac-tops').forEach(function(card){
      var box = qs('[data-goac-async="top"]', card), tabs = qs('[data-goac-top-tabs]', card), period = qs('[data-goac-top-period]', card);
      if (!box) return;
      if (tabs) tabs.addEventListener('click', function(e){
        var b = e.target.closest('button'); if (!b) return;
        qsa('button', tabs).forEach(function(x){ x.classList.toggle('is-active', x === b); x.setAttribute('aria-selected', x === b ? 'true' : 'false'); });
        box.setAttribute('data-dimension', b.getAttribute('data-value')); loadAsync(box);
      });
      if (period) period.addEventListener('change', function(){ box.setAttribute('data-period', period.value); loadAsync(box); });
    });
  }

  /* ------------------------------------------------------------ Formulários */
  function initPeriodForms(){
    qsa('[data-goac-period-form]').forEach(function(form){
      var sel = qs('[data-goac-preset]', form); if (!sel) return;
      var map = {}; try { map = JSON.parse(sel.getAttribute('data-goac-preset')); } catch (e) {}
      var from = qs('input[name="from"]', form), to = qs('input[name="to"]', form), inc = qs('[data-goac-include-today]', form);
      function apply(){ var m = map[sel.value]; if (!m || !from || !to) return; from.value = m[0]; to.value = inc && inc.checked ? m[2] : m[1]; }
      sel.addEventListener('change', apply);
      if (inc) inc.addEventListener('change', function(){ if (sel.value !== 'custom') apply(); });
      [from, to].forEach(function(input){ if (input) input.addEventListener('change', function(){ sel.value = 'custom'; }); });
    });
  }
  function initBudget(){
    qsa('[data-goac-budget-form]').forEach(function(form){
      var body = qs('[data-goac-expense-rows]', form), tpl = qs('[data-goac-expense-template]', form), add = qs('[data-goac-add-expense]', form);
      if (!body || !tpl || !add) return;
      var seq = Date.now();
      add.addEventListener('click', function(){
        seq += 1;
        var html = tpl.innerHTML.replace(/__INDEX__/g, 'new_' + seq);
        body.insertAdjacentHTML('beforeend', html);
        var rows = qsa('[data-goac-expense-row]', body), row = rows[rows.length - 1];
        var input = row ? qs('input[name*="[description]"]', row) : null; if (input) input.focus();
      });
      body.addEventListener('click', function(e){
        var btn = e.target.closest ? e.target.closest('[data-goac-remove-expense]') : null;
        if (!btn) return;
        var row = btn.closest('[data-goac-expense-row]'); if (row) row.remove();
      });
    });
  }

  function initUnitSelect(){ var s = qs('#goac-unit-select'); if (!s) return; function sync(){ var o = s.options[s.selectedIndex], n = qs('#goac-unit-name'), st = qs('#goac-unit-state'); if (n) n.value = o.getAttribute('data-name') || ''; if (st) st.value = ''; } s.addEventListener('change', sync); sync(); }
  function initChannelSelect(){ var s = qs('#goac-channel-select'); if (!s) return; function sync(){ var o = s.options[s.selectedIndex], n = qs('#goac-channel-name'), st = qs('#goac-channel-active'); if (n) n.value = o.getAttribute('data-name') || ''; if (st) st.value = 'keep'; } s.addEventListener('change', sync); sync(); }
  document.addEventListener('click', function(e){
    var t = e.target.closest ? e.target.closest('[data-goac-confirm]') : null;
    if (t && !window.confirm(t.getAttribute('data-goac-confirm'))) e.preventDefault();
  });

  function init(){
    drawAll(); initSwitches(); initTables(document); initPeriodForms(); initBudget(); initUnitSelect(); initChannelSelect();
    initAsync(); initLive(); initBackfill();
    var timer, lastWidth = window.innerWidth;
    window.addEventListener('resize', function(){ clearTimeout(timer); timer = setTimeout(function(){ if (window.innerWidth !== lastWidth) { lastWidth = window.innerWidth; drawAll(); } }, 150); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
