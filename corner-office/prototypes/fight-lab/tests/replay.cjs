const assert = require("node:assert/strict"),
  fs = require("node:fs"),
  path = require("node:path"),
  vm = require("node:vm");
const D = path.resolve(__dirname, "../../../game/content"),
  read = (p) => JSON.parse(fs.readFileSync(path.join(D, p), "utf8"));
const R = require("../replay"),
  catalog = read("fight_visuals.json"),
  arenas = read("arena_profiles.json"),
  examples = [
    ...read("replays/index.json"),
    ...read("replays/simulated_index.json"),
  ].map((x) => read("replays/" + x.file));
const clone = (x) => JSON.parse(JSON.stringify(x));
let samples = 0;
assert.equal(
  new Set(catalog.clips.map((c) => c.id)).size,
  catalog.clips.length,
);
assert.equal(arenas.arenas.length, read("organizations.json").length);
for (const a of arenas.arenas) {
  const org = read("organizations.json").find((o) => o.id === a.id),
    rules = read("rulesets.json").find((r) => r.id === org.ruleset_id);
  assert.equal(a.venue, rules.venue);
  assert.equal(a.sides, a.venue === "ring" ? 4 : 8);
}
function one(c, outcome) {
  const s = clone(examples[0].initial_state);
  s.position = c.from_positions[0];
  s.top_id = R.ground.has(s.position)
    ? c.actor_role === "bottom"
      ? "blue"
      : "red"
    : null;
  const e = {
    id: "test",
    at_ms: 0,
    duration_ms: c.duration_ms,
    round: 1,
    clock_s: 300,
    actor_id: "red",
    target_id: "blue",
    technique_id: c.id,
    outcome,
    rules_approved: true,
    reason_codes: ["TEST"],
    before: clone(s),
    after: clone(s),
  };
  e.after.position = R.expectedPosition(c, e);
  e.after.top_id = R.ground.has(e.after.position) ? s.top_id || "red" : null;
  return { ...clone(examples[0]), initial_state: s, events: [e], result: null };
}
for (const c of catalog.clips) {
  assert.ok(c.styles.length);
  assert.ok(c.from_positions.every((p) => catalog.positions.includes(p)));
  for (const o of c.outcomes) {
    const replay = one(c, o),
      player = new R.Player(replay, catalog, arenas),
      before = JSON.stringify(replay);
    for (let i = 0; i <= 10; i++) {
      const frame = player.sample((player.duration * i) / 10);
      for (const pose of Object.values(frame.poses)) {
        for (const v of [pose.root, ...pose.hands, ...pose.feet])
          assert.ok(v.every(Number.isFinite), c.id);
        const sk = R.skeleton(pose, {
          sex: i % 2 ? "f" : "m",
          body: { height: i / 10 },
        });
        for (const limb of [...sk.arms, ...sk.legs])
          assert.ok([...limb.end, ...limb.joint].every(Number.isFinite));
      }
      assert.deepEqual(frame, player.sample((player.duration * i) / 10));
      samples++;
    }
    assert.equal(JSON.stringify(replay), before);
    assert.deepEqual(
      player.sample(player.duration).state,
      replay.events[0].after,
    );
    assert.deepEqual(player.sample(-100), player.sample(0));
  }
}
for (const log of examples) {
  assert.deepEqual(R.validate(log, catalog, arenas), [], log.id);
  const player = new R.Player(log, catalog, arenas);
  for (const e of log.events)
    assert.equal(player.sample(e.at_ms).event.id, e.id);
  assert.deepEqual(player.sample(player.duration).result, log.result);
  let t = 0;
  for (const speed of [1, 2, 5]) {
    while (t < player.duration) t += (1000 / 60) * speed;
    assert.deepEqual(player.sample(t).result, log.result);
  }
}
// Event boundaries preserve each fighter's actual prior pose, including actor swaps.
for (const log of examples) {
  const player = new R.Player(log, catalog, arenas);
  for (let i = 1; i < log.events.length; i++) {
    const at = log.events[i].at_ms,
      previous = player.sample(at - 0.00001),
      current = player.sample(at);
    for (const id of log.fighter_ids) {
      for (const field of ["root", "hands", "feet"]) {
        const a = previous.poses[id][field].flat(),
          b = current.poses[id][field].flat();
        a.forEach((v, j) =>
          assert.ok(
            Math.abs(v - b[j]) < 0.00001,
            "No teleport: " + log.id + "/" + id + "/" + field,
          ),
        );
      }
      assert.equal(
        current.poses[id].facing,
        id === log.fighter_ids[0] ? 1 : -1,
      );
    }
  }
}
// All limbs retain their lengths across an animated sequence, for both physiques.
for (const log of examples) {
  const player = new R.Player(log, catalog, arenas);
  for (let t = 0; t < player.duration; t += 67)
    for (const p of Object.values(player.sample(t).poses)) {
      for (const f of [
        { sex: "m", body: { height: 0 } },
        { sex: "f", body: { height: 1 } },
      ]) {
        const sk = R.skeleton(p, f);
        for (const [origin, limb, l1, l2] of [
          ...sk.arms.map((a, i) => [
            sk.shoulders[i],
            a,
            0.305 * sk.h,
            0.285 * sk.h,
          ]),
          ...sk.legs.map((a, i) => [sk.hips[i], a, 0.44 * sk.h, 0.43 * sk.h]),
        ]) {
          assert.ok(
            Math.abs(
              Math.hypot(limb.joint[0] - origin[0], limb.joint[1] - origin[1]) -
                l1,
            ) < 1e-8,
          );
          assert.ok(
            Math.abs(
              Math.hypot(
                limb.end[0] - limb.joint[0],
                limb.end[1] - limb.joint[1],
              ) - l2,
            ) < 1e-8,
          );
        }
      }
    }
}
// Reject misleading playback; no silent fallback to a different move or result.
for (const mutate of [
  (x) => (x.version = 2),
  (x) => (x.events[0].technique_id = "unknown"),
  (x) => (x.events[0].outcome = "fabricated"),
  (x) => (x.events[0].rules_approved = false),
  (x) => (x.events[1].before.stamina.red = 0.5),
  (x) => (x.events[1].at_ms = 0),
  (x) => (x.events[0].actor_id = x.events[0].target_id),
  (x) => (x.events[0].duration_ms = -1),
  (x) => (x.events[0].after.position = "guard"),
  (x) => (x.initial_state.stamina.red = NaN),
]) {
  const bad = clone(examples[0]);
  mutate(bad);
  assert.ok(R.validate(bad, catalog, arenas).length);
  assert.throws(() => new R.Player(bad, catalog, arenas));
}
// Reach constraints: no stretching skeletons when source anchors are extreme.
for (const target of [
  [0, 0],
  [100, 100],
  [-100, 20],
]) {
  const k = R.ik([0, 0], target, 0.3, 0.28);
  assert.ok(Math.abs(Math.hypot(...k.joint) - 0.3) < 1e-8);
  assert.ok(
    Math.abs(Math.hypot(k.end[0] - k.joint[0], k.end[1] - k.joint[1]) - 0.28) <
      1e-8,
  );
}
console.log(
  JSON.stringify({
    passed: true,
    techniques: catalog.clips.length,
    outcome_tracks: catalog.clips.reduce((n, c) => n + c.outcomes.length, 0),
    samples,
    replays: examples.length,
    arenas: arenas.arenas.length,
  }),
);
// Optional real Canvas visual checks (same shared identity and renderer).
if (process.env.CANVAS_MODULE_PATH) {
  const { createCanvas, Path2D } = require(process.env.CANVAS_MODULE_PATH),
    ctx = vm.createContext({
      console,
      Path2D,
      window: { devicePixelRatio: 1 },
      document: { createElement: () => createCanvas(1, 1) },
      FightReplay: R,
    });
  ctx.window.FightReplay = R;
  for (const file of [
    "../../face-lab/studio.js",
    "../../face-lab/identity.js",
    "../renderer.js",
  ])
    vm.runInContext(
      fs.readFileSync(path.resolve(__dirname, file), "utf8"),
      ctx,
    );
  vm.runInContext("this.faces=CANON;this.Renderer=window.FightRenderer;", ctx);
  const cv = createCanvas(1000, 600);
  cv.clientWidth = 1000;
  cv.clientHeight = 600;
  const renderer = new ctx.Renderer(cv),
    apps = { red: ctx.faces[0], blue: ctx.faces[1] };
  let renders = 0;
  for (const a of arenas.arenas) {
    renderer.render(
      new R.Player(examples[0], catalog, arenas).sample(300),
      a,
      apps,
    );
    renders++;
  }
  for (const c of catalog.clips) {
    const p = new R.Player(one(c, c.outcomes[0]), catalog, arenas);
    renderer.render(p.sample(p.duration * 0.56), arenas.arenas[0], apps);
    renders++;
  }
  if (process.env.VISUAL_OUTPUT) {
    fs.mkdirSync(process.env.VISUAL_OUTPUT, { recursive: true });
    for (const id of [
      "jab",
      "head_roundhouse",
      "clinch_knee_body",
      "double_leg",
      "guard_punch",
      "rear_naked_choke",
    ]) {
      const c = catalog.clips.find((c) => c.id === id),
        p = new R.Player(one(c, c.outcomes[0]), catalog, arenas);
      renderer.camera = "detail";
      renderer.render(p.sample(p.duration * 0.56), arenas.arenas[0], apps);
      fs.writeFileSync(
        path.join(process.env.VISUAL_OUTPUT, id + ".png"),
        cv.toBuffer("image/png"),
      );
    }
  }
  console.log(JSON.stringify({ canvas_renders: renders, passed: true }));
}
