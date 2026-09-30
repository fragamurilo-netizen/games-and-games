/* Fight Night broadcast shell. Uses the ORIGINAL Fight Studio renderer, identity,
   animation sampler and the immutable Godot replay: nothing here decides or alters
   a result. It stages the night around it — walkouts, tale of the tape, a fictional
   ring announcer, round breaks, finish replay and the verdict (Bible §§6,10,15–17).
   Presentation language studied from UFC Undisputed 3; every name, voice line,
   brand and person is a Corner Office original (Bible §22). */
(async () => {
  const $ = id => document.getElementById(id);
  const json = id => JSON.parse($(id).textContent);
  const read = async path => { const r = await fetch('../../game/content/' + path); if (!r.ok) throw new Error('Conteúdo indisponível.'); return r.json(); };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const clock = s => `${Math.floor(Math.max(0, s) / 60)}:${String(Math.floor(Math.max(0, s) % 60)).padStart(2, '0')}`;
  const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };

  const ANNOUNCER = 'DARIO VALENTE · VOZ OFICIAL';
  const REFEREES = ['Hélio Matos', 'Rachel Duarte', 'Kenji Mori', 'Tom Barrett', 'Aleks Petrov', 'Lúcia Brandão'];
  const JUDGES = ['Paulo Riedel', 'Ana Seixas', 'Mark Hollis', 'Yuki Sato', 'Beatriz Lemos', 'Owen Clarke'];
  const OUTCOME = { completed: 'Concluído', landed: 'Conectou', missed: 'Errou', evaded: 'Esquiva', blocked: 'Bloqueado', defended: 'Defendido', escaped: 'Escapou', held: 'Controle', threatened: 'Ameaça de finalização', tapped: 'Desistência', knockdown: 'Knockdown', stoppage: 'Interrupção' };
  const DIVISION = { m_flyweight: 'peso-mosca', m_bantamweight: 'peso-galo', m_featherweight: 'peso-pena', m_lightweight: 'peso-leve', m_welterweight: 'peso meio-médio', m_middleweight: 'peso-médio', m_light_heavyweight: 'peso meio-pesado', m_heavyweight: 'peso-pesado', w_strawweight: 'peso-palha feminino', w_flyweight: 'peso-mosca feminino', w_bantamweight: 'peso-galo feminino', w_featherweight: 'peso-pena feminino' };
  const BASE = { boxing: 'Boxe', muay_thai: 'Muay thai', kickboxing: 'Kickboxing', karate: 'Karatê', taekwondo: 'Taekwondo', wrestling: 'Wrestling', bjj: 'Jiu-jítsu', judo: 'Judô', sambo: 'Sambo', mma: 'MMA completo' };
  const STANCE = { orthodox: 'Ortodoxa', southpaw: 'Canhota', switch: 'Alterna' };
  const COUNTRY = { BR: 'Brasil', US: 'Estados Unidos', MX: 'México', KZ: 'Cazaquistão', JP: 'Japão', GB: 'Reino Unido', RS: 'Sérvia', AU: 'Austrália', NZ: 'Nova Zelândia', IE: 'Irlanda', FR: 'França', DE: 'Alemanha', PL: 'Polônia', RU: 'Rússia', GE: 'Geórgia', KR: 'Coreia do Sul', CN: 'China', AR: 'Argentina', CO: 'Colômbia', PE: 'Peru', CA: 'Canadá', ES: 'Espanha', IT: 'Itália', NL: 'Holanda', SE: 'Suécia', UZ: 'Uzbequistão', KG: 'Quirguistão', AE: 'Emirados Árabes', PH: 'Filipinas', TH: 'Tailândia', NG: 'Nigéria', CM: 'Camarões' };
  const SLOT = { main_event: 'a luta principal', co_main: 'a luta co-principal', main_card: 'uma luta do card principal', prelims: 'uma luta do card preliminar' };
  const ORD = ['', 'primeiro', 'segundo', 'terceiro', 'quarto', 'quinto'];
  const flag = cc => cc && cc.length === 2 ? String.fromCodePoint(...[...cc.toUpperCase()].map(ch => 0x1F1E6 + ch.charCodeAt(0) - 65)) : '';

  let player, renderer, replay, catalog, arena, appearance, P, RED, BLUE;
  let time = 0, playing = false, last = 0, speed = 1, slow = 1, phase = 'loading';
  let replayEnd = null, curRound = 1, lastIndex = -1, lastSmall = 0, subWarned = false;
  const cam = { zoom: 1.3, focusX: 0, lift: 0.3, shake: 0, target: null };

  // ---------------------------------------------------------------- audio (synthesized, offline)
  const audio = {
    ctx: null, muted: false, crowdGain: null, beatTimer: null,
    init() {
      if (this.ctx || this.muted) return;
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext; if (!Ctx) return;
        const ctx = this.ctx = new Ctx();
        const buf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate), d = buf.getChannelData(0);
        let b0 = 0, b1 = 0; for (let i = 0; i < d.length; i++) { const w = Math.random() * 2 - 1; b0 = .99 * b0 + w * .07; b1 = .96 * b1 + w * .15; d[i] = (b0 + b1) * .6; }
        const src = ctx.createBufferSource(); src.buffer = buf; src.loop = true;
        const band = ctx.createBiquadFilter(); band.type = 'bandpass'; band.frequency.value = 650; band.Q.value = .5;
        this.crowdGain = ctx.createGain(); this.crowdGain.gain.value = 0;
        src.connect(band).connect(this.crowdGain).connect(ctx.destination); src.start();
        this.swell(.05, 1.5);
      } catch (e) { this.ctx = null; }
    },
    swell(level, secs = .6) { if (!this.ctx || this.muted) return; const g = this.crowdGain.gain, t = this.ctx.currentTime; g.cancelScheduledValues(t); g.setValueAtTime(g.value, t); g.linearRampToValueAtTime(level, t + secs); },
    tone(freq, dur, vol, type = 'sine', when = 0, slideTo = null) {
      if (!this.ctx || this.muted) return; const c = this.ctx, t = c.currentTime + when;
      const o = c.createOscillator(), g = c.createGain(); o.type = type; o.frequency.setValueAtTime(freq, t);
      if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
      g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.0001, t + dur); o.connect(g).connect(c.destination); o.start(t); o.stop(t + dur + .05);
    },
    bell(n = 3) { for (let i = 0; i < n; i++) { this.tone(1180, 1.4, .22, 'sine', i * .32); this.tone(3250, .9, .07, 'sine', i * .32); this.tone(590, 1.1, .08, 'triangle', i * .32); } },
    hit(power = 1) { this.tone(95, .22, .45 * power, 'sine', 0, 38); this.tone(900, .05, .12 * power, 'square'); },
    whoosh() { this.tone(300, .35, .06, 'sawtooth', 0, 1400); },
    beat(on) {
      clearInterval(this.beatTimer); this.beatTimer = null; if (!on || !this.ctx || this.muted) return;
      let step = 0; this.beatTimer = setInterval(() => { if (step % 4 === 0) this.tone(120, .28, .5, 'sine', 0, 42); if (step % 4 === 2) this.tone(180, .12, .12, 'square', 0, 90); this.tone(7000, .03, .02, 'square'); step++; }, 235);
    },
    mute(m) { this.muted = m; if (m) { this.beat(false); if (this.ctx) this.crowdGain.gain.value = 0; try { speechSynthesis.cancel(); } catch (e) {} } else { this.init(); this.swell(.05); } },
  };

  // ---------------------------------------------------------------- announcer (subtitle + optional pt-BR voice)
  const stretchLast = name => { const parts = name.toUpperCase().split(' '); const lastW = parts.pop(); const m = lastW.match(/^(.*?)([AEIOUÁÉÍÓÚÂÊÔÃÕ])([^AEIOUÁÉÍÓÚÂÊÔÃÕ]*)$/); const s = m ? m[1] + m[2].repeat(4) + m[3] : lastW; return [parts.join(' '), s]; };
  let voice = null;
  try { const pick = () => { voice = speechSynthesis.getVoices().find(v => /pt[-_]BR/i.test(v.lang)) || speechSynthesis.getVoices().find(v => /^pt/i.test(v.lang)) || null; }; pick(); speechSynthesis.onvoiceschanged = pick; } catch (e) {}
  function say(text, opts = {}) {
    const box = $('announcer'); box.hidden = false; $('speaker').textContent = opts.speaker || ANNOUNCER;
    const line = $('line'); line.replaceChildren();
    if (opts.stretch) { const [first, s] = stretchLast(opts.stretch); line.append(el('span', null, (text ? text + ' ' : '') + first + ' '), el('span', 'stretch', s + '!')); }
    else line.textContent = text;
    const spoken = opts.stretch ? `${text} ${opts.stretch}!` : text;
    const base = clamp(spoken.length * 62, 1500, 5200) + (opts.stretch ? 900 : 0);
    return new Promise(done => {
      let finished = false; const end = () => { if (!finished) { finished = true; done(); } };
      if (!audio.muted && voice && window.speechSynthesis) {
        try { const u = new SpeechSynthesisUtterance(spoken); u.voice = voice; u.lang = voice.lang; u.rate = .92; u.pitch = .72; u.onend = () => setTimeout(end, 250); speechSynthesis.cancel(); speechSynthesis.speak(u); setTimeout(end, base + 4000); return; } catch (e) {}
      }
      setTimeout(end, base);
    });
  }
  const quiet = () => { $('announcer').hidden = true; try { speechSynthesis.cancel(); } catch (e) {} };

  // ---------------------------------------------------------------- show control (tap advances, PULAR skips)
  let skipper = null, advance = null;
  class Skip extends Error {}
  const hold = (ms) => new Promise((ok, fail) => { const t = setTimeout(ok, ms); advance = () => { clearTimeout(t); ok(); }; skipper = () => { clearTimeout(t); fail(new Skip()); }; });
  const step = async (promise, minMs = 0) => { const guard = new Promise((_, fail) => { skipper = () => fail(new Skip()); }); const adv = new Promise(ok => { advance = ok; }); await Promise.race([Promise.all([promise, new Promise(r => setTimeout(r, minMs))]), guard, adv]); };
  $('stage').addEventListener('click', e => { if ((phase === 'show' || phase === 'break') && !e.target.closest('button') && advance) advance(); });
  $('skip').onclick = () => { if (skipper) skipper(); };
  const show = (...nodes) => { $('show').replaceChildren(...nodes); };
  const callout = (text, kind = '') => { const n = el('div', 'bang ' + kind, text); $('callout').replaceChildren(n); };

  // ---------------------------------------------------------------- content
  $('back').onclick = () => { audio.beat(false); try { speechSynthesis.cancel(); } catch (e) {} if (window.CornerOffice) window.CornerOffice.close(); else if (window.ipc) window.ipc.postMessage('close'); else if (location.protocol === 'file:') window.close(); else location.href = '../promoter/'; };
  $('mute').onclick = () => { const m = !audio.muted; audio.mute(m); $('mute').setAttribute('aria-pressed', String(m)); };
  try {
    const bundled = !!$('co-catalog');
    catalog = bundled ? json('co-catalog') : await read('fight_visuals.json');
    const arenas = bundled ? json('co-arenas') : await read('arena_profiles.json');
    if (bundled) replay = json('co-replay');
    else {
      const id = new URLSearchParams(location.search).get('career_fight');
      if (id) {
        const response = await fetch('/api/career', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'replay', fight_id: id }) });
        const data = await response.json(); if (!response.ok || !data.replay) throw new Error(data.error || 'Replay indisponível.'); replay = data.replay;
      } else replay = await read('replays/' + (new URLSearchParams(location.search).get('replay') || 'sim_women') + '.json');
    }
    player = new FightReplay.Player(replay, catalog, arenas);
    arena = FightReplay.arenaFor(replay, arenas);
    [RED, BLUE] = replay.fighter_ids;
    appearance = Object.fromEntries(replay.fighter_ids.map(id => [id, FightAppearance.resolve(replay.fighters[id], CANON, genFace)]));
    P = replay.presentation || {};
    renderer = new FightRenderer($('fight')); renderer.camera = 'broadcast'; renderer.hud = false; renderer.view = cam;
    $('seek').max = player.duration;
  } catch (error) { $('error').textContent = error.message; $('error').hidden = false; return; }

  const F = id => replay.fighters[id];
  const name = id => appearance[id].name || F(id).name;
  const rounds = replay.scheduled_rounds || 3;
  const division = DIVISION[F(RED).division] || '';
  const orgName = (arena && (arena.short_name || arena.name)) || '';
  const eventName = P.event_name || (replay.organization?.name ? replay.organization.name + ' · Fight Night' : orgName + ' Fight Night');
  const title = ['title', 'interim'].includes(P.title_stakes);
  const refName = REFEREES[Math.abs(replay.seed || 0) % REFEREES.length];
  $('eventline').textContent = [eventName, P.city || arena?.city, P.card_slot ? SLOT[P.card_slot]?.replace(/^(a|uma) /, '') : null].filter(Boolean).join(' · ');
  $('gate-title').textContent = `${name(RED).split(' ').pop()} × ${name(BLUE).split(' ').pop()}`.toUpperCase();
  $('gate-sub').textContent = [eventName, division, `${rounds} rounds`, title ? 'disputa de cinturão' : null].filter(Boolean).join(' · ');
  document.body.dataset.phase = phase = 'gate';

  // timeline marks: rounds and knockdowns
  (() => {
    const marks = $('marks'); let lastR = 1;
    for (const e of replay.events) {
      if (e.round !== lastR) { const i = el('i', 'rd'); i.style.left = (100 * e.at_ms / player.duration) + '%'; marks.append(i); lastR = e.round; }
      if (e.outcome === 'knockdown' || e.outcome === 'stoppage' || e.outcome === 'tapped') { const i = el('i', 'kd'); i.style.left = (100 * e.at_ms / player.duration) + '%'; marks.append(i); }
    }
  })();

  // ---------------------------------------------------------------- per-round and fight stats (counted from the engine's own log)
  const family = id => catalog.clips.find(c => c.id === id)?.family;
  function roundStats(r) {
    const s = {}; for (const id of replay.fighter_ids) s[id] = { att: 0, land: 0, td: 0, sub: 0, kd: 0 };
    let prev = null;
    for (const e of replay.events) {
      if (r && e.round !== r) { prev = e; continue; }
      const f = family(e.technique_id), a = s[e.actor_id]; if (!a) { prev = e; continue; }
      if (f === 'strike' || f === 'kick') { a.att++; if (['landed', 'knockdown', 'stoppage'].includes(e.outcome)) a.land++; }
      if (f === 'entry' && e.outcome === 'completed') a.td++;
      const sub = e.before?.submission || {};
      if (f === 'submission' && (!sub.attacker_id || sub.attacker_id !== e.actor_id)) a.sub++;
      if (e.outcome === 'knockdown') a.kd++;
      prev = e;
    }
    return s;
  }
  function lastOfRound(r) { let x = null; for (const e of replay.events) if (e.round === r) x = e; return x; }
  const dmgTotal = d => d ? Math.round(100 * (d.head * .55 + d.body * .25 + d.leg * .2)) : 0;
  function statsTable(rows) {
    const t = el('table', 'stats');
    for (const [label, a, b, fmt] of rows) {
      const tr = el('tr'); const va = fmt ? fmt(a) : a, vb = fmt ? fmt(b) : b;
      const ca = el('td', typeof a === 'number' && a > b ? 'lead' : '', va), cb = el('td', typeof b === 'number' && b > a ? 'lead' : '', vb);
      tr.append(ca, el('td', null, label), cb); t.append(tr);
    }
    return t;
  }

  // ---------------------------------------------------------------- camera director
  const liftFor = (zoom, h, frac) => renderer.S ? h - (renderer.floor - frac * renderer.H) / (zoom * renderer.S) : (zoom - 1) * .8;
  function direct(frame, dt) {
    const mode = $('camera').value;
    const ground = FightReplay.ground.has(frame.state.position);
    const offset = frame.state.location === 'center' ? 0 : (arena?.radius_m || 4) * .53;
    const xs = replay.fighter_ids.map(id => frame.poses[id].root[0] + offset);
    let zoom, focus = (xs[0] + xs[1]) / 2, lift;
    if (cam.target) { zoom = cam.target.zoom; focus = cam.target.focus; lift = liftFor(zoom, cam.target.h ?? .9, cam.target.frac ?? .58); }
    else if (mode !== 'director' && phase === 'fight') { zoom = 1; focus = 0; lift = 0; }
    else {
      const gap = Math.abs(xs[0] - xs[1]);
      zoom = ground ? 1.75 : ['clinch', 'cage_wrestling', 'cage_striking'].includes(frame.state.position) ? 1.62 : clamp(2.7 / (gap + 1.25), 1.25, 1.62);
      if (slow < 1) zoom = 2.05;
      lift = Math.max(0, liftFor(zoom, ground ? .35 : .95, ground ? .6 : .55));
    }
    const k = Math.min(1, dt * (cam.target ? 1.6 : 2.4));
    cam.zoom += (zoom - cam.zoom) * k; cam.focusX += (focus - cam.focusX) * k; cam.lift += (lift - cam.lift) * k;
    cam.shake = Math.max(0, cam.shake - dt * 30);
    cam.shakeX = (Math.random() - .5) * cam.shake; cam.shakeY = (Math.random() - .5) * cam.shake * .6;
    renderer.camera = mode === 'director' ? 'broadcast' : mode;
    renderer.view = (mode === 'director' || phase !== 'fight' || cam.target) ? cam : null;
  }

  // ---------------------------------------------------------------- HUD + moments
  function hud(frame) {
    $('hud-round').textContent = `ROUND ${frame.event.round} / ${rounds}`;
    $('hud-clock').textContent = clock(frame.event.clock_s);
    for (const [id, side] of [[RED, 'red'], [BLUE, 'blue']]) {
      $('st-' + side).style.width = Math.round(100 * clamp(frame.state.stamina?.[id] ?? 1, 0, 1)) + '%';
      $('dm-' + side).style.width = clamp(dmgTotal(frame.state.damage?.[id]), 0, 100) + '%';
    }
    $('tick-action').textContent = frame.clip.label;
    $('tick-outcome').textContent = OUTCOME[frame.event.outcome] || frame.event.outcome;
  }
  function moments(frame, now) {
    if (frame.event_index === lastIndex) return; lastIndex = frame.event_index;
    const e = frame.event, f = family(e.technique_id);
    const tgt = e.target_id, before = e.before?.damage?.[tgt], after = e.after?.damage?.[tgt];
    const headHit = before && after ? after.head - before.head : 0;
    const small = t => { if (now - lastSmall > 1400) { callout(t, 'small'); lastSmall = now; } };
    if (e.outcome === 'knockdown') { callout('KNOCKDOWN!'); cam.shake = 16; audio.hit(1.2); audio.swell(.24, .3); setTimeout(() => audio.swell(.07, 2.5), 1800); return; }
    if (e.outcome === 'stoppage') { callout('ACABOU!'); cam.shake = 20; audio.hit(1.4); audio.swell(.3, .3); return; }
    if (e.outcome === 'tapped') { callout('DESISTÊNCIA!'); audio.swell(.3, .3); return; }
    if (e.outcome === 'threatened' && (e.after?.submission?.progress || 0) >= .6 && !subWarned) { subWarned = true; small('FINALIZAÇÃO ENCAIXADA'); audio.swell(.18, .8); return; }
    if (f !== 'submission') subWarned = false;
    if ((e.after?.stun?.[tgt] || 0) >= .5 && (e.before?.stun?.[tgt] || 0) < .5) { small('ESTÁ ABALADO!'); cam.shake = 9; audio.hit(.8); audio.swell(.16, .4); return; }
    if (f === 'entry' && e.outcome === 'completed') { small('QUEDA!'); audio.hit(.5); return; }
    if (headHit >= .05) { small('CONECTOU!'); cam.shake = 7; audio.hit(.7); audio.swell(.1, .3); setTimeout(() => audio.swell(.05, 1.5), 900); }
  }

  // ---------------------------------------------------------------- render loop
  let lastNow = 0;
  function draw(now) {
    const dt = lastNow ? Math.min(.1, (now - lastNow) / 1000) : .016; lastNow = now;
    const frame = player.sample(time);
    direct(frame, dt);
    renderer.render(frame, arena, appearance);
    if (phase === 'fight') { hud(frame); moments(frame, now); }
    $('seek').value = time; $('time').textContent = `${clock(time / 1000)} / ${clock(player.duration / 1000)}`;
    return frame;
  }
  function loop(now) {
    if (playing) {
      const prev = time;
      time = Math.min(replayEnd ?? player.duration, time + (last ? now - last : 0) * speed * slow);
      const frame = draw(now);
      if (phase === 'fight' && frame.event.round > curRound && !replayEnd) { playing = false; roundBreak(curRound, frame.event.round); }
      if (time >= (replayEnd ?? player.duration) && prev < time) { playing = false; onReachedEnd(); }
    } else draw(now);
    last = now; requestAnimationFrame(loop);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden && phase === 'fight') { playing = false; sync(); } last = 0; });
  window.pauseCornerOffice = () => { if (phase === 'fight') { playing = false; sync(); } last = 0; };
  requestAnimationFrame(loop);

  // ---------------------------------------------------------------- the night
  function walkCard(id, corner) {
    const f = F(id), rec = f.record || {}, pres = (P.fighters || {})[id] || {};
    const card = el('div', 'card ' + (corner === 'blue' ? 'blue right' : ''));
    card.append(el('span', 'kicker', corner === 'blue' ? 'CORNER AZUL' : 'CORNER VERMELHO'));
    if (pres.nickname) { const n = el('div', null); n.append(el('span', 'nick', `“${pres.nickname}”`)); card.append(n); }
    card.append(el('div', 'big', name(id)));
    const meta = el('div', 'meta');
    const bits = [[`${rec.wins || 0}-${rec.losses || 0}-${rec.draws || 0}`, 'cartel'], [(flag(f.country) + ' ' + (COUNTRY[f.country] || f.country || '')).trim(), ''], [BASE[f.martial_base] || f.martial_base, 'base'], pres.rank ? [`#${pres.rank}`, 'ranking'] : null, pres.champion ? ['CAMPEÃO', ''] : null].filter(Boolean);
    for (const [v, l] of bits) { const s = el('span'); s.append(el('b', null, v)); if (l) s.append(document.createTextNode(' ' + l)); meta.append(s); }
    card.append(el('div', 'rule'), meta);
    return card;
  }
  function tape() {
    const a = F(RED), b = F(BLUE), pa = (P.fighters || {})[RED] || {}, pb = (P.fighters || {})[BLUE] || {};
    const box = el('div', 'tape'); const head = el('div', 'tape-head');
    head.append(el('strong', 'r', name(RED)), el('span', null, 'TALE OF THE TAPE'), el('strong', 'b', name(BLUE))); box.append(head);
    const t = el('table');
    const rows = [
      ['IDADE', pa.age, pb.age, v => v ? v + ' anos' : '—', 'low'],
      ['ALTURA', a.height_cm, b.height_cm, v => v ? v + ' cm' : '—', 'high'],
      ['ALCANCE', a.reach_cm, b.reach_cm, v => v ? v + ' cm' : '—', 'high'],
      ['CARTEL', `${a.record?.wins || 0}-${a.record?.losses || 0}-${a.record?.draws || 0}`, `${b.record?.wins || 0}-${b.record?.losses || 0}-${b.record?.draws || 0}`],
      ['POSTURA', STANCE[a.stance] || a.stance || '—', STANCE[b.stance] || b.stance || '—'],
      ['BASE', BASE[a.martial_base] || '—', BASE[b.martial_base] || '—'],
      ['ORIGEM', (flag(a.country) + ' ' + (COUNTRY[a.country] || a.country || '')).trim(), (flag(b.country) + ' ' + (COUNTRY[b.country] || b.country || '')).trim()],
    ];
    rows.forEach(([label, va, vb, fmt, better], i) => {
      const tr = el('tr'); tr.style.animationDelay = (i * .12) + 's';
      const ca = el('td', null, fmt ? fmt(va) : va), cb = el('td', null, fmt ? fmt(vb) : vb);
      if (better && va && vb && va !== vb) { const aWins = better === 'high' ? va > vb : va < vb; (aWins ? ca : cb).classList.add('adv'); }
      tr.append(ca, el('td', null, label), cb); t.append(tr);
    });
    box.append(t); return box;
  }
  // side: shift the subject away from the text column (TV walkout framing)
  function focusOn(id, zoom = 2.4, side = 0) {
    const f = player.sample(time); const off = f.state.location === 'center' ? 0 : (arena?.radius_m || 4) * .53;
    const portrait = (renderer.H || 1) > (renderer.W || 1);
    cam.target = { zoom, focus: f.poses[id].root[0] + off + (portrait ? 0 : side), h: 1.3, frac: portrait ? .34 : .5 };
  }

  async function pregame() {
    document.body.dataset.phase = phase = 'show'; $('gate').hidden = true; time = 0;
    try {
      cam.target = { zoom: 1.05, focus: 0, h: .9, frac: .62 };
      const open = el('div', 'card' + (title ? ' gold' : ''));
      open.append(el('span', 'kicker', title ? 'DISPUTA DE CINTURÃO' : 'FIGHT NIGHT'), el('div', 'big', eventName), el('div', 'sub', [P.city || arena?.city, P.card_slot ? (SLOT[P.card_slot] || '').replace(/^(a|uma) /, '') : null, division, `${rounds} rounds`].filter(Boolean).join(' · ')), el('div', 'rule'));
      show(open); audio.whoosh(); audio.swell(.08, 2);
      await step(hold(3200));
      // walkouts: blue corner first, then red
      for (const [id, corner] of [[BLUE, 'blue'], [RED, 'red']]) {
        renderer.hideReferee = true; audio.beat(true); focusOn(id, 2.4, corner === 'blue' ? .85 : -.85); show(walkCard(id, corner)); audio.whoosh(); audio.swell(.12, 1.2);
        await step(hold(4200)); audio.beat(false);
      }
      renderer.hideReferee = false; cam.target = { zoom: 1.15, focus: 0, h: .9, frac: .62 };
      show(tape()); audio.whoosh();
      await step(hold(6500));
      show(); cam.target = { zoom: 1.35, focus: 0, h: 1, frac: .5 };
      await step(say('Senhoras e senhores!'), 600);
      await step(say(`Esta é ${SLOT[P.card_slot] || 'a próxima luta'} da noite: ${rounds} rounds na categoria ${division}!`), 600);
      if (title) await step(say(`E ela vale o cinturão ${orgName}!`), 600);
      for (const [id, intro] of [[BLUE, 'Lutando no corner azul...'], [RED, 'E no corner vermelho...']]) {
        const f = F(id), rec = f.record || {}, pres = (P.fighters || {})[id] || {};
        focusOn(id, 2.2);
        await step(say(intro), 400);
        await step(say(`Com um cartel de ${rec.wins || 0} vitórias e ${rec.losses || 0} derrotas, representando ${COUNTRY[f.country] || f.country || 'sua equipe'}...`), 400);
        audio.swell(.2, .5);
        await step(say(pres.nickname ? `“${pres.nickname}”` : '', { stretch: name(id) }), 900);
        audio.swell(.07, 1.5);
      }
      cam.target = { zoom: 1.4, focus: 0, h: 1, frac: .5 };
      await step(say('Esta noite, ninguém sai igual. QUE A NOITE DECIDA!'), 500);
      await step(say(`Protejam-se o tempo todo. Obedeçam ao meu comando. Toquem as luvas.`, { speaker: `ÁRBITRO CENTRAL · ${refName.toUpperCase()}` }), 400);
    } catch (e) { if (!(e instanceof Skip)) throw e; audio.beat(false); }
    startFight();
  }

  function startFight() {
    quiet(); show(); cam.target = null; skipper = null; advance = null;
    document.body.dataset.phase = phase = 'fight';
    for (const k of ['hud', 'controls', 'timeline']) $(k).hidden = false;
    $('hud-red').textContent = name(RED); $('hud-blue').textContent = name(BLUE);
    curRound = player.sample(time).event.round; lastIndex = -1;
    callout(`ROUND ${curRound}`); audio.bell(1); audio.swell(.09, 1);
    playing = true; last = 0; sync();
  }

  async function roundBreak(ended, next) {
    document.body.dataset.phase = phase = 'break'; sync(); audio.bell(2); audio.swell(.14, .5);
    const s = roundStats(ended), endE = lastOfRound(ended), a = s[RED], b = s[BLUE];
    const card = el('div', 'panel card');
    card.append(el('span', 'kicker', `FIM DO ${ORD[ended]?.toUpperCase() || ended + 'º'} ROUND`));
    card.append(statsTable([
      ['GOLPES CONECTADOS', a.land, b.land], ['TENTATIVAS', a.att, b.att], ['QUEDAS', a.td, b.td],
      ['FINALIZAÇÕES TENTADAS', a.sub, b.sub], ['KNOCKDOWNS', a.kd, b.kd],
      ['DANO ACUMULADO', dmgTotal(endE?.after?.damage?.[RED]), dmgTotal(endE?.after?.damage?.[BLUE]), v => v + '%'],
    ]));
    const leader = a.land + a.td * 2 + a.kd * 5 > b.land + b.td * 2 + b.kd * 5 ? RED : BLUE, trailing = leader === RED ? BLUE : RED;
    card.append(el('p', 'sub', `No corner de ${name(trailing).split(' ')[0]}: “Você precisa deste round. Muda o ritmo!”`));
    show(card);
    try { await step(hold(5200)); } catch (e) { if (!(e instanceof Skip)) throw e; }
    show(); curRound = next; document.body.dataset.phase = phase = 'fight';
    callout(`ROUND ${next}`); audio.bell(1); audio.swell(.09, 1);
    playing = true; last = 0; sync(); skipper = null; advance = null;
  }

  function onReachedEnd() {
    if (replayEnd != null) { replayEnd = null; slow = 1; $('replaytag').hidden = true; ceremony(); return; }
    const r = replay.result;
    if (r && (r.method === 'ko_tko' || r.method === 'submission')) {
      const lastE = replay.events[replay.events.length - 1];
      setTimeout(() => { replayEnd = player.duration; time = Math.max(0, lastE.at_ms - 2600); slow = .35; $('replaytag').hidden = false; lastIndex = -1; playing = true; last = 0; }, 1500);
    } else { callout('FIM DE LUTA', 'small'); audio.bell(3); setTimeout(ceremony, 1800); }
  }

  const methodPhrase = r => {
    if (!r) return '';
    if (r.method === 'decision') return { unanimous: 'decisão unânime', split: 'decisão dividida', majority: 'decisão majoritária' }[r.detail] || 'decisão';
    if (r.method === 'draw') return 'empate';
    if (r.method === 'ko_tko') return { ko: 'nocaute', knockout: 'nocaute', referee_tko: 'nocaute técnico', body_tko: 'nocaute técnico com golpes no corpo', leg_tko: 'nocaute técnico com golpes nas pernas' }[r.detail] || 'nocaute técnico';
    if (r.method === 'submission') return 'finalização, com ' + (catalog.clips.find(x => x.id === r.detail)?.label || 'finalização').toLowerCase();
    return r.method;
  };

  async function ceremony() {
    document.body.dataset.phase = phase = 'show'; for (const k of ['hud', 'controls', 'timeline']) $(k).hidden = true;
    playing = false; time = player.duration; cam.target = { zoom: 1.3, focus: 0, h: 1, frac: .5 };
    const r = replay.result || {}, win = r.winner_id, champ = (P.fighters || {})[win]?.champion;
    try {
      audio.swell(.12, .8);
      await step(say('Senhoras e senhores, temos um resultado!'), 500);
      if (r.method === 'decision' || r.method === 'draw') {
        for (const [i, card] of (r.scorecards || []).entries()) {
          const t = card.total || []; const hi = Math.max(...t), lo = Math.min(...t);
          const who = t[0] === t[1] ? 'empate' : name(t[0] > t[1] ? RED : BLUE).split(' ').pop();
          await step(say(`${JUDGES[(i + (replay.seed || 0)) % JUDGES.length]} marca ${hi} a ${lo}${t[0] === t[1] ? '' : ' para ' + who}.`), 300);
        }
      } else if (win) {
        await step(say(`Aos ${clock(r.time_s)} do ${ORD[r.round] || r.round + 'º'} round, vencedor por ${methodPhrase(r)}...`), 600);
      }
      if (win) {
        focusOn(win, 2.1); audio.swell(.3, .4);
        await step(say(title ? (champ ? 'E AINDA campeão...' : 'E NOVO campeão...') : (r.method === 'decision' ? `Vencedor, por ${methodPhrase(r)}...` : ''), { stretch: name(win) }), 1200);
      } else await step(say('Esta luta termina EMPATADA!'), 800);
    } catch (e) { if (!(e instanceof Skip)) throw e; }
    quiet(); resultScreen();
  }

  function resultScreen() {
    document.body.dataset.phase = phase = 'result'; skipper = null; advance = null;
    const r = replay.result || {}, win = r.winner_id, lose = win === RED ? BLUE : RED, full = replay.stats?.fighters || {};
    const panel = el('div', 'panel card' + (title && win ? ' gold' : ''));
    panel.append(el('span', 'kicker', title && win ? 'CAMPEÃO' : 'RESULTADO OFICIAL'));
    const row = el('div', 'winner');
    if (win) { const cv = el('canvas'); cv.width = 256; cv.height = 320; cv.getContext('2d').drawImage(renderer.head(appearance[win]), 0, 0); row.append(cv); }
    const txt = el('div'); txt.append(el('div', 'big', win ? name(win) : 'EMPATE'), el('div', 'sub', `${methodPhrase(r)} · round ${r.round} · ${clock(r.time_s)}`));
    if (win) txt.append(el('div', 'sub', `derrotou ${name(lose)}`));
    row.append(txt); panel.append(row);
    const s = roundStats(0), fa = full[RED] || {}, fb = full[BLUE] || {};
    const head = el('div', 'tape-head'); head.append(el('strong', 'r', name(RED)), el('span', null, 'ESTATÍSTICAS'), el('strong', 'b', name(BLUE)));
    panel.append(el('div', 'rule'), head, statsTable([
      ['GOLPES CONECTADOS', s[RED].land, s[BLUE].land], ['PRECISÃO', s[RED].att ? Math.round(100 * s[RED].land / s[RED].att) : 0, s[BLUE].att ? Math.round(100 * s[BLUE].land / s[BLUE].att) : 0, v => v + '%'],
      ['KNOCKDOWNS', s[RED].kd, s[BLUE].kd], ['QUEDAS', `${fa.takedowns || 0}/${fa.takedown_attempts || 0}`, `${fb.takedowns || 0}/${fb.takedown_attempts || 0}`],
      ['FINALIZAÇÕES TENTADAS', fa.submission_attempts ?? s[RED].sub, fb.submission_attempts ?? s[BLUE].sub], ['CONTROLE', Math.round(fa.control_s || 0), Math.round(fb.control_s || 0), v => clock(v)],
    ]));
    for (const [i, card] of (r.scorecards || []).entries()) panel.append(el('p', 'sub', `${JUDGES[(i + (replay.seed || 0)) % JUDGES.length]}: ${(card.total || []).join(' – ')}`));
    const actions = el('div', 'actions');
    const again = el('button', 'primary', 'ASSISTIR DE NOVO'); again.onclick = () => { time = 0; for (const k of ['hud', 'controls', 'timeline']) $(k).hidden = false; startFight(); };
    const back = el('button', null, 'VOLTAR À CARREIRA'); back.onclick = () => $('back').click();
    actions.append(again, back); panel.append(actions);
    show(panel); audio.swell(.06, 2);
  }

  // ---------------------------------------------------------------- controls
  const sync = () => { $('play').textContent = playing ? 'PAUSAR' : 'CONTINUAR'; };
  $('play').onclick = () => { if (phase !== 'fight') return; if (time >= player.duration) time = 0; playing = !playing; last = 0; sync(); };
  $('speed').onchange = () => { speed = Number($('speed').value); };
  $('seek').oninput = () => { if (phase !== 'fight') return; time = Number($('seek').value); curRound = player.sample(time).event.round; lastIndex = -1; last = 0; };
  $('instant').onclick = () => { if (phase !== 'fight') return; playing = false; time = player.duration; replayEnd = null; slow = 1; ceremony(); };
  $('start').onclick = () => { audio.init(); pregame(); };
  $('start-fast').onclick = () => { audio.init(); $('gate').hidden = true; startFight(); };
  await document.fonts.ready;
  document.body.dataset.ready = 'true';
})();
