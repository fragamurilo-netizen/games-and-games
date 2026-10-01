/* Canvas presentation only. Game Bible §§5,15–17. Shared faces from face-lab.
 * Arena identity lives in content/arena_profiles.json; no organization literals.
 */
(function (root) {
  "use strict";
  const rgba = (hex, a) => {
    const [r, g, b] = h2r(hex);
    return `rgba(${r},${g},${b},${Math.max(0, Math.min(1, a))})`;
  };
  const clamp01 = (v) => Math.max(0, Math.min(1, v));
  // Injuries drawn onto the face sprite (face-lab units: eyes at x ±.3, y .02;
  // brows y -.13; nostrils y .43; mouth y .6). source-atop keeps paint on the head.
  function faceWounds(c, f, fd) {
    const S = 101,
      X = (x) => 128 + x * S,
      Y = (y) => 146 + y * S,
      skin = SKIN[f.skin]?.[0] || "#B7805D";
    const blot = (x, y, rx, ry, color, alpha, rot = 0) => {
      if (alpha <= 0.005) return;
      c.save();
      c.translate(X(x), Y(y));
      c.rotate(rot);
      c.scale(1, ry / rx);
      const g = c.createRadialGradient(0, 0, 0, 0, 0, rx * S);
      g.addColorStop(0, rgba(color, alpha));
      g.addColorStop(0.55, rgba(color, alpha * 0.6));
      g.addColorStop(1, rgba(color, 0));
      c.fillStyle = g;
      c.beginPath();
      c.arc(0, 0, rx * S, 0, Math.PI * 2);
      c.fill();
      c.restore();
    };
    // A tapering run of blood that follows gravity down the face.
    const stream = (x, y, len, width, wobble, seed, alpha = 0.92) => {
      if (len <= 0.01) return;
      const pts = [];
      for (let k = 0; k <= 16; k++) {
        const t = k / 16;
        // Blood beads and thins as it runs; the path follows facial contours loosely.
        pts.push([x + Math.sin(t * 5.3 + seed * 6) * wobble * 1.6 + Math.sin(t * 13 + seed * 3) * wobble * 0.5, y + t * len, width * (1 - t * 0.6) * (0.8 + 0.35 * Math.sin(t * 9 + seed * 5) ** 2)]);
      }
      // Thin smear where the run was wiped by gloves and sweat.
      c.strokeStyle = rgba("#8E2027", alpha * 0.18);
      c.lineWidth = width * S * 3.2;
      c.lineCap = "round";
      c.beginPath();
      pts.forEach(([px, py], i) => (i ? c.lineTo(X(px), Y(py)) : c.moveTo(X(px), Y(py))));
      c.stroke();
      c.beginPath();
      pts.forEach(([px, py, w], i) => (i ? c.lineTo(X(px - w), Y(py)) : c.moveTo(X(px - w), Y(py))));
      for (let i = pts.length - 1; i >= 0; i--) c.lineTo(X(pts[i][0] + pts[i][2]), Y(pts[i][1]));
      c.closePath();
      c.fillStyle = rgba("#5E0A10", alpha * 0.9);
      c.fill();
      c.strokeStyle = rgba("#C9464B", alpha * 0.35);
      c.lineWidth = 1;
      c.beginPath();
      pts.forEach(([px, py, w], i) => (i ? c.lineTo(X(px - w * 0.4), Y(py)) : c.moveTo(X(px - w * 0.4), Y(py))));
      c.stroke();
      const [ex, ey, ew] = pts[pts.length - 1];
      c.fillStyle = rgba("#6E0C12", alpha);
      c.beginPath();
      c.ellipse(X(ex), Y(ey + ew * 0.6), ew * 1.25 * S, ew * 1.6 * S, 0, 0, Math.PI * 2);
      c.fill();
    };
    c.save();
    c.globalCompositeOperation = "source-atop";
    const H = clamp01(fd.head / 0.22),
      sweat = clamp01((fd.sweat - 0.3) / 0.6);
    // Exertion and accumulated punishment redden the face.
    for (const s of [-1, 1]) blot(s * 0.3, 0.27, 0.2, 0.14, "#B8403A", 0.1 * sweat + 0.3 * H);
    blot(0, 0.3, 0.08, 0.13, "#B03A36", 0.35 * H);
    for (const s of [-1, 1]) {
      const sw = Math.min(1.4, fd.swell[s] / 0.1);
      if (sw <= 0.02) continue;
      // Orbital hematoma: purple centre, red rim, a shine where skin is stretched.
      blot(s * 0.34, 0.12, 0.27, 0.18, "#9C3A3A", 0.3 * Math.min(1, sw));
      blot(s * 0.32, 0.09, 0.19, 0.12, "#4A2142", 0.6 * Math.min(1, sw));
      blot(s * 0.37, 0.19, 0.12, 0.06, "#FFFFFF", 0.13 * Math.min(1, sw), s * 0.3);
      const close = clamp01((sw - 0.8) / 0.6);
      if (close > 0.03) {
        const puffy = mix(skin, "#6B3148", 0.35);
        c.globalAlpha = Math.min(1, close * 1.6);
        c.fillStyle = puffy;
        c.beginPath();
        c.ellipse(X(s * 0.3), Y(-0.02 + close * 0.03), 0.15 * S, (0.04 + close * 0.045) * S, 0, 0, Math.PI * 2);
        c.fill();
        c.fillStyle = mix(skin, "#5A2A40", 0.45);
        c.beginPath();
        c.ellipse(X(s * 0.3), Y(0.085 - close * 0.02), 0.14 * S, (0.03 + close * 0.03) * S, 0, 0, Math.PI * 2);
        c.fill();
        c.strokeStyle = "#2A1218";
        c.lineWidth = 1.4;
        c.beginPath();
        c.moveTo(X(s * 0.3 - 0.11), Y(0.045));
        c.quadraticCurveTo(X(s * 0.3), Y(0.06), X(s * 0.3 + 0.11), Y(0.04));
        c.stroke();
        c.globalAlpha = 1;
        blot(s * 0.3, -0.04, 0.1, 0.03, "#FFFFFF", 0.18 * close);
      }
    }
    if (fd.head > 0.1) {
      const s = fd.swell[1] >= fd.swell[-1] ? 1 : -1,
        k = clamp01((fd.head - 0.1) / 0.15);
      blot(s * 0.2, -0.33, 0.12, 0.08, "#A2403E", 0.4 * k);
      blot(s * 0.19, -0.36, 0.09, 0.05, "#FFFFFF", 0.07 * k);
    }
    const lip = clamp01(fd.lip / 0.07);
    if (lip > 0.05) {
      blot(0.08, 0.6, 0.075, 0.035, "#8E2A31", 0.6 * lip);
      c.strokeStyle = rgba("#4A0A10", 0.8 * lip);
      c.lineWidth = 1.3;
      c.beginPath();
      c.moveTo(X(0.07), Y(0.585));
      c.lineTo(X(0.1), Y(0.625));
      c.stroke();
    }
    const nose = clamp01(fd.nose);
    if (nose > 0.05) {
      for (const s of [-1, 1]) stream(s * 0.045, 0.42, (0.08 + nose * 0.3) * (s < 0 ? 1 : 0.7), 0.012 + nose * 0.01, 0.006, s + 2, 0.85);
      blot(0, 0.5, 0.1, 0.03, "#6E0C12", 0.55 * nose);
    }
    const SPOTS = [[0.28, -0.14], [0.42, -0.07], [0.36, 0.2], [0.13, -0.36], [0.03, 0.12], [0.24, -0.12]];
    for (const cut of fd.cuts) {
      const [sx, sy] = SPOTS[Math.floor(cut.u * SPOTS.length) % SPOTS.length],
        x = cut.side * sx,
        y = sy,
        sev = clamp01(cut.sev / 0.2),
        L = 0.06 + sev * 0.08,
        a = (cut.v - 0.5) * 0.9;
      blot(x, y, 0.11, 0.07, "#A8262B", 0.45);
      // The run lengthens for a couple of seconds after the cut opens.
      const flow = clamp01(cut.age / 2600),
        len = (0.25 + sev * 0.75) * flow;
      const n = 1 + (sev > 0.55 ? 1 : 0) + (sev > 0.85 ? 1 : 0);
      for (let k = 0; k < n; k++)
        stream(x + (k - (n - 1) / 2) * 0.035 + cut.side * 0.01, y + 0.01, len * (1 - k * 0.3) * (0.8 + cut.v * 0.4), 0.01 + sev * 0.011, 0.012, cut.u + k);
      c.strokeStyle = "#3A070B";
      c.lineCap = "round";
      c.lineWidth = 2.6;
      c.beginPath();
      c.moveTo(X(x - Math.cos(a) * L * 0.5), Y(y - Math.sin(a) * L * 0.5));
      c.lineTo(X(x + Math.cos(a) * L * 0.5), Y(y + Math.sin(a) * L * 0.5));
      c.stroke();
      c.strokeStyle = "#D2383E";
      c.lineWidth = 1;
      c.beginPath();
      c.moveTo(X(x - Math.cos(a) * L * 0.45), Y(y - Math.sin(a) * L * 0.45 - 0.008));
      c.lineTo(X(x + Math.cos(a) * L * 0.45), Y(y + Math.sin(a) * L * 0.45 - 0.008));
      c.stroke();
    }
    // Sweat catches the arena light on forehead, nose and cheekbones.
    if (sweat > 0.02)
      for (const [x, y, r] of [[-0.18, -0.36, 0.05], [0.16, -0.3, 0.04], [0.02, 0.27, 0.025], [-0.36, 0.2, 0.03], [0.38, 0.12, 0.03]])
        blot(x, y, r, r * 0.6, "#FFFFFF", 0.45 * sweat);
    c.restore();
  }
  class FightRenderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.heads = new Map();
      this.camera = "broadcast";
      this.showRig = false;
      // Optional director camera (broadcast shell): zoom/focus/shake around the
      // cage floor. Presentation only; the replay pose data is untouched.
      this.view = null;
      this.hud = true;
    }
    head(f) {
      const key = JSON.stringify(f);
      if (this.heads.has(key)) return this.heads.get(key);
      const cv = document.createElement("canvas");
      cv.width = 256;
      cv.height = 320;
      drawFace(cv.getContext("2d"), 256, 320, f, STYLES.studio, {
        S: 101,
        ox: 128,
        oy: 146,
        noBody: true,
        skipNeck: true,
      });
      this.heads.set(key, cv);
      return cv;
    }
    // Face sprite with the fight's injuries; quantized so a bout reuses a few dozen sprites.
    damagedHead(f, fd) {
      const base = this.head(f),
        q = (v, k = 100) => Math.round(v * k);
      if (!fd || (fd.head <= 0 && !fd.cuts.length && fd.nose <= 0.05 && fd.sweat < 0.32)) return base;
      const key = [
        JSON.stringify(f),
        q(fd.head),
        q(fd.swell[-1]),
        q(fd.swell[1]),
        q(fd.nose, 20),
        q(fd.lip),
        q(fd.sweat, 10),
        ...fd.cuts.map((x) => [q(x.u), q(x.sev), Math.min(10, Math.floor(x.age / 260))].join(":")),
      ].join("|");
      this.hurt ||= new Map();
      if (this.hurt.has(key)) return this.hurt.get(key);
      if (this.hurt.size > 90) this.hurt.clear();
      const cv = document.createElement("canvas");
      cv.width = base.width;
      cv.height = base.height;
      const c = cv.getContext("2d");
      c.drawImage(base, 0, 0);
      faceWounds(c, f, fd);
      this.hurt.set(key, cv);
      return cv;
    }
    // Everything a fighter's body shows at this moment, rebuilt from recorded hits.
    woundState(frame, id) {
      const t = frame.time,
        st = frame.state,
        fd = { head: 0, swell: { "-1": 0, 1: 0 }, cuts: [], nose: 0, lip: 0, body: [], leg: [], arm: [], spray: null, time: t };
      fd.sweat = 1 - (st.stamina?.[id] ?? 1);
      fd.stun = st.stun?.[id] || 0;
      fd.cut = st.cuts?.[id] || 0;
      for (const w of frame.wounds || []) {
        if (w.id !== id) continue;
        const age = t - w.at_ms,
          grow = Math.min(1, 0.35 + age / 4000);
        if (w.zone === "head") {
          fd.head += w.power;
          fd.swell[w.side] += (w.power + (w.knockdown ? 0.05 : 0)) * grow;
          if (w.cut > 0) fd.cuts.push({ u: w.u, v: w.v, side: w.side, sev: w.cut, age });
          if (w.power > 0.022) fd.lip += w.power;
          if (w.knockdown) fd.nose += 0.45;
          if (age < 420 && (w.power > 0.012 || w.knockdown))
            fd.spray = { age, power: w.power + (w.knockdown ? 0.04 : 0), seed: w.u, bloody: w.cut > 0 || fd.cut > 0.05 };
        } else fd[w.zone]?.push({ ...w, age });
      }
      fd.nose += Math.max(0, fd.head - 0.12) * 3;
      const other = frame.fighter_ids.find((x) => x !== id);
      fd.glove = Math.min(0.7, (st.cuts?.[other] || 0) * 2.5);
      return fd;
    }
    render(frame, arena, appearances) {
      const cv = this.canvas,
        c = this.ctx,
        dpr = Math.min(2, window.devicePixelRatio || 1),
        W = cv.clientWidth || 960,
        H = cv.clientHeight || 600;
      if (
        cv.width !== Math.round(W * dpr) ||
        cv.height !== Math.round(H * dpr)
      ) {
        cv.width = Math.round(W * dpr);
        cv.height = Math.round(H * dpr);
      }
      c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.clearRect(0, 0, W, H);
      this.W = W;
      this.H = H;
      this.S =
        Math.min(W / (W < 600 ? 4.8 : 8.8), H / 4.5) *
        (this.camera === "detail"
          ? 1.65
          : this.camera === "tactical"
            ? 0.85
            : 1.2);
      this.floor = H * 0.76;
      const bg = c.createLinearGradient(0, 0, 0, H);
      bg.addColorStop(0, "#101418");
      bg.addColorStop(0.7, "#252F36");
      bg.addColorStop(1, "#0C1013");
      c.fillStyle = bg;
      c.fillRect(0, 0, W, H);
      // Seeded crowd pattern is static and independent from the simulation RNG.
      for (let row = 0; row < 5; row++)
        for (let i = 0; i < 65; i++) {
          const x = ((i + 0.5) * W) / 65 + (row % 2) * 6,
            y = H * 0.2 + row * 11;
          const n = (i * 71 + row * 113) % 29;
          c.fillStyle = n < 6 ? "#48525B" : n < 18 ? "#29343D" : "#1B242B";
          c.beginPath();
          c.ellipse(x, y, 3.3, 4.2, 0, 0, Math.PI * 2);
          c.fill();
          c.fillRect(x - 4, y + 4, 8, 6);
        }
      for (const side of [-1, 1]) {
        const g = c.createLinearGradient(
          W * 0.5 + side * W * 0.26,
          0,
          W * 0.5,
          H,
        );
        g.addColorStop(0, "rgba(232,231,209,.08)");
        g.addColorStop(1, "rgba(232,231,209,0)");
        c.fillStyle = g;
        c.beginPath();
        c.moveTo(W * 0.5 + side * W * 0.26, 0);
        c.lineTo(W * 0.5 + side * W * 0.48, H * 0.75);
        c.lineTo(W * 0.5 - side * W * 0.08, H * 0.75);
        c.fill();
      }
      const view = this.view;
      if (view) {
        c.save();
        const zoom = view.zoom || 1;
        c.translate(W * 0.5 + (view.shakeX || 0), this.floor + (view.shakeY || 0));
        c.scale(zoom, zoom);
        c.translate(-W * 0.5 - (view.focusX || 0) * this.S, -this.floor + (view.lift || 0) * this.S);
      }
      this.arena(arena, false);
      this.blood(frame.stains || []);
      const ids = Object.keys(frame.poses),
        location = frame.state.location,
        offset = location === "center" ? 0 : arena.radius_m * 0.53;
      for (const id of ids) {
        const p = frame.poses[id];
        const [x, y] = this.project(p.root[0] + offset, 0, 0.06);
        c.fillStyle = "rgba(9,13,15,.29)";
        c.beginPath();
        c.ellipse(
          x,
          y,
          this.S * (FightReplay.ground.has(frame.state.position) ? 0.58 : 0.38),
          this.S * 0.075,
          0,
          0,
          Math.PI * 2,
        );
        c.fill();
      }
      // Bottom fighter first, top fighter last for occlusion in grappling.
      ids.sort(
        (a, b) =>
          (a === frame.state.top_id ? 1 : 0) -
          (b === frame.state.top_id ? 1 : 0),
      );
      for (const id of ids)
        this.fighter(
          frame.poses[id],
          appearances[id],
          id === frame.fighter_ids[0] ? arena.red_corner : arena.blue_corner,
          offset,
          frame.state.damage[id],
          frame.state.cuts?.[id] || 0,
          this.woundState(frame, id),
        );
      this.arena(arena, true);
      if (frame.clip.category === "official")
        this.referee(frame.progress, frame.event.technique_id, offset);
      if (view) c.restore();
      if (!this.hud) return;
      c.fillStyle = "rgba(12,16,19,.70)";
      c.fillRect(18, 18, 170, 29);
      c.fillStyle = "#E6E3DB";
      c.font = "600 11px system-ui";
      c.fillText(
        arena.venue === "ring" ? "RINGUE · 4 CORDAS" : "ARENA · 8 LADOS",
        30,
        37,
      );
      c.textAlign = "right";
      c.fillStyle = "#CFD3D6";
      c.font = "11px system-ui";
      c.fillText(
        this.camera === "detail"
          ? "CÂMERA DE DETALHE"
          : this.camera === "tactical"
            ? "VISTA TÁTICA"
            : "TRANSMISSÃO",
        W - 22,
        37,
      );
      c.textAlign = "left";
    }
    blood(marks) {
      const c = this.ctx;
      c.save();
      for (const m of marks) {
        const point = this.project(m.x, 0.003, m.z);
        c.save();
        c.translate(...point);
        c.scale(1, 0.42);
        c.rotate(m.angle);
        c.globalAlpha = m.opacity;
        c.fillStyle = "#692D30";
        c.beginPath();
        c.ellipse(0, 0, m.rx * this.S, m.rz * this.S, 0, 0, Math.PI * 2);
        c.fill();
        c.restore();
      }
      c.restore();
    }
    project(x, y, z = 0) {
      return [
        this.W * 0.5 + x * this.S,
        this.floor - y * this.S + z * this.S * 0.42,
      ];
    }
    line(a, b, color, width = 1, alpha = 1) {
      const c = this.ctx;
      c.save();
      c.globalAlpha = alpha;
      c.strokeStyle = color;
      c.lineWidth = width;
      c.beginPath();
      c.moveTo(...a);
      c.lineTo(...b);
      c.stroke();
      c.restore();
    }
    polygon(points, fill, stroke, width = 1) {
      const c = this.ctx;
      c.beginPath();
      points.forEach((p, i) => (i ? c.lineTo(...p) : c.moveTo(...p)));
      c.closePath();
      if (fill) {
        c.fillStyle = fill;
        c.fill();
      }
      if (stroke) {
        c.strokeStyle = stroke;
        c.lineWidth = width;
        c.stroke();
      }
    }
    arena(a, front) {
      const c = this.ctx,
        N = a.sides,
        R = a.radius_m,
        vertices = Array.from({ length: N }, (_, i) => {
          const angle = ((i + 0.5) * Math.PI * 2) / N;
          return [Math.cos(angle) * R, Math.sin(angle) * R];
        });
      if (!front) {
        const points = vertices.map(([x, z]) => this.project(x, 0, z));
        const apron = vertices.map(([x, z]) =>
          this.project(x * 1.06, -0.18, z * 1.06),
        );
        this.polygon(apron, a.apron);
        this.polygon(points, a.mat, a.accent, 5);
        c.save();
        c.translate(this.W * 0.5, this.floor);
        c.scale(1, 0.43);
        c.strokeStyle = a.accent;
        c.lineWidth = 2;
        c.globalAlpha = 0.35;
        c.beginPath();
        c.arc(0, 0, this.S * 1.29, 0, Math.PI * 2);
        c.stroke();
        c.globalAlpha = 0.85;
        c.textAlign = "center";
        c.fillStyle = a.ink;
        c.font = `800 ${Math.round(this.S * 0.4)}px 'Arial Narrow',sans-serif`;
        c.fillText(a.short_name, 0, -this.S * 0.42);
        c.font = `600 ${Math.round(this.S * 0.12)}px system-ui`;
        c.fillText("CORNER OFFICE · OPEN ERA", 0, -this.S * 0.17);
        // Geometric, fictional center insignia and corner stripes.
        c.strokeStyle = a.accent;
        c.lineWidth = this.S * 0.035;
        c.beginPath();
        const n =
          {
            crown: 5,
            ascent: 3,
            valley: 3,
            sun: 16,
            lines: 4,
            hex: 6,
            wave: 9,
          }[a.mark] || 6;
        for (let i = 0; i < n; i++) {
          const t = (i * Math.PI * 2) / n,
            r = this.S * 0.38;
          const x = Math.cos(t) * r,
            y = Math.sin(t) * r + this.S * 0.49;
          i ? c.lineTo(x, y) : c.moveTo(x, y);
        }
        c.closePath();
        c.stroke();
        c.restore();
      }
      for (let i = 0; i < N; i++) {
        const v = vertices[i],
          w = vertices[(i + 1) % N],
          isFront = (v[1] + w[1]) / 2 > 0;
        if (isFront !== front) continue;
        const foot = this.project(v[0], 0, v[1]),
          top = this.project(v[0], a.height_m, v[1]),
          nextFoot = this.project(w[0], 0, w[1]),
          nextTop = this.project(w[0], a.height_m, w[1]);
        if (a.venue === "ring") {
          for (let r = 1; r <= a.ropes; r++) {
            const h = 0.3 + r * 0.31;
            this.line(
              this.project(v[0], h, v[1]),
              this.project(w[0], h, w[1]),
              r % 2 ? a.accent : "#DDDAD2",
              Math.max(2, this.S * 0.018),
              front ? 0.45 : 0.85,
            );
          }
        } else {
          this.polygon(
            [foot, nextFoot, nextTop, top],
            front ? "rgba(15,20,23,.015)" : "rgba(17,24,28,.12)",
          );
          c.save();
          c.beginPath();
          [foot, nextFoot, nextTop, top].forEach((p, j) =>
            j ? c.lineTo(...p) : c.moveTo(...p),
          );
          c.closePath();
          c.clip();
          const minX = Math.min(foot[0], top[0], nextTop[0]),
            maxX = Math.max(nextFoot[0], foot[0]),
            minY = Math.min(top[1], nextTop[1]),
            maxY = Math.max(foot[1], nextFoot[1]);
          for (
            let x = minX - (maxY - minY);
            x < maxX + (maxY - minY);
            x += 12
          ) {
            this.line(
              [x, minY],
              [x + (maxY - minY) * 0.6, maxY],
              a.steel,
              0.65,
              front ? 0.1 : 0.35,
            );
            this.line(
              [x, minY],
              [x - (maxY - minY) * 0.6, maxY],
              a.steel,
              0.65,
              front ? 0.1 : 0.35,
            );
          }
          c.restore();
          this.line(top, nextTop, a.apron, this.S * 0.065, front ? 0.5 : 1);
          this.line(foot, nextFoot, a.steel, this.S * 0.025, 0.8);
        }
        this.line(
          foot,
          top,
          i === 1 ? a.red_corner : i === N - 2 ? a.blue_corner : a.apron,
          this.S * 0.083,
          front ? 0.58 : 1,
        );
        if (!front) {
          c.save();
          c.translate(top[0], top[1] + this.S * 0.34);
          c.rotate(Math.PI / 2);
          c.fillStyle = "#D7DBD9";
          c.font = `700 ${Math.max(8, this.S * 0.07)}px system-ui`;
          c.fillText(a.short_name, 0, 0);
          c.restore();
        }
      }
    }
    fighter(p, f, corner, offset, damage, cuts = 0, fd = null) {
      // A rocked fighter sways on unsteady legs; the recorded pose stays the anchor.
      if (fd?.stun > 0.05)
        p = { ...p, lean: p.lean + Math.sin(fd.time * 0.006) * Math.min(1, fd.stun) * 9 };
      const c = this.ctx,
        s = FightReplay.skeleton(p, f),
        scale = this.S,
        body = f.body || {},
        muscle = body.muscle ?? 0.65,
        fat = body.fat ?? 0.14,
        // Body-type fields from the appearance catalog; neutral when absent.
        armK = 1 + ((body.arms ?? 0.5) - 0.5) * 0.45,
        legK = 1 + ((body.legMass ?? (f.sex === "f" ? 0.62 : 0.5)) - 0.5) * 0.4,
        neckK = 1 + ((body.neck ?? 0.5) - 0.5) * 0.9,
        belly = body.belly ?? 0,
        fem = f.sex === "f",
        skin = SKIN[f.skin]?.[0] || "#B7805D",
        P = (v) => this.project(v[0] + offset, v[1]),
        skinGrad = (x, r) => studioGradient(c, skin, x, 0, r);
      // Hits on one area merge into a mottled patch: red while fresh, darker and
      // more purple as punishment piles up; a bright flush marks the instant of impact.
      const patch = (x, y, rx, ry, total, age, seed, rot = 0) => {
        const k = Math.min(1, total / 0.1),
          fresh = Math.max(0, 1 - age / 6000),
          r = rngOf(Math.floor(seed * 1e5) + 7);
        if (k > 0.02) {
          studioSoft(c, x, y, rx * (1 + k * 0.6), ry * (1 + k * 0.6), "#A8544C", 0.12 + k * 0.18, rot);
          for (let i = 0; i < 3; i++)
            studioSoft(c, x + (r() - 0.5) * rx * 0.9, y + (r() - 0.5) * ry * 0.9, rx * (0.35 + r() * 0.35) * (0.6 + k * 0.5), ry * (0.3 + r() * 0.35) * (0.6 + k * 0.5), mix(mix("#6A3550", "#4E3A58", r()), "#B8433D", fresh * 0.6), (0.08 + k * 0.3) * (0.7 + r() * 0.3), rot + r());
        }
        if (age < 260) studioSoft(c, x, y, rx * 1.2, ry * 1.2, "#E86A5E", 0.5 * (1 - age / 260), rot);
      };
      const areas = (list, spots) => {
        const out = spots.map(() => ({ total: 0, age: 1e9, seed: 0 }));
        for (const w of list) {
          const a = out[Math.min(spots.length - 1, Math.floor(w.u * spots.length))];
          a.total += w.power;
          a.age = Math.min(a.age, w.age);
          a.seed = a.seed || w.v + 0.01;
        }
        return out;
      };
      const hip = P(s.hip),
        neck = P(s.neck);
      const size =
        (0.072 + muscle * 0.024 + fat * 0.028) * scale * (fem ? 0.86 : 1);
      const tube = (points, radii, fill) => {
        const path = new Path2D();
        const l = [],
          r = [];
        for (let i = 0; i < points.length; i++) {
          const before = points[Math.max(0, i - 1)],
            after = points[Math.min(points.length - 1, i + 1)],
            dx = after[0] - before[0],
            dy = after[1] - before[1],
            len = Math.hypot(dx, dy) || 1;
          l.push([
            points[i][0] - (dy / len) * radii[i],
            points[i][1] + (dx / len) * radii[i],
          ]);
          r.push([
            points[i][0] + (dy / len) * radii[i],
            points[i][1] - (dx / len) * radii[i],
          ]);
        }
        const outline = [...l, ...r.reverse()];
        const start = outline[outline.length - 1];
        path.moveTo(
          (start[0] + outline[0][0]) / 2,
          (start[1] + outline[0][1]) / 2,
        );
        for (let i = 0; i < outline.length; i++) {
          const current = outline[i],
            next = outline[(i + 1) % outline.length];
          path.quadraticCurveTo(
            ...current,
            (current[0] + next[0]) / 2,
            (current[1] + next[1]) / 2,
          );
        }
        path.closePath();
        const xs = points.map((p) => p[0]),
          minX = Math.min(...xs),
          maxX = Math.max(...xs);
        c.fillStyle =
          fill || skinGrad((minX + maxX) * 0.5, (maxX - minX) * 0.5 + size);
        c.fill(path);
        if (fill) return path;
        c.save();
        c.clip(path);
        const mid = points[1];
        studioSoft(
          c,
          mid[0] - size * 0.25,
          mid[1],
          size * 0.66,
          size * 1.5,
          lighten(skin, 0.26),
          0.32,
        );
        c.restore();
        return path;
      };
      const limb = (origin, limb, radii) => {
        const a = P(origin),
          j = P(limb.joint),
          e = P(limb.end);
        const lerp = (x, y, t) => x.map((v, i) => v + (y[i] - v) * t);
        const points = [a, lerp(a, j, 0.4), j, lerp(j, e, 0.36), e];
        const shape = tube(points, [
          radii[0],
          radii[0] * 1.09,
          radii[1],
          radii[1] * 1.12,
          radii[2],
        ]);
        c.save();
        c.clip(shape);
        // Broad anatomical planes follow the actual bones, including bent elbows/knees.
        const v = [j[0] - a[0], j[1] - a[1]],
          length = Math.hypot(...v);
        studioSoft(
          c,
          a[0] + v[0] * 0.43 - size * 0.16,
          a[1] + v[1] * 0.43,
          radii[0] * 0.49,
          length * 0.35,
          lighten(skin, 0.3),
          0.28,
          Math.atan2(v[1], v[0]) - Math.PI / 2,
        );
        const v2 = [e[0] - j[0], e[1] - j[1]],
          l2 = Math.hypot(...v2);
        studioSoft(
          c,
          j[0] + v2[0] * 0.4 - size * 0.14,
          j[1] + v2[1] * 0.4,
          radii[1] * 0.5,
          l2 * 0.35,
          lighten(skin, 0.3),
          0.27,
          Math.atan2(v2[1], v2[0]) - Math.PI / 2,
        );
        c.restore();
        return points;
      };
      const foot = (limb, i) => {
        const a = P(limb.end);
        c.save();
        c.translate(...a);
        const direction = p.facing || 1;
        if (limb.end[1] > 0.19)
          c.rotate(
            -Math.atan2(
              limb.end[1] - limb.joint[1],
              limb.end[0] - limb.joint[0],
            ) + (direction > 0 ? 0 : Math.PI),
          );
        c.fillStyle = skinGrad(0, size);
        c.beginPath();
        c.ellipse(
          direction * size * 0.57,
          0,
          size * 0.97,
          size * 0.32,
          0,
          0,
          Math.PI * 2,
        );
        c.fill();
        for (let k = 0; k < 5; k++) {
          c.beginPath();
          c.ellipse(
            direction * (size * 1.18 + k * size * 0.05),
            size * (-0.19 + k * 0.095),
            size * (0.15 - k * 0.018),
            size * 0.065,
            0,
            0,
            Math.PI * 2,
          );
          c.fill();
        }
        c.restore();
      };
      limb(s.hips[0], s.legs[0], [size * 1.26 * legK, size * 0.74 * legK, size * 0.43]);
      foot(s.legs[0], 0);
      limb(s.shoulders[0], s.arms[0], [size * 0.72 * armK, size * 0.47 * armK, size * 0.33]);
      limb(s.hips[1], s.legs[1], [size * 1.28 * legK, size * 0.76 * legK, size * 0.43]);
      foot(s.legs[1], 1);
      // Kicks land on the lead leg: thigh welts, and calf kicks lower down.
      if (fd?.leg.length) {
        const a = P(s.hips[1]),
          b = P(s.legs[1].joint),
          e = P(s.legs[1].end);
        areas(fd.leg, [[a, b, 0.6], [a, b, 0.78], [b, e, 0.35]]).forEach((ar, i) => {
          const [from, to, t] = [[a, b, 0.6], [a, b, 0.8], [b, e, 0.35]][i];
          if (ar.total > 0 || ar.age < 260)
            patch(from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t, size * 0.6, size * 0.95, ar.total, ar.age, ar.seed, Math.atan2(to[1] - from[1], to[0] - from[0]) - Math.PI / 2);
        });
      }
      // Each cloth leg follows the solved hip/knee segment, including kicks and ground poses.
      const shortsColor = SHORTS[f.kit?.shorts]?.[0] || corner;
      for (let i = 0; i < 2; i++) {
        const a = P(s.hips[i]),
          b = P(s.legs[i].joint),
          v = [b[0] - a[0], b[1] - a[1]],
          length = Math.hypot(...v) || 1;
        const point = (t) => [a[0] + v[0] * t, a[1] + v[1] * t];
        const hem = point(fem ? 0.38 : 0.43),
          middle = point(0.19),
          radius = size * 1.28;
        const shape = tube(
          [a, middle, hem],
          [radius * 1.07, radius, radius * 0.94],
          studioGradient(c, shortsColor, middle[0], middle[1], radius),
        );
        c.save();
        c.clip(shape);
        studioSoft(
          c,
          middle[0] - size * 0.25,
          middle[1],
          radius * 0.55,
          length * 0.23,
          lighten(shortsColor, 0.4),
          0.35,
          Math.atan2(v[1], v[0]) - Math.PI / 2,
        );
        c.restore();
        const normal = [-v[1] / length, v[0] / length];
        this.line(
          [
            hem[0] - normal[0] * radius * 0.82,
            hem[1] - normal[1] * radius * 0.82,
          ],
          [
            hem[0] + normal[0] * radius * 0.82,
            hem[1] + normal[1] * radius * 0.82,
          ],
          lighten(shortsColor, 0.28),
          scale * 0.008,
        );
      }
      // Continuous torso from hips through shoulders and the neck.
      const angle = (p.lean * Math.PI) / 180;
      c.save();
      c.translate(...hip);
      c.rotate(angle);
      // Heavy breathing when the tank empties.
      c.scale(1 + Math.sin((fd?.time || 0) * 0.005) * 0.018 * Math.max(0, (fd?.sweat || 0) - 0.35), s.h);
      const shoulder =
          (fem ? 0.151 : 0.195) * scale +
          (body.shoulders ?? 0.5) * scale * 0.025,
        waist =
          (fem ? 0.106 : 0.145) * scale +
          fat * scale * 0.05 +
          ((body.waist ?? (fem ? 0.4 : 0.5)) - 0.5) * scale * 0.03,
        gut = waist + belly * scale * 0.06,
        hips =
          (fem ? 0.191 : 0.155) * scale + (body.hips ?? 0.5) * scale * 0.035;
      c.fillStyle = studioGradient(c, skin, 0, -0.3 * scale, shoulder);
      c.beginPath();
      c.moveTo(-hips, 0.04 * scale);
      c.bezierCurveTo(
        -gut,
        -0.16 * scale,
        -waist,
        -0.3 * scale,
        -shoulder,
        -0.43 * scale,
      );
      c.quadraticCurveTo(
        -shoulder * 0.84,
        -0.54 * scale,
        -0.07 * scale,
        -0.5 * scale,
      );
      c.lineTo(-0.06 * neckK * scale, -0.57 * scale);
      c.lineTo(0.06 * neckK * scale, -0.57 * scale);
      c.lineTo(0.07 * scale, -0.5 * scale);
      c.quadraticCurveTo(
        shoulder * 0.84,
        -0.54 * scale,
        shoulder,
        -0.43 * scale,
      );
      c.bezierCurveTo(
        waist,
        -0.3 * scale,
        gut,
        -0.16 * scale,
        hips,
        0.04 * scale,
      );
      c.closePath();
      c.fill();
      c.save();
      c.clip();
      studioTorso(
        c,
        scale * 0.175,
        0,
        -scale * 0.76,
        skin,
        shoulder / (scale * 0.175),
        waist / (scale * 0.175),
        fat,
        muscle,
        fem,
        f.seed || 17,
      );
      // Local bruising follows the torso: ribs, liver and solar plexus, one mark per hit.
      if (fd?.body.length)
        // Liver/ribs on the open side, solar plexus, and the far ribs.
        areas(fd.body, [[0.45, 0.2], [0.05, 0.3], [-0.4, 0.24]]).forEach((ar, i) => {
          const [x, y] = [[0.45, 0.2], [0.05, 0.3], [-0.4, 0.24]][i];
          if (ar.total > 0 || ar.age < 260)
            patch((p.facing || 1) * shoulder * x, -scale * y, scale * 0.065, scale * 0.05, ar.total, ar.age, ar.seed, x * 0.6);
        });
      const sweat = Math.max(0, (fd?.sweat || 0) - 0.3) / 0.7;
      if (sweat > 0.02) {
        studioSoft(c, 0, -scale * 0.42, shoulder * 0.8, scale * 0.1, "#C25A55", sweat * 0.14);
        const r = rngOf((f.seed || 17) * 31 + 5);
        for (let k = 0; k < 9; k++)
          studioSoft(c, (r() - 0.5) * shoulder * 1.4, -scale * (0.1 + r() * 0.42), scale * 0.006, scale * (0.012 + r() * 0.014), "#FFFFFF", sweat * 0.28);
      }
      // Blood from facial cuts drips onto chest and shoulders.
      if ((fd?.cut || 0) > 0.04) {
        const r = rngOf((f.seed || 17) * 53 + 11),
          n = Math.min(16, Math.floor(fd.cut * 60));
        for (let k = 0; k < n; k++) {
          const x = (r() - 0.5) * shoulder * 1.1,
            y = -scale * (0.3 + r() * 0.22);
          studioSoft(c, x, y, scale * (0.006 + r() * 0.008), scale * (0.008 + r() * 0.016), "#6E0C12", 0.75);
        }
        if (fd.cut > 0.12) studioSoft(c, shoulder * 0.15, -scale * 0.4, scale * 0.02, scale * 0.12, "#7A1117", 0.45);
      }
      c.restore();
      if (fem) {
        const kitColor = SHORTS[f.kit?.shorts]?.[0] || corner;
        c.fillStyle = studioGradient(c, kitColor, 0, 0, shoulder);
        c.beginPath();
        c.moveTo(-shoulder * 0.88, -0.43 * scale);
        c.quadraticCurveTo(0, -0.385 * scale, shoulder * 0.88, -0.43 * scale);
        c.lineTo(waist * 1.03, -0.29 * scale);
        c.quadraticCurveTo(0, -0.25 * scale, -waist * 1.03, -0.29 * scale);
        c.closePath();
        c.fill();
        for (const side of [-1, 1])
          studioSoft(
            c,
            side * scale * 0.068,
            -scale * 0.364,
            scale * 0.062,
            scale * 0.052,
            lighten(kitColor, 0.35),
            0.3,
          );
        this.line(
          [-waist * 0.97, -scale * 0.282],
          [waist * 0.97, -scale * 0.282],
          darken(kitColor, 0.4),
          scale * 0.024,
        );
        for (const x of [-1, 1])
          this.line(
            [x * 0.11 * scale, -0.49 * scale],
            [x * 0.12 * scale, -0.39 * scale],
            kitColor,
            scale * 0.026,
          );
      }
      const kit = shortsColor;
      c.fillStyle = studioGradient(c, kit, 0, 0, hips);
      c.beginPath();
      c.moveTo(-hips, -scale * 0.038);
      c.lineTo(hips, -scale * 0.038);
      c.quadraticCurveTo(hips * 1.04, scale * 0.04, hips * 0.75, scale * 0.09);
      c.quadraticCurveTo(0, scale * 0.13, -hips * 0.75, scale * 0.09);
      c.quadraticCurveTo(-hips * 1.04, scale * 0.04, -hips, -scale * 0.038);
      c.fill();
      this.line(
        [-hips, -scale * 0.023],
        [hips, -scale * 0.023],
        lighten(kit, 0.35),
        scale * 0.028,
      );
      this.line([0, 0], [0, scale * 0.055], darken(kit, 0.4), scale * 0.008);
      c.restore();
      limb(s.shoulders[1], s.arms[1], [size * 0.74 * armK, size * 0.49 * armK, size * 0.33]);
      // Checked kicks leave the blocking forearm red.
      if (fd?.arm.length) {
        const j = P(s.arms[1].joint),
          e = P(s.arms[1].end),
          [ar] = areas(fd.arm, [0]);
        patch(j[0] + (e[0] - j[0]) * 0.5, j[1] + (e[1] - j[1]) * 0.5, size * 0.35, size * 0.55, ar.total * 0.6, ar.age, ar.seed, Math.atan2(e[1] - j[1], e[0] - j[0]) - Math.PI / 2);
      }
      for (const arm of s.arms) {
        const hand = P(arm.end);
        c.save();
        c.translate(...hand);
        c.rotate(
          Math.atan2(arm.end[1] - arm.joint[1], arm.end[0] - arm.joint[0]) * -1,
        );
        c.fillStyle = studioGradient(c, "#23282D", 0, 0, size * 0.8);
        c.beginPath();
        c.ellipse(0, 0, size * 0.59, size * 0.47, 0, 0, Math.PI * 2);
        c.fill();
        c.fillStyle = corner;
        c.fillRect(-size * 0.48, -size * 0.42, size * 0.19, size * 0.84);
        c.fillStyle = skin;
        for (let k = 0; k < 4; k++) {
          c.beginPath();
          c.ellipse(
            size * 0.43,
            -size * 0.26 + k * size * 0.17,
            size * 0.18,
            size * 0.085,
            0,
            0,
            Math.PI * 2,
          );
          c.fill();
        }
        if ((fd?.glove || 0) > 0.05) studioSoft(c, size * 0.3, 0, size * 0.28, size * 0.42, "#6E0C12", fd.glove);
        c.restore();
      }
      const head = P(s.head);
      c.save();
      c.translate(...head);
      c.rotate(((p.lean + p.head) * Math.PI) / 180);
      const sprite = this.damagedHead(f, fd),
        headW = scale * 0.32,
        headH = scale * 0.4;
      c.drawImage(sprite, -headW / 2, -headH * 0.54, headW, headH);
      c.restore();
      // Sweat (and blood, once cut) sprays off the head on a clean shot.
      if (fd?.spray) {
        const sp = fd.spray,
          k = sp.age / 420,
          r = rngOf(Math.floor(sp.seed * 1e6) + 3),
          n = Math.min(26, 6 + Math.floor(sp.power * 500)),
          dir = -(p.facing || 1);
        for (let i = 0; i < n; i++) {
          const spd = scale * (0.12 + r() * 0.3) * (0.6 + sp.power * 12),
            ang = (r() - 0.6) * 1.3,
            x = head[0] + dir * Math.cos(ang) * spd * k,
            y = head[1] - Math.sin(ang) * spd * k + scale * 0.25 * k * k;
          c.fillStyle = sp.bloody && r() < 0.55 ? rgba("#7A0D13", 0.9 * (1 - k)) : `rgba(226,236,242,${0.75 * (1 - k)})`;
          c.beginPath();
          c.arc(x, y, Math.max(0.8, scale * (0.003 + r() * 0.004)), 0, Math.PI * 2);
          c.fill();
        }
      }
      if (this.showRig) {
        for (const [origin, limb] of [
          ...s.arms.map((x, i) => [s.shoulders[i], x]),
          ...s.legs.map((x, i) => [s.hips[i], x]),
        ]) {
          this.line(P(origin), P(limb.joint), "#E4D7A1", 1.5);
          this.line(P(limb.joint), P(limb.end), "#E4D7A1", 1.5);
        }
        this.line(hip, neck, "#E4D7A1", 1.5);
      }
    }
    referee(t, id, offset) {
      if (this.hideReferee) return;
      const c = this.ctx,
        p = this.project(offset - 1.7, 0.02, 0.7),
        s = this.S,
        stop = id === "referee_stop";
      // Same identity library as the athletes; one stable official per renderer.
      if (!this.refFace && typeof genFace === "function") this.refFace = genFace(90210, "misto", "m");
      const skin = "#b88a68", shirt = "#15191d", trousers = "#2b3036", glove = "#3f73b3";
      c.save();
      c.translate(...p);
      // trousers and shoes
      for (const side of [-1, 1]) {
        this.line([side * 0.08 * s, -0.94 * s], [side * 0.13 * s, -0.05 * s], trousers, 0.15 * s);
        c.fillStyle = "#0b0d0f";
        c.beginPath();
        c.ellipse(side * 0.15 * s, -0.03 * s, 0.1 * s, 0.045 * s, 0, 0, Math.PI * 2);
        c.fill();
      }
      // shirt with soft left key light, collar and belt
      const g = c.createLinearGradient(-0.22 * s, 0, 0.22 * s, 0);
      g.addColorStop(0, "#2a3138");
      g.addColorStop(0.5, shirt);
      g.addColorStop(1, "#07090b");
      c.fillStyle = g;
      c.beginPath();
      c.moveTo(-0.23 * s, -1.46 * s);
      c.quadraticCurveTo(0, -1.53 * s, 0.23 * s, -1.46 * s);
      c.quadraticCurveTo(0.21 * s, -1.2 * s, 0.17 * s, -0.92 * s);
      c.lineTo(-0.17 * s, -0.92 * s);
      c.quadraticCurveTo(-0.21 * s, -1.2 * s, -0.23 * s, -1.46 * s);
      c.fill();
      this.line([-0.17 * s, -0.93 * s], [0.17 * s, -0.93 * s], "#0b0d0f", 0.04 * s);
      this.line([-0.06 * s, -1.5 * s], [0, -1.42 * s], "#3a434c", 0.02 * s);
      this.line([0.06 * s, -1.5 * s], [0, -1.42 * s], "#3a434c", 0.02 * s);
      // arms: short black sleeves, skin forearms, blue exam gloves
      for (const side of [-1, 1]) {
        const shoulder = [side * 0.22 * s, -1.42 * s];
        const elbow = stop && side === 1
          ? [side * 0.46 * s, -1.34 * s]
          : [side * 0.27 * s, -1.12 * s];
        const hand = stop && side === 1
          ? [side * (0.7 + t * 0.14) * s, -1.3 * s]
          : [side * (0.3 + t * 0.08) * s, -0.86 * s];
        this.line(shoulder, elbow, skin, 0.085 * s);
        this.line(shoulder, [(shoulder[0] + elbow[0]) / 2, (shoulder[1] + elbow[1]) / 2], shirt, 0.11 * s);
        this.line(elbow, hand, skin, 0.075 * s);
        c.fillStyle = glove;
        c.beginPath();
        c.ellipse(hand[0], hand[1], 0.055 * s, 0.06 * s, 0, 0, Math.PI * 2);
        c.fill();
      }
      // neck and face
      this.line([0, -1.46 * s], [0, -1.55 * s], skin, 0.1 * s);
      if (this.refFace) {
        const sprite = this.head(this.refFace), headW = s * 0.32, headH = s * 0.4;
        c.drawImage(sprite, -headW / 2, -1.66 * s - headH * 0.54, headW, headH);
      }
      c.restore();
    }
  }
  root.FightRenderer = FightRenderer;
})(window);
