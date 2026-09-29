/* Event-authoritative presentation. Game Bible §§6,15,17; MMA Bible §20.
 * No RNG, collision outcome, score, damage calculation or simulation mutation.
 * Same immutable log + time always samples the same paired pose.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object") module.exports = api;
  else root.FightReplay = api;
})(typeof window === "object" ? window : this, () => {
  "use strict";
  const clone = (x) => JSON.parse(JSON.stringify(x));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const ground = new Set([
    "guard",
    "half_guard",
    "side_control",
    "mount_back",
    "scramble",
  ]);
  const equal = (a, b) =>
    JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
  function canonical(x) {
    if (Array.isArray(x)) return x.map(canonical);
    if (x && typeof x === "object")
      return Object.fromEntries(
        Object.keys(x)
          .sort()
          .map((k) => [k, canonical(x[k])]),
      );
    return x;
  }
  function mixPose(a, b, t) {
    const out = {};
    for (const k of Object.keys(a)) {
      if (typeof a[k] === "number") out[k] = a[k] + (b[k] - a[k]) * t;
      else if (Array.isArray(a[k]))
        out[k] = a[k].map((v, i) =>
          Array.isArray(v)
            ? v.map((n, j) => n + (b[k][i][j] - n) * t)
            : v + (b[k][i] - v) * t,
        );
    }
    return out;
  }
  function reflect(p) {
    p = clone(p);
    p.root[0] *= -1;
    p.lean *= -1;
    p.head *= -1;
    p.facing *= -1;
    for (const k of ["hands", "feet"]) for (const q of p[k]) q[0] *= -1;
    p.bend = p.bend.map((v) => -v);
    return p;
  }
  function expectedPosition(c, e) {
    if (["knockdown"].includes(e.outcome)) return "scramble";
    if (e.outcome === "stoppage" || e.outcome === "tapped") return "reset";
    if (e.outcome === "escaped" && c.family === "control")
      return ["clinch", "cage_wrestling"].includes(e.before.position)
        ? "pocket"
        : "scramble";
    if (["completed", "held", "threatened"].includes(e.outcome))
      return c.to_position;
    return e.before.position;
  }
  function validate(replay, catalog, arenas) {
    const errors = [];
    const check = (condition, message) => {
      if (!condition) errors.push(message);
    };
    if (!replay || typeof replay !== "object")
      return ["Replay deve ser um objeto."];
    check(replay.version === 1, "Versão de replay incompatível.");
    check(
      ["authored_preview", "simulation"].includes(replay.source),
      "Origem do registro ausente.",
    );
    const ids = replay.fighter_ids;
    check(
      Array.isArray(ids) &&
        ids.length === 2 &&
        ids.every((x) => typeof x === "string" && x) &&
        ids[0] !== ids[1],
      "Dois atletas distintos são obrigatórios.",
    );
    if (!Array.isArray(ids) || ids.length !== 2) return errors;
    const arena = arenas.arenas.find((x) => x.id === replay.organization_id);
    check(!!arena, "Organização sem arena.");
    if (arena)
      check(
        arena.ruleset_id === replay.ruleset_id,
        "Ruleset não corresponde à arena.",
      );
    const clips = new Map(catalog.clips.map((x) => [x.id, x]));
    const state = (s, where) => {
      if (!s || typeof s !== "object") {
        errors.push(where + ": estado ausente.");
        return false;
      }
      check(
        catalog.positions.includes(s.position),
        where + ": posição desconhecida.",
      );
      check(
        ["center", "cage", "ropes"].includes(s.location),
        where + ": local desconhecido.",
      );
      if (arena)
        check(
          s.location === "center" ||
            s.location === (arena.venue === "ring" ? "ropes" : "cage"),
          where + ": limite incompatível com arena.",
        );
      check(
        ground.has(s.position) ? ids.includes(s.top_id) : s.top_id === null,
        where + ": top_id incompatível com posição.",
      );
      for (const id of ids) {
        check(
          Number.isFinite(s.stamina?.[id]) &&
            s.stamina[id] >= 0 &&
            s.stamina[id] <= 1,
          where + ": stamina inválida.",
        );
        for (const zone of ["head", "body", "leg"])
          check(
            Number.isFinite(s.damage?.[id]?.[zone]) &&
              s.damage[id][zone] >= 0 &&
              s.damage[id][zone] <= 1,
            where + ": dano inválido.",
          );
      }
      return true;
    };
    state(replay.initial_state, "Inicial");
    let previous = replay.initial_state;
    let end = 0,
      round = 0,
      clock = Infinity;
    const seen = new Set();
    check(
      Array.isArray(replay.events) && replay.events.length > 0,
      "Registro de eventos vazio.",
    );
    for (const [i, e] of (Array.isArray(replay.events)
      ? replay.events
      : []
    ).entries()) {
      const at = `Evento ${i + 1}`;
      if (!e || typeof e !== "object") {
        errors.push(at + ": inválido.");
        continue;
      }
      check(
        typeof e.id === "string" && e.id && !seen.has(e.id),
        at + ": id ausente ou repetido.",
      );
      seen.add(e.id);
      check(
        Number.isFinite(e.at_ms) && e.at_ms >= end,
        at + ": eventos sobrepostos ou fora de ordem.",
      );
      check(
        Number.isFinite(e.duration_ms) && e.duration_ms > 0,
        at + ": duração inválida.",
      );
      end = e.at_ms + e.duration_ms;
      check(
        Number.isInteger(e.round) && e.round >= Math.max(1, round),
        at + ": round inválido.",
      );
      check(
        Number.isFinite(e.clock_s) &&
          e.clock_s >= 0 &&
          e.clock_s <= 300 &&
          (e.round !== round || e.clock_s <= clock),
        at + ": relógio inválido.",
      );
      round = e.round;
      clock = e.clock_s;
      check(
        ids.includes(e.actor_id) &&
          ids.includes(e.target_id) &&
          e.actor_id !== e.target_id,
        at + ": papéis inválidos.",
      );
      check(e.rules_approved === true, at + ": aprovação do ruleset ausente.");
      check(
        Array.isArray(e.reason_codes) &&
          e.reason_codes.length > 0 &&
          e.reason_codes.every((x) => typeof x === "string"),
        at + ": reason codes ausentes.",
      );
      const beforeOK = state(e.before, at + " antes"),
        afterOK = state(e.after, at + " depois");
      check(
        equal(e.before, previous),
        at + ": continuidade de estados rompida.",
      );
      previous = e.after;
      const c = clips.get(e.technique_id);
      check(!!c, at + ": técnica desconhecida " + e.technique_id);
      if (!c || !beforeOK || !afterOK) continue;
      check(
        c.from_positions.includes(e.before.position),
        at + ": técnica não parte desta posição.",
      );
      check(c.outcomes.includes(e.outcome), at + ": resultado sem animação.");
      check(
        e.after.position === expectedPosition(c, e),
        at + ": transição incompatível.",
      );
      if (c.actor_role === "top" && ground.has(e.before.position))
        check(
          e.before.top_id === e.actor_id,
          at + ": técnica requer atleta por cima.",
        );
      if (c.actor_role === "bottom" && ground.has(e.before.position))
        check(
          e.before.top_id === e.target_id,
          at + ": técnica requer atleta por baixo.",
        );
    }
    if (replay.result) {
      check(
        ["ko_tko", "submission", "decision", "draw", "nc", "dq"].includes(
          replay.result.method,
        ),
        "Método final inválido.",
      );
      check(
        replay.result.winner_id === null ||
          ids.includes(replay.result.winner_id),
        "Vencedor inválido.",
      );
      if (["draw", "nc"].includes(replay.result.method))
        check(replay.result.winner_id === null, "Empate/NC não tem vencedor.");
    }
    return errors;
  }
  class Player {
    constructor(replay, catalog, arenas) {
      const errors = validate(replay, catalog, arenas);
      if (errors.length) throw new Error(errors.join("\n"));
      this.log = clone(replay);
      this.catalog = catalog;
      this.clips = new Map(catalog.clips.map((c) => [c.id, c]));
      this.duration = Math.max(
        ...replay.events.map((e) => e.at_ms + e.duration_ms),
      );
      this.ends = this.log.events.map((e) => {
        const c = this.clips.get(e.technique_id),
          last = c.tracks[e.outcome].at(-1),
          flip = e.actor_id !== this.log.fighter_ids[0];
        return {
          [e.actor_id]: flip ? reflect(last.a) : clone(last.a),
          [e.target_id]: flip ? reflect(last.b) : clone(last.b),
        };
      });
    }
    sample(time) {
      const t = clamp(Number.isFinite(time) ? time : 0, 0, this.duration);
      const es = this.log.events;
      let lo = 0,
        hi = es.length - 1;
      while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (es[mid].at_ms <= t) lo = mid;
        else hi = mid - 1;
      }
      const e = es[lo],
        c = this.clips.get(e.technique_id),
        progress = clamp((t - e.at_ms) / e.duration_ms, 0, 1),
        frames = c.tracks[e.outcome];
      let n = 0;
      while (n < frames.length - 2 && frames[n + 1].t < progress) n++;
      const f = frames[n],
        g = frames[n + 1];
      let u = clamp((progress - f.t) / (g.t - f.t), 0, 1);
      u = u * u * (3 - 2 * u);
      let a = mixPose(f.a, g.a, u),
        b = mixPose(f.b, g.b, u);
      const first = e.actor_id === this.log.fighter_ids[0];
      if (!first) {
        a = reflect(a);
        b = reflect(b);
      }
      // Visual placement only; full state changes at the engine's event boundary.
      const poses = { [e.actor_id]: a, [e.target_id]: b };
      // Blend entry from the actual previous endpoint by id, never teleport/swap fighters.
      if (lo > 0 && progress < 0.26) {
        let blend = progress / 0.26;
        blend = blend * blend * (3 - 2 * blend);
        for (const id of this.log.fighter_ids)
          poses[id] = mixPose(this.ends[lo - 1][id], poses[id], blend);
      }

      for (const id of this.log.fighter_ids) {
        poses[id].facing = id === this.log.fighter_ids[0] ? 1 : -1;
        poses[id].bend = [-1, 1, 1, 1].map((v) => v * poses[id].facing);
      }
      const state = clone(progress >= 1 ? e.after : e.before);
      return {
        fighter_ids: this.log.fighter_ids,
        time: t,
        event_index: lo,
        event: clone(e),
        clip: c,
        progress,
        poses,
        state,
        finished: t >= this.duration,
        result: t >= this.duration ? clone(this.log.result || null) : null,
      };
    }
  }
  // Deterministic two-bone inverse kinematics. Targets are clamped to limb reach.
  function ik(origin, target, l1, l2, bend = 1) {
    const dx = target[0] - origin[0],
      dy = target[1] - origin[1],
      dist = Math.hypot(dx, dy),
      d = clamp(dist, Math.abs(l1 - l2) + 0.0001, l1 + l2 - 0.0001),
      angle = Math.atan2(dy, dx),
      c = clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1),
      theta = angle + Math.acos(c) * Math.sign(bend || 1);
    return {
      joint: [
        origin[0] + Math.cos(theta) * l1,
        origin[1] + Math.sin(theta) * l1,
      ],
      end: [origin[0] + Math.cos(angle) * d, origin[1] + Math.sin(angle) * d],
    };
  }
  function skeleton(p, appearance = {}) {
    const b = appearance.body || {},
      h = 0.94 + (b.height ?? 0.5) * 0.12,
      angle = (p.lean * Math.PI) / 180,
      up = [Math.sin(angle), Math.cos(angle)],
      side = [
        Math.cos(angle) * (p.facing ?? 1),
        -Math.sin(angle) * (p.facing ?? 1),
      ],
      fem = appearance.sex === "f",
      shoulder = (fem ? 0.135 : 0.16) + (b.shoulders ?? 0.5) * 0.05;
    const add = (v, x, y) => [
      v[0] + side[0] * x + up[0] * y,
      v[1] + side[1] * x + up[1] * y,
    ];
    const hip = p.root,
      neck = add(hip, 0, 0.53 * h),
      head = add(neck, 0, 0.16 * h);
    const shoulders = [
        add(neck, -shoulder, -0.065),
        add(neck, shoulder, -0.065),
      ],
      hips = [add(hip, -0.092, 0), add(hip, 0.092, 0)];
    const arms = shoulders.map((s, i) => {
      const candidates = [
        ik(s, p.hands[i], 0.305 * h, 0.285 * h, -1),
        ik(s, p.hands[i], 0.305 * h, 0.285 * h, 1),
      ];
      const viable = candidates.filter((k) => k.joint[1] >= 0.025);
      return (viable.length ? viable : candidates).sort(
        (a, b) =>
          a.joint[0] * up[0] +
          a.joint[1] * up[1] -
          (b.joint[0] * up[0] + b.joint[1] * up[1]),
      )[0];
    });
    const legs = hips.map((s, i) => {
      const a = ik(s, p.feet[i], 0.44 * h, 0.43 * h, p.bend[i + 2]),
        b = ik(s, p.feet[i], 0.44 * h, 0.43 * h, -p.bend[i + 2]);
      return a.joint[1] >= 0.02 ? a : b;
    });
    return { hip, neck, head, shoulders, hips, arms, legs, up, side, h };
  }
  return {
    Player,
    validate,
    expectedPosition,
    mixPose,
    reflect,
    ik,
    skeleton,
    ground,
  };
});
