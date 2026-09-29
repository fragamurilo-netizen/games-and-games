/* Preview/catalog UI; no combat controls. Game Design Bible §15. */
"use strict";
(async () => {
  const $ = (id) => document.getElementById(id),
    clone = (x) => JSON.parse(JSON.stringify(x)),
    base = "../../game/content/";
  const labels = {
    landed: "Acertou",
    blocked: "Bloqueado",
    evaded: "Esquivado",
    missed: "Errou",
    knockdown: "Knockdown",
    stoppage: "Interrupção",
    completed: "Concluído",
    defended: "Defendido",
    held: "Controle mantido",
    escaped: "Escape",
    threatened: "Ameaça mantida",
    tapped: "Desistência",
  };
  const positions = {
    long_range: "Distância",
    pocket: "Pocket",
    cage_striking: "Trocação na grade",
    clinch: "Clinch",
    open_wrestling: "Wrestling no centro",
    cage_wrestling: "Wrestling na grade",
    guard: "Guarda",
    half_guard: "Meia-guarda",
    side_control: "Controle lateral",
    mount_back: "Montada / costas",
    scramble: "Scramble",
    reset: "Separação",
  };
  const get = async (path) => {
    const r = await fetch(base + path);
    if (!r.ok)
      throw new Error(`Não foi possível carregar ${path} (${r.status}).`);
    return r.json();
  };
  let catalog,
    arenas,
    index,
    examples,
    player,
    renderer,
    selected,
    log,
    time = 0,
    playing = false,
    last = 0,
    appearances = {},
    lastEvent = -1;
  function option(select, value, text) {
    const o = document.createElement("option");
    o.value = value;
    o.textContent = text;
    select.append(o);
  }
  function message(text) {
    $("error").hidden = !text;
    $("error").textContent = text;
  }
  function clock(s) {
    s = Math.max(0, Math.floor(s));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }
  function name(id) {
    return appearances[id]?.name || log.fighters[id]?.name || id;
  }
  function activeArena() {
    return arenas.arenas.find((a) => a.id === log.organization_id);
  }
  function buildAppearances() {
    appearances = {};
    for (const id of log.fighter_ids) {
      const f = log.fighters?.[id] || {};
      appearances[id] = FightAppearance.resolve(f, CANON, genFace);
    }
  }
  function load(replay) {
    try {
      const next = new FightReplay.Player(replay, catalog, arenas);
      player = next;
      log = clone(replay);
      buildAppearances();
      time = 0;
      lastEvent = -1;
      $("verdict").hidden = true;
      message("");
      $("arena").value = log.organization_id;
      $("seek").max = player.duration;
      $("source").textContent =
        log.source === "simulation"
          ? "REPLAY · registro da simulação"
          : "DEMONSTRAÇÃO · sequência autoral";
      for (const id of ["arena", "fighter-red", "fighter-blue"])
        $(id).disabled = log.source === "simulation";
      for (const [i, id] of log.fighter_ids.entries()) {
        $("name-" + (i ? "blue" : "red")).textContent = name(id);
        $("fighter-" + (i ? "blue" : "red")).value = String(
          log.fighters[id].appearance_index ?? 0,
        );
      }
      $("org-label").textContent = activeArena().short_name;
      renderEvents();
      draw();
    } catch (e) {
      message(e.message);
    }
  }
  function renderEvents() {
    const body = $("events");
    body.replaceChildren();
    log.events.forEach((e, i) => {
      const row = document.createElement("tr");
      row.dataset.event = String(i);
      const data = [
        `R${e.round} · ${clock(e.clock_s)}`,
        name(e.actor_id),
        catalog.clips.find((c) => c.id === e.technique_id).label,
        labels[e.outcome],
        positions[e.after.position],
      ];
      data.forEach((text, j) => {
        const cell = document.createElement("td");
        if (j === 2) {
          const b = document.createElement("button");
          b.textContent = text;
          b.addEventListener("click", () => {
            time = e.at_ms;
            playing = false;
            syncPlay();
            draw();
          });
          cell.append(b);
        } else cell.textContent = text;
        row.append(cell);
      });
      body.append(row);
    });
  }
  function draw() {
    if (!player) return;
    const frame = player.sample(time);
    renderer.render(frame, activeArena(), appearances);
    $("action").textContent = frame.clip.label;
    $("phase").textContent =
      catalog.categories[frame.clip.category].toUpperCase();
    $("outcome").textContent = labels[frame.event.outcome];
    $("round").textContent = "ROUND " + frame.event.round;
    $("clock").textContent = clock(frame.event.clock_s);
    $("tv-clock").textContent = clock(frame.event.clock_s);
    $("tv-round").textContent =
      `R${frame.event.round}${log.scheduled_rounds ? " / " + log.scheduled_rounds : ""}`;
    for (const [i, id] of log.fighter_ids.entries()) {
      const side = i ? "blue" : "red",
        f = log.fighters[id];
      $("tv-" + side + "-name").textContent = name(id)
        .split(" ")
        .at(-1)
        .toUpperCase();
      $("tv-" + side + "-style").textContent =
        catalog.styles.find((s) => s.id === f.martial_base)?.label ||
        (i ? "CORNER AZUL" : "CORNER VERMELHO");
    }
    const landed = log.fighter_ids.map(
      (id) =>
        log.events.filter(
          (e) =>
            e.actor_id === id &&
            e.at_ms + e.duration_ms <= time &&
            ["landed", "knockdown", "stoppage"].includes(e.outcome),
        ).length,
    );
    $("tv-stats").textContent =
      `GOLPES CONECTADOS  ${landed[0]} — ${landed[1]}  ·  ${positions[frame.state.position].toUpperCase()}`;
    $("time").textContent =
      `${clock(time / 1000)} / ${clock(player.duration / 1000)}`;
    $("seek").value = time;
    $("position").textContent =
      positions[frame.state.position] +
      (frame.state.top_id ? " · por cima: " + name(frame.state.top_id) : "");
    for (const [i, id] of log.fighter_ids.entries()) {
      const side = i ? "blue" : "red";
      $("stamina-" + side).value = frame.state.stamina[id];
      const d = frame.state.damage[id];
      $("damage-" + side).textContent =
        `Dano · cabeça ${Math.round(d.head * 100)} · corpo ${Math.round(d.body * 100)} · perna ${Math.round(d.leg * 100)}`;
    }
    $("result").textContent = frame.result
      ? (frame.result.winner_id ? name(frame.result.winner_id) + " · " : "") +
        ({
          ko_tko: "KO/TKO",
          submission: "Finalização",
          decision: "Decisão",
          draw: "Empate",
          nc: "No contest",
          dq: "Desclassificação",
        }[frame.result.method] || "")
      : "";
    showVerdict(frame.result);
    const threat = frame.state.submission;
    $("fight-story").textContent = threat?.technique_id
      ? `${name(threat.attacker_id)} trabalha ${catalog.clips.find((c) => c.id === threat.technique_id)?.label || "a finalização"} · pressão ${Math.round(threat.progress * 100)}%`
      : frame.event.reason_codes.includes("KNOCKDOWN")
        ? "Knockdown! A continuidade depende da reação e da defesa."
        : frame.clip.family === "entry" && frame.event.outcome === "defended"
          ? `${name(frame.event.target_id)} defende a queda e tenta retomar a iniciativa.`
          : frame.clip.category === "official"
            ? frame.clip.label
            : `${name(frame.event.actor_id)} · ${frame.clip.label} · ${labels[frame.event.outcome].toLowerCase()}`;
    if (lastEvent !== frame.event_index) {
      lastEvent = frame.event_index;
      for (const row of $("events").children)
        row.classList.toggle(
          "current",
          Number(row.dataset.event) === lastEvent,
        );
    }
  }
  function showVerdict(result) {
    $("verdict").hidden = !result;
    if (!result) return;
    const types = {
      ko: "Nocaute",
      referee_tko: "TKO · interrupção do árbitro",
      body_tko: "TKO · golpes no corpo",
      leg_tko: "TKO · dano nas pernas",
      unanimous: "Decisão unânime",
      split: "Decisão dividida",
      majority: "Decisão majoritária",
    };
    $("verdict-title").textContent = result.winner_id
      ? name(result.winner_id) + " vence"
      : "Empate";
    const detail =
      types[result.detail] ||
      catalog.clips.find((c) => c.id === result.detail)?.label ||
      {
        ko_tko: "KO/TKO",
        submission: "Finalização",
        decision: "Decisão",
        draw: "Empate",
        nc: "No contest",
        dq: "Desclassificação",
      }[result.method] ||
      "";
    $("verdict-detail").textContent =
      `${detail}${result.round ? " · R" + result.round : ""}${result.time_s != null ? " · " + clock(result.time_s) : ""}`;
    const signature = JSON.stringify(result);
    if ($("scorecards").dataset.result === signature) return;
    $("scorecards").dataset.result = signature;
    $("scorecards").replaceChildren();
    (result.scorecards || []).forEach((card, i) => {
      const panel = document.createElement("div");
      const title = document.createElement("strong");
      title.textContent = `Juiz ${i + 1} · ${card.total.join("–")}`;
      const scores = document.createElement("p");
      scores.textContent =
        card.scoring === "whole_fight"
          ? "Avaliação global da luta"
          : card.rounds.map((s, i) => `R${i + 1}: ${s.join("–")}`).join(" · ");
      panel.append(title, scores);
      $("scorecards").append(panel);
    });
  }
  async function setupSimulation() {
    const roster = await get("canonical_fighters.json");
    const visible = [
      "carter",
      "moreira",
      "arsanov",
      "reyes",
      "costa",
      "sato",
      "monroe",
      "volkovic",
      "markovic",
      "cole",
    ].map((x) => "ftr_" + x);
    for (const f of roster.filter((f) => visible.includes(f.id)))
      for (const side of ["red", "blue"])
        option($("match-" + side), f.id, f.first_name + " " + f.last_name);
    $("match-red").value = "ftr_carter";
    $("match-blue").value = "ftr_moreira";
    for (const a of arenas.arenas) option($("match-org"), a.id, a.name);
    for (const style of catalog.styles)
      for (const side of ["red", "blue"])
        option($("match-" + side + "-style"), style.id, style.label);
    $("match-org").onchange = () => {
      const ring =
        arenas.arenas.find((a) => a.id === $("match-org").value).venue ===
        "ring";
      $("match-rounds").options[1].disabled = ring;
      if (ring) $("match-rounds").value = "3";
    };
    try {
      const response = await fetch("/api/status");
      if (!response.ok || (await response.json()).engine !== "godot")
        throw new Error();
      $("engine-status").textContent =
        "Motor conectado. Prepare o confronto e acompanhe.";
    } catch {
      $("simulate").disabled = true;
      $("engine-status").textContent =
        "Replays prontos disponíveis abaixo. Para criar novos confrontos, inicie tools/fight_lab_server.py conforme o guia da equipe.";
    }
    $("match-form").onsubmit = async (e) => {
      e.preventDefault();
      $("simulate").disabled = true;
      $("engine-status").textContent = "Simulando o confronto…";
      try {
        const response = await fetch("/api/simulate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            seed: Number($("match-seed").value),
            red: $("match-red").value,
            blue: $("match-blue").value,
            organization: $("match-org").value,
            rounds: Number($("match-rounds").value),
            red_style: $("match-red-style").value,
            blue_style: $("match-blue-style").value,
          }),
        });
        const data = await response.json();
        if (!response.ok)
          throw new Error(data.error || "Não foi possível simular.");
        load(data);
        playing = true;
        $("loop").checked = false;
        syncPlay();
        $("engine-status").textContent =
          `Luta pronta · seed ${data.seed} · ${data.events.length} trocas registradas.`;
        $("fight").scrollIntoView({ behavior: "smooth", block: "center" });
      } catch (error) {
        message(error.message);
        $("engine-status").textContent =
          "Não foi possível concluir. Confira os dados do confronto.";
      } finally {
        $("simulate").disabled = false;
      }
    };
  }
  function syncPlay() {
    $("play").textContent = playing ? "Pausar" : "Reproduzir";
    $("play").setAttribute(
      "aria-label",
      playing ? "Pausar reprodução" : "Iniciar reprodução",
    );
  }
  function tick(now) {
    if (last && playing && player) {
      time += Math.min(100, now - last) * Number($("speed").value);
      if (time >= player.duration) {
        time = player.duration;
        if ($("loop").checked) time = 0;
        else {
          playing = false;
          syncPlay();
        }
      }
    }
    last = now;
    if (playing) draw();
    requestAnimationFrame(tick);
  }
  function selectClip(c) {
    selected = c;
    $("clip-name").textContent = c.label;
    $("clip-path").textContent =
      `${positions[c.from_positions[0]]} → ${positions[c.to_position]} · ${c.actor_role === "bottom" ? "ataque por baixo" : c.actor_role === "top" ? "controle por cima" : "em pé"} · ${c.duration_ms / 1000}s`;
    $("response").replaceChildren();
    c.outcomes.forEach((o) => option($("response"), o, labels[o]));
    for (const b of $("categories").children)
      b.setAttribute("aria-pressed", String(b.dataset.clip === c.id));
  }
  function filter() {
    const search = $("search")
        .value.normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase(),
      cat = $("category").value,
      style = $("style").value;
    const list = catalog.clips.filter(
      (c) =>
        (!cat || c.category === cat) &&
        (!style || c.styles.includes(style)) &&
        (c.label + " " + c.id)
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "")
          .toLowerCase()
          .includes(search),
    );
    $("categories").replaceChildren();
    for (const c of list) {
      const b = document.createElement("button");
      b.dataset.clip = c.id;
      b.setAttribute("aria-pressed", String(selected?.id === c.id));
      const sm = document.createElement("small");
      sm.textContent = catalog.categories[c.category];
      const title = document.createElement("strong");
      title.textContent = c.label;
      b.append(sm, title);
      b.addEventListener("click", () => selectClip(c));
      $("categories").append(b);
    }
    $("count").textContent =
      `${list.length} de ${catalog.clips.length} técnicas`;
  }
  function previewClip() {
    if (!selected) return;
    const c = selected,
      ids = ["red", "blue"],
      state = {
        position: c.from_positions[0],
        top_id: FightReplay.ground.has(c.from_positions[0])
          ? c.actor_role === "bottom"
            ? "blue"
            : "red"
          : null,
        location: "center",
        stamina: { red: 1, blue: 1 },
        damage: {
          red: { head: 0, body: 0, leg: 0 },
          blue: { head: 0, body: 0, leg: 0 },
        },
      };
    const e = {
      id: "preview_001",
      at_ms: 0,
      duration_ms: c.duration_ms,
      round: 1,
      clock_s: 300,
      actor_id: "red",
      target_id: "blue",
      technique_id: c.id,
      outcome: $("response").value,
      rules_approved: true,
      reason_codes: ["AUTHORED_PREVIEW"],
      before: clone(state),
      after: clone(state),
    };
    e.after.position = FightReplay.expectedPosition(c, e);
    e.after.top_id = FightReplay.ground.has(e.after.position)
      ? state.top_id || "red"
      : null;
    const a = arenas.arenas.find((a) => a.id === $("arena").value);
    const r = {
      version: 1,
      id: "technique_preview",
      title: c.label,
      source: "authored_preview",
      organization_id: a.id,
      ruleset_id: a.ruleset_id,
      fighter_ids: ids,
      fighters: Object.fromEntries(
        ids.map((id) => [
          id,
          {
            appearance_index: Number($("fighter-" + id).value),
            stance: "orthodox",
          },
        ]),
      ),
      initial_state: state,
      events: [e],
    };
    load(r);
    playing = true;
    syncPlay();
    $("fight").scrollIntoView({ block: "center", behavior: "smooth" });
  }
  try {
    [catalog, arenas, index] = await Promise.all([
      get("fight_visuals.json"),
      get("arena_profiles.json"),
      get("replays/index.json"),
    ]);
    const simulatedIndex = await get("replays/simulated_index.json");
    index.push(...simulatedIndex);
    examples = await Promise.all(index.map((x) => get("replays/" + x.file)));
    renderer = new FightRenderer($("fight"));
    $("inventory").textContent =
      `${catalog.clips.length} técnicas · ${arenas.arenas.length} arenas · ${catalog.styles.length} bases`;
    arenas.arenas.forEach((a) =>
      option(
        $("arena"),
        a.id,
        a.name + (a.venue === "ring" ? " · ringue" : ""),
      ),
    );
    index.forEach((x, i) => option($("sequence"), String(i), x.title));
    CANON.forEach((f, i) => {
      option($("fighter-red"), String(i), f.name);
      option($("fighter-blue"), String(i), f.name);
    });
    Object.entries(catalog.categories).forEach(([k, v]) =>
      option($("category"), k, v),
    );
    catalog.styles.forEach((s) => option($("style"), s.id, s.label));
    $("broadcast-mode").onclick = () => {
      const enabled = document.body.classList.toggle("broadcast-mode");
      $("broadcast-mode").setAttribute("aria-pressed", String(enabled));
      $("broadcast-mode").textContent = enabled
        ? "Voltar ao laboratório"
        : "Modo transmissão";
      $("fight").scrollIntoView({ block: "center" });
      draw();
    };
    $("play").onclick = () => {
      if (time >= player.duration) time = 0;
      playing = !playing;
      syncPlay();
      draw();
    };
    $("restart").onclick = () => {
      time = 0;
      draw();
    };
    $("instant").onclick = () => {
      time = player.duration;
      playing = false;
      syncPlay();
      draw();
    };
    $("seek").oninput = () => {
      time = Number($("seek").value);
      draw();
    };
    $("camera").onchange = () => {
      renderer.camera = $("camera").value;
      draw();
    };
    $("rig").onchange = () => {
      renderer.showRig = $("rig").checked;
      draw();
    };
    $("sequence").onchange = () => {
      load(examples[Number($("sequence").value)]);
      playing = true;
      syncPlay();
    };
    $("arena").onchange = () => {
      const a = arenas.arenas.find((x) => x.id === $("arena").value);
      const r = clone(
        a.venue === "ring" ? examples.find((x) => x.id === "shinsei") : log,
      );
      r.source = "authored_preview";
      r.organization_id = a.id;
      r.ruleset_id = a.ruleset_id;
      for (const state of [
        r.initial_state,
        ...r.events.flatMap((e) => [e.before, e.after]),
      ])
        if (state.location !== "center")
          state.location = a.venue === "ring" ? "ropes" : "cage";
      load(r);
    };
    for (const side of ["red", "blue"])
      $("fighter-" + side).onchange = () => {
        const id = log.fighter_ids[side === "blue" ? 1 : 0];
        log.fighters[id] = {
          appearance_index: Number($("fighter-" + side).value),
          stance: "orthodox",
        };
        load(log);
      };
    for (const id of ["search", "category", "style"])
      $(id).addEventListener(id === "search" ? "input" : "change", filter);
    $("inspect").onclick = previewClip;
    $("response").onchange = () => {
      if (log.id === "technique_preview") previewClip();
    };
    $("import").onchange = async () => {
      const file = $("import").files[0];
      if (!file) return;
      if (file.size > 8_000_000) {
        message("O replay ultrapassa o limite de 8 MB.");
        return;
      }
      try {
        load(JSON.parse(await file.text()));
        playing = false;
        syncPlay();
      } catch (e) {
        message("JSON inválido: " + e.message);
      }
    };
    $("export").onclick = () => {
      const blob = new Blob([JSON.stringify(log, null, 2)], {
          type: "application/json",
        }),
        url = URL.createObjectURL(blob),
        a = document.createElement("a");
      a.href = url;
      a.download = "corner-office-replay.json";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    new ResizeObserver(draw).observe($("fight"));
    document.addEventListener("visibilitychange", () => {
      last = 0;
    });
    await setupSimulation();
    load(examples.find((x) => x.source === "simulation") || examples[0]);
    $("sequence").value = String(examples.findIndex((x) => x.id === log.id));
    selectClip(catalog.clips.find((c) => c.id === "jab"));
    filter();
    syncPlay();
    requestAnimationFrame(tick);
  } catch (e) {
    message(
      e.message +
        "\nInicie o servidor na pasta corner-office: python -m http.server 8767",
    );
  }
})();
