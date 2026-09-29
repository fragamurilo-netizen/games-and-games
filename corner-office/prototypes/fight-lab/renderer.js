/* Canvas presentation only. Game Bible §§5,15–17. Shared faces from face-lab.
 * Arena identity lives in content/arena_profiles.json; no organization literals.
 */
(function (root) {
  "use strict";
  class FightRenderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.heads = new Map();
      this.camera = "broadcast";
      this.showRig = false;
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
        );
      this.arena(arena, true);
      if (frame.clip.category === "official")
        this.referee(frame.progress, frame.event.technique_id, offset);
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
    fighter(p, f, corner, offset, damage, cuts = 0) {
      const c = this.ctx,
        s = FightReplay.skeleton(p, f),
        scale = this.S,
        body = f.body || {},
        muscle = body.muscle ?? 0.65,
        fat = body.fat ?? 0.14,
        fem = f.sex === "f",
        skin = SKIN[f.skin]?.[0] || "#B7805D",
        P = (v) => this.project(v[0] + offset, v[1]),
        skinGrad = (x, r) => studioGradient(c, skin, x, 0, r);
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
      limb(s.hips[0], s.legs[0], [size * 1.26, size * 0.74, size * 0.43]);
      foot(s.legs[0], 0);
      limb(s.shoulders[0], s.arms[0], [size * 0.72, size * 0.47, size * 0.33]);
      limb(s.hips[1], s.legs[1], [size * 1.28, size * 0.76, size * 0.43]);
      foot(s.legs[1], 1);
      if ((damage?.leg || 0) > 0.12) {
        const a = P(s.hips[1]),
          b = P(s.legs[1].joint);
        studioSoft(
          c,
          a[0] * 0.4 + b[0] * 0.6,
          a[1] * 0.4 + b[1] * 0.6,
          size * 0.7,
          size * 1.0,
          "#794E58",
          Math.min(0.4, damage.leg * 0.5),
        );
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
      c.scale(1, s.h);
      const shoulder =
          (fem ? 0.151 : 0.195) * scale +
          (body.shoulders ?? 0.5) * scale * 0.025,
        waist = (fem ? 0.106 : 0.145) * scale + fat * scale * 0.05,
        hips =
          (fem ? 0.191 : 0.155) * scale + (body.hips ?? 0.5) * scale * 0.035;
      c.fillStyle = studioGradient(c, skin, 0, -0.3 * scale, shoulder);
      c.beginPath();
      c.moveTo(-hips, 0.04 * scale);
      c.bezierCurveTo(
        -waist,
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
      c.lineTo(-0.06 * scale, -0.57 * scale);
      c.lineTo(0.06 * scale, -0.57 * scale);
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
        waist,
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
      // Local bruising follows the torso instead of floating in screen coordinates.
      if ((damage?.body || 0) > 0.12) {
        studioSoft(
          c,
          scale * 0.065,
          -scale * 0.21,
          scale * 0.078,
          scale * 0.055,
          "#813F48",
          Math.min(0.4, damage.body * 0.5),
          -0.3,
        );
        studioSoft(
          c,
          -scale * 0.09,
          -scale * 0.35,
          scale * 0.055,
          scale * 0.038,
          "#946D61",
          Math.min(0.33, damage.body * 0.45),
          0.3,
        );
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
      limb(s.shoulders[1], s.arms[1], [size * 0.74, size * 0.49, size * 0.33]);
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
        c.restore();
      }
      const head = P(s.head);
      c.save();
      c.translate(...head);
      c.rotate(((p.lean + p.head) * Math.PI) / 180);
      const sprite = this.head(f),
        headW = scale * 0.32,
        headH = scale * 0.4;
      c.drawImage(sprite, -headW / 2, -headH * 0.54, headW, headH);
      if ((damage?.head || 0) > 0.35) {
        c.fillStyle = "rgba(117,42,45,.26)";
        c.beginPath();
        c.ellipse(
          headW * 0.17,
          headH * 0.02,
          headW * 0.1,
          headW * 0.08,
          0,
          0,
          Math.PI * 2,
        );
        c.fill();
      }
      if (cuts > 0.04) {
        this.line(
          [-headW * 0.17, -headH * 0.08],
          [-headW * 0.02, -headH * 0.11],
          "#7E2C30",
          Math.max(1, scale * 0.006),
          Math.min(0.85, 0.3 + cuts),
        );
      }
      c.restore();
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
      const c = this.ctx,
        p = this.project(offset - 1.7, 0.02, 0.7),
        s = this.S;
      c.save();
      c.translate(...p);
      c.fillStyle = "#10171D";
      c.fillRect(-0.13 * s, -1.2 * s, 0.26 * s, 0.64 * s);
      this.line([-0.08 * s, -0.6 * s], [-0.19 * s, 0], "#161D23", 0.12 * s);
      this.line([0.08 * s, -0.6 * s], [0.2 * s, 0], "#161D23", 0.12 * s);
      c.fillStyle = "#AA886C";
      c.beginPath();
      c.ellipse(0, -1.36 * s, 0.105 * s, 0.14 * s, 0, 0, Math.PI * 2);
      c.fill();
      for (const side of [-1, 1])
        this.line(
          [side * 0.13 * s, -1.13 * s],
          [
            side * (0.24 + t * 0.16) * s,
            -s * (id === "referee_stop" ? 1.05 : 0.74),
          ],
          "#172128",
          0.09 * s,
        );
      c.restore();
    }
  }
  root.FightRenderer = FightRenderer;
})(window);
