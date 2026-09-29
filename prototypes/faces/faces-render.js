// PARALELO — protótipo de rostos procedurais.
// Parte 2: renderização em Canvas 2D.
//   mode "real":   pele com mapa de relevo + iluminação por pixel (análogo aos shaders do Skia),
//                  cabelo e barba por milhares de fios, rugas como relevo.
//   mode "vector": mesma geometria em formas chapadas com gradientes (opção 1).
;(function (root) {
  "use strict"
  const C = root.FaceCore
  const { clamp, lerp, smooth, makeRng, hash32 } = C
  const W = 400
  const H = 500

  // ---------- ruído ----------
  function hashXY(x, y, s) {
    let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0
    h = Math.imul(h ^ (h >>> 13), 1274126177)
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296
  }
  function vnoise(x, y, s) {
    const xi = Math.floor(x), yi = Math.floor(y)
    const xf = x - xi, yf = y - yi
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
    const a = hashXY(xi, yi, s), b = hashXY(xi + 1, yi, s), c = hashXY(xi, yi + 1, s), d = hashXY(xi + 1, yi + 1, s)
    return lerp(lerp(a, b, u), lerp(c, d, u), v)
  }
  function fbm(x, y, s, oct = 3) {
    let t = 0, amp = 0.5, f = 1
    for (let i = 0; i < oct; i++) {
      t += amp * vnoise(x * f, y * f, s + i * 17)
      f *= 2.03
      amp *= 0.5
    }
    return t
  }

  // ---------- mapas float ----------
  function boxBlur(src, w, h, r) {
    if (r < 1) return src.slice()
    const tmp = new Float32Array(w * h)
    const out = new Float32Array(w * h)
    const k = 1 / (2 * r + 1)
    for (let y = 0; y < h; y++) {
      let acc = 0
      const row = y * w
      for (let x = -r; x <= r; x++) acc += src[row + clamp(x, 0, w - 1)]
      for (let x = 0; x < w; x++) {
        tmp[row + x] = acc * k
        acc += src[row + Math.min(x + r + 1, w - 1)] - src[row + Math.max(x - r, 0)]
      }
    }
    for (let x = 0; x < w; x++) {
      let acc = 0
      for (let y = -r; y <= r; y++) acc += tmp[clamp(y, 0, h - 1) * w + x]
      for (let y = 0; y < h; y++) {
        out[y * w + x] = acc * k
        acc += tmp[Math.min(y + r + 1, h - 1) * w + x] - tmp[Math.max(y - r, 0) * w + x]
      }
    }
    return out
  }
  const blur3 = (s, w, h, r) => boxBlur(boxBlur(boxBlur(s, w, h, r), w, h, r), w, h, r)

  function makeCanvas(w, h) {
    if (typeof OffscreenCanvas !== "undefined") return new OffscreenCanvas(w, h)
    const c = document.createElement("canvas")
    c.width = w
    c.height = h
    return c
  }

  // Carimbo gaussiano elíptico num mapa (coordenadas em unidades de 400x500).
  function stamp(map, w, h, res, x, y, rx, ry, amp, rot = 0) {
    const X = x * res, Y = y * res, RX = Math.max(rx * res, 0.5), RY = Math.max(ry * res, 0.5)
    const R = Math.max(RX, RY) * 2.2
    const x0 = Math.max(0, Math.floor(X - R)), x1 = Math.min(w - 1, Math.ceil(X + R))
    const y0 = Math.max(0, Math.floor(Y - R)), y1 = Math.min(h - 1, Math.ceil(Y + R))
    const cs = Math.cos(rot), sn = Math.sin(rot)
    for (let py = y0; py <= y1; py++) {
      for (let px = x0; px <= x1; px++) {
        const dx = px - X, dy = py - Y
        const u = (dx * cs + dy * sn) / RX
        const v = (-dx * sn + dy * cs) / RY
        const d = u * u + v * v
        if (d < 4.5) map[py * w + px] += amp * Math.exp(-d * 1.5)
      }
    }
  }
  // Linha (vinco/ruga) como série de carimbos.
  function stampLine(map, w, h, res, pts, width, amp) {
    for (let i = 0; i < pts.length - 1; i++) {
      const [ax, ay] = pts[i], [bx, by] = pts[i + 1]
      const len = Math.hypot(bx - ax, by - ay)
      const n = Math.max(1, Math.ceil(len / (width * 0.6)))
      const t0 = i / (pts.length - 1)
      for (let k = 0; k < n; k++) {
        const t = k / n
        const g = t0 + t / (pts.length - 1)
        const taper = Math.sin(Math.PI * clamp(g, 0.02, 0.98))
        stamp(map, w, h, res, lerp(ax, bx, t), lerp(ay, by, t), width, width, amp * taper)
      }
    }
  }

  const rgb = (c, a = 1) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`
  const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]
  const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k]

  function pathFrom(pts, closed = true) {
    const p = new Path2D()
    pts.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)))
    if (closed) p.closePath()
    return p
  }

  function hslToRgb(h, s, l) {
    const f = (n) => {
      const k = (n + h * 12) % 12
      const a = s * Math.min(l, 1 - l)
      return 255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))
    }
    return [f(0), f(8), f(4)]
  }

  // =====================================================================
  function render(canvas, g, opts = {}) {
    const age = opts.age ?? 30
    const mode = opts.mode || "real"
    const res = opts.res || 1
    const pw = W * res, ph = H * res
    canvas.width = pw
    canvas.height = ph
    const ctx = canvas.getContext("2d")
    ctx.setTransform(res, 0, 0, res, 0, 0)

    const fat = C.bodyFatAt(g, age, opts.fat)
    const L = C.layout(g, { age, fat })
    const P = C.phenotype(g, age)
    const r = makeRng(hash32(g.id + ":render"))
    const hairStyle = C.hairForAge(g, age, opts.hair)
    const beardStyle = g.sex === "M" || opts.beard ? C.BEARD_BY_ID[opts.beard || g.pref.beard] : C.BEARD_BY_ID.nenhuma
    const glasses = opts.glasses !== undefined ? opts.glasses : age > 7 ? g.pref.glasses : null
    const makeup = age >= 15 ? (opts.makeup ?? g.pref.makeup) : 0

    // cores
    let skin = C.skinRGB(P.mel, g.skin.under)
    skin = mix(skin, [skin[0] * 0.97, skin[1] * 0.95, skin[2] * 0.95], L.old * 0.5) // pele idosa um pouco mais opaca
    if (L.baby > 0.5) skin = mix(skin, [skin[0] * 1.02, skin[1] * 0.97, skin[2] * 0.97], (L.baby - 0.5) * 0.6)
    const hairBase = C.hairRGB(P.hairEu, P.hairPheo)
    const greyFrac = smooth(g.hair.greyOnset, g.hair.greyOnset + 32, age)
    const beardGreyFrac = smooth(g.hair.greyOnset - 6, g.hair.greyOnset + 24, age)
    const eyeCol = C.eyeRGB(P.eyeDark, P.eyeGreen)
    const bald = g.sex === "M" ? g.hair.bald * smooth(g.hair.baldOnset, g.hair.baldOnset + 28, age) : g.hair.bald * smooth(55, 90, age) * 0.6

    // ---------- fundo ----------
    if (opts.bg !== false) {
      const bg = ctx.createRadialGradient(170, 170, 40, 200, 250, 360)
      bg.addColorStop(0, "#2a2e33")
      bg.addColorStop(1, "#16181b")
      ctx.fillStyle = bg
      ctx.fillRect(0, 0, W, H)
    }

    // ---------- formas base ----------
    const headPath = pathFrom(L.outline)
    const neckTopY = L.jawY - 4
    const nL = L.cx - L.neckW / 2, nR = L.cx + L.neckW / 2
    const chestY = L.shoulderY + 10
    const bodyPts = [
      [nL + 2, neckTopY], [nR - 2, neckTopY],
      [nR, L.shoulderY - (L.shoulderY - L.chinY) * 0.3],
      [nR + 6, L.shoulderY - 6],
      [L.cx + L.shoulderW * 0.46, L.shoulderY + 8],
      [L.cx + L.shoulderW * 0.56, chestY + 40],
      [L.cx + L.shoulderW * 0.6, H + 10],
      [L.cx - L.shoulderW * 0.6, H + 10],
      [L.cx - L.shoulderW * 0.56, chestY + 40],
      [L.cx - L.shoulderW * 0.46, L.shoulderY + 8],
      [nL - 6, L.shoulderY - 6],
      [nL, L.shoulderY - (L.shoulderY - L.chinY) * 0.3],
    ]
    const bodyPath = pathFrom(C.catmull(bodyPts, true, 6))

    const ears = [-1, 1].map((s) => {
      const top = L.browY + 2
      const bot = top + L.earH
      const mid = (top + bot) / 2
      const fx = L.cx + s * (C.faceHalfWidth(L, mid) - 3)
      const out = L.earW * (0.8 + L.earOut)
      const pts = [
        [fx, top + 4], [fx + s * out * 0.7, top - 1], [fx + s * out, top + L.earH * 0.22],
        [fx + s * out * 0.95, mid], [fx + s * out * 0.62, bot - L.earH * 0.12], [fx + s * out * 0.3, bot + 1], [fx - s * 2, bot - 4],
      ]
      return { s, pts: C.catmull(pts, true, 5), top, bot, fx, out, mid }
    })
    const earPaths = ears.map((e) => pathFrom(e.pts))

    // ---------- cabelo: máscaras ----------
    const hairGeo = buildHair(L, hairStyle, P, bald, age, r)

    // camada de cabelo de trás (antes do corpo)
    if (hairGeo.back) drawHairLayer(ctx, hairGeo.back, hairGeo, "back")

    // ---------- corpo/roupa (antes da pele do pescoço? a roupa cobre o peito) ----------
    // pele primeiro, roupa por cima
    if (mode === "real") {
      drawSkinReal(ctx, g, L, P, skin, headPath, earPaths, bodyPath, ears, res, age, makeup, beardStyle, hairBase, bald)
    } else {
      drawSkinVector(ctx, g, L, P, skin, headPath, earPaths, bodyPath, ears, age, makeup, beardStyle, hairBase)
    }
    drawClothes(ctx, g, L, age, mode)

    // ---------- traços ----------
    for (const s of [-1, 1]) drawEye(ctx, g, L, P, s, eyeCol, mode, makeup, age, r)
    drawNose(ctx, L, skin, mode)
    drawMouth(ctx, g, L, P, skin, mode, makeup, age)
    for (const s of [-1, 1]) drawBrow(ctx, g, L, s, mix(hairBase, [200, 200, 200], greyFrac * 0.7), age, r)

    // barba
    if (beardStyle && beardStyle.id !== "nenhuma" && age >= 13) {
      const beardCol = mix(hairBase, [150, 70, 30], g.hair.beardRed * 0.5)
      drawBeard(ctx, g, L, beardStyle, beardCol, beardGreyFrac, age, res, mode, r)
    }

    // cabelo da frente
    if (hairGeo.front) drawHairLayer(ctx, hairGeo.front, hairGeo, "front")
    if (hairGeo.extra) hairGeo.extra(ctx)

    if (glasses) drawGlasses(ctx, L, glasses, r)

    // ---------- helpers de cabelo que precisam de closure ----------
    function drawHairLayer(ctx2, maskFn, geo, layer) {
      const lay = makeCanvas(pw, ph)
      const lc = lay.getContext("2d")
      lc.setTransform(res, 0, 0, res, 0, 0)
      // máscara
      const mk = makeCanvas(pw, ph)
      const mc = mk.getContext("2d")
      mc.setTransform(res, 0, 0, res, 0, 0)
      mc.fillStyle = "#fff"
      maskFn(mc)
      const md = mc.getImageData(0, 0, pw, ph).data
      const alphaAt = (x, y) => {
        const X = (x * res) | 0, Y = (y * res) | 0
        if (X < 0 || Y < 0 || X >= pw || Y >= ph) return 0
        return md[(Y * pw + X) * 4 + 3] / 255
      }
      const cols = hairPalette(hairBase, greyFrac, geo)
      paintHair(lc, geo, layer, alphaAt, cols, mode, res, r)
      if (layer === "front") {
        const sh = makeCanvas(pw, ph)
        const sc = sh.getContext("2d")
        sc.drawImage(mk, 0, 0)
        sc.globalCompositeOperation = "source-in"
        sc.fillStyle = "#000"
        sc.fillRect(0, 0, pw, ph)
        ctx2.save()
        ctx2.setTransform(1, 0, 0, 1, 0, 0)
        ctx2.globalAlpha = mode === "real" ? 0.45 : 0.3
        ctx2.filter = `blur(${4 * res}px)`
        ctx2.drawImage(sh, 2 * res, 4 * res)
        ctx2.restore()
      }
      // recorta pela máscara com borda suave
      lc.setTransform(1, 0, 0, 1, 0, 0)
      lc.globalCompositeOperation = "destination-in"
      lc.filter = `blur(${(layer === "front" ? 1.1 : 0.7) * res}px)`
      lc.drawImage(mk, 0, 0)
      lc.filter = "none"
      lc.globalCompositeOperation = "source-over"
      ctx2.save()
      ctx2.setTransform(1, 0, 0, 1, 0, 0)
      ctx2.drawImage(lay, 0, 0)
      ctx2.restore()
      // fios soltos fora da silhueta
      if (mode === "real" && geo.flyaways && layer === "front") drawFlyaways(ctx2, geo, alphaAt, cols, r)
      if (mode === "real" && layer === "front" && !geo.horseshoe && geo.kind !== "shaved") drawBabyHairs(ctx2, geo, alphaAt, cols)
    }

    return { L, fat, hair: hairStyle.id, beard: beardStyle ? beardStyle.id : "nenhuma", height: C.heightCm(g, age) }
  }

  // =====================================================================
  // PELE — modo realista (relevo + iluminação por pixel)
  function drawSkinReal(ctx, g, L, P, skin, headPath, earPaths, bodyPath, ears, res, age, makeup, beardStyle, hairBase, bald) {
    const pw = W * res, ph = H * res
    const N = pw * ph
    const mk = makeCanvas(pw, ph)
    const mc = mk.getContext("2d")
    mc.setTransform(res, 0, 0, res, 0, 0)
    const readMask = (draw) => {
      mc.clearRect(0, 0, W, H)
      mc.fillStyle = "#fff"
      draw()
      const d = mc.getImageData(0, 0, pw, ph).data
      const m = new Float32Array(N)
      for (let i = 0; i < N; i++) m[i] = d[i * 4 + 3] / 255
      return m
    }
    const Mh = readMask(() => mc.fill(headPath))
    const Me = readMask(() => earPaths.forEach((p) => mc.fill(p)))
    const Mb = readMask(() => mc.fill(bodyPath))

    // relevo
    const bh1 = blur3(Mh, pw, ph, Math.round(11 * res))
    const bh2 = blur3(Mh, pw, ph, Math.round(3 * res))
    const bb = blur3(Mb, pw, ph, Math.round(9 * res))
    const be = blur3(Me, pw, ph, Math.round(2 * res))
    const Hm = new Float32Array(N)
    const domeCy = (L.browY + L.mouthY) / 2, domeRy = L.Ht * 0.62, domeRx = L.rx * 1.12
    for (let i = 0; i < N; i++) {
      const px = (i % pw) / res, py = ((i / pw) | 0) / res
      const dxn = (px - L.cx) / domeRx, dyn = (py - domeCy) / domeRy
      const dome = Math.sqrt(Math.max(0, 1 - dxn * dxn - dyn * dyn))
      const head = Math.sqrt(Math.max(0, bh1[i])) * 16 + bh2[i] * 5 + dome * 34
      const body = bb[i] * 16
      const ear = be[i] * 5 + 12
      Hm[i] = Math.max(head * Mh[i] + (1 - Mh[i]) * Math.max(body * Mb[i], ear * Me[i] * (1 - Mb[i] * 0)), 0)
      if (Mh[i] < 0.5 && Me[i] > 0.5) Hm[i] = ear
      if (Mh[i] < 0.98 && Mb[i] > 0.5 && py > L.chinY - 30) Hm[i] += 18 * clamp(1 - (py - L.chinY + 6) / 34) * (1 - Mh[i])
    }

    {
      // suaviza a costura queixo/pescoço
      const sm = blur3(Hm, pw, ph, Math.round(3 * res))
      const y0p = Math.floor((L.chinY - 14) * res), y1p = Math.ceil((L.chinY + 16) * res)
      for (let py = Math.max(0, y0p); py < Math.min(ph, y1p); py++) {
        const t = 1 - Math.abs(py / res - L.chinY) / 16
        for (let px = 0; px < pw; px++) {
          const i = py * pw + px
          if (Mb[i] > 0.5) Hm[i] = lerp(Hm[i], sm[i], clamp(t * 1.4))
        }
      }
    }
    const S = (x, y, rx, ry, amp, rot) => stamp(Hm, pw, ph, res, x, y, rx, ry, amp, rot)
    const SL = (pts, w, amp) => stampLine(Hm, pw, ph, res, pts, w, amp)
    const { cx, eyeY, browY, noseY, mouthY, chinY, eyeW, eyeOff, rx, old, gr, fat, thin, baby } = L
    const aged = old
    const z = g.z

    // testa e arcada
    S(cx, browY - (browY - L.y0) * 0.35, rx * 0.6, (browY - L.y0) * 0.35, 3 + baby * 3)
    for (const s of [-1, 1]) {
      S(cx + s * eyeOff * 0.9, browY - 2, eyeW * 0.85, eyeW * 0.32, (g.sex === "M" ? 3.8 : 2.2) * gr)
      // órbitas
      S(cx + s * eyeOff, eyeY - eyeW * 0.05, eyeW * 0.72, eyeW * 0.46, -(3.2 + thin * 1.5 + aged * 2.4) * lerp(0.5, 1, gr))
      // globo ocular
      S(cx + s * eyeOff, eyeY, eyeW * 0.46, eyeW * 0.3, 2.2)
      // maçãs do rosto
      S(cx + s * rx * 0.58, eyeY + eyeW * 0.85, rx * 0.32, rx * 0.2, 3 + 0.8 * z.cheekB + thin * 1.5 - baby * 1, -s * 0.3)
      // bochechas (gordura/bebê)
      S(cx + s * rx * 0.55, mouthY - eyeW * 0.3, rx * 0.3, rx * 0.28, fat * 5 + baby * 5)
      // cavidade da bochecha (magros/idosos)
      S(cx + s * rx * 0.62, mouthY - eyeW * 0.1, rx * 0.18, rx * 0.26, -(thin * 3 + aged * 2.5 * (1 - fat)))
      // têmporas fundas na velhice
      S(cx + s * rx * 0.88, browY - 6, rx * 0.12, rx * 0.2, -aged * 3 * (1 - fat))
    }
    // nariz
    const bridge = 1 + 0.25 * z.noseBridge
    const nb = []
    for (let i = 0; i <= 8; i++) {
      const t = i / 8
      nb.push([cx + L.asymNose * t + z.noseHook * 1.2 * Math.sin(t * Math.PI) * 0.4, lerp(browY + 4, noseY - L.noseLen * 0.12, t)])
    }
    for (let i = 0; i < nb.length; i++) {
      const t = i / (nb.length - 1)
      S(nb[i][0], nb[i][1], lerp(3.2, 4.2, t) * lerp(0.8, 1, gr), 5, (lerp(1.2, 3.5, t) * bridge + 0.9 * z.noseHook * Math.sin(t * Math.PI)) * lerp(0.4, 1, gr))
    }
    const tipX = cx + L.asymNose, tipY = noseY - L.noseLen * 0.1
    const tipR = L.noseW * 0.2 * (1 + 0.18 * z.noseTip) * (1 + aged * 0.12)
    S(tipX, tipY, tipR, tipR * 0.9, 5 * lerp(0.6, 1, gr))
    for (const s of [-1, 1]) {
      S(tipX + s * L.noseW * 0.34, noseY - L.noseLen * 0.07, L.noseW * 0.16, L.noseW * 0.13, 3.2)
      S(tipX + s * L.noseW * 0.2, noseY - 0.5, L.noseW * 0.08, L.noseW * 0.045, -3.5)
      // sulco da asa
      SL([[tipX + s * L.noseW * 0.48, noseY - L.noseLen * 0.18], [tipX + s * L.noseW * 0.52, noseY - L.noseLen * 0.06], [tipX + s * L.noseW * 0.4, noseY]], 1.3, -1.4)
    }
    // boca
    S(cx, mouthY - 2, L.mouthW * 0.62, L.mouthW * 0.34, 3)
    S(cx + L.asymMouth * 0.3, mouthY - L.lipU * 0.45, L.mouthW * 0.36, L.lipU * 0.5, 1.8)
    S(cx + L.asymMouth * 0.3, mouthY + L.lipL * 0.55, L.mouthW * 0.33, L.lipL * 0.55, 2.4)
    S(cx, mouthY + L.lipL * 1.35, L.mouthW * 0.28, 2.2, -1.6 - aged) // sulco mentolabial
    // filtro labial
    for (const s of [-1, 1]) SL([[cx + s * 3.5, noseY + 2], [cx + s * 4.2, mouthY - L.lipU * 0.9]], 1.4, 0.9)
    // queixo
    S(cx, chinY - (chinY - mouthY) * 0.32, L.chinW * 0.7, (chinY - mouthY) * 0.25, 3 + 0.6 * z.chinL)
    // pescoço: tendões e dobras
    for (const s of [-1, 1]) {
      SL([[cx + s * L.neckW * 0.18, L.chinY + 8], [cx + s * L.neckW * 0.3, L.shoulderY - 4]], 3.5, (thin * 1 + aged * 1.1) * gr)
    }
    // pomo de adão
    if (g.sex === "M" && age > 13) S(cx, L.chinY + (L.shoulderY - L.chinY) * 0.38, 4, 6, 1.6 * (1 - fat))
    // papada
    if (fat > 0.45 || L.jowl > 0.3) {
      const dc = clamp((fat - 0.45) * 2.2 + L.jowl * 0.8)
      S(cx, chinY + 7, L.chinW * 1.3, 7, 5 * dc)
      SL([[cx - L.chinW * 1.2, chinY + 3], [cx, chinY + 11 * dc + 3], [cx + L.chinW * 1.2, chinY + 3]], 1.6, -2.5 * dc)
    }

    // ---------- envelhecimento (rugas como relevo) ----------
    const wr = makeRng(hash32(g.id + ":wr"))
    const ageLines = smooth(28, 80, age) * g.skin.aging
    if (ageLines > 0.02) {
      const fh = browY - L.hairlineY
      const n = 3 + Math.floor(wr() * 2)
      for (let i = 0; i < n; i++) {
        const y = browY - fh * (0.3 + i * 0.16) + wr.normal() * 1.2
        const w0 = rx * (0.5 + wr() * 0.18)
        const pts = []
        for (let k = 0; k <= 6; k++) {
          const t = k / 6
          pts.push([cx - w0 + t * w0 * 2, y + Math.sin(t * Math.PI) * -2.5 + wr.normal() * 0.5])
        }
        SL(pts, 1.3, -1.0 * ageLines * (1 - i * 0.15))
      }
      // glabela
      const gl = smooth(35, 75, age)
      for (const s of [-1, 1]) SL([[cx + s * 4, browY - 10], [cx + s * 5, browY + 3]], 1.2, -0.9 * gl)
      // pés de galinha
      const cf = smooth(33, 72, age) * g.skin.aging
      for (const s of [-1, 1]) {
        const ox = cx + s * (eyeOff + eyeW * 0.6), oy = eyeY
        for (let k = -1; k <= 1; k++) SL([[ox, oy + k * 3], [ox + s * eyeW * 0.4, oy + k * 6 - 2]], 1, -0.8 * cf)
      }
      // bolsas e olheiras
      const bag = smooth(38, 85, age)
      for (const s of [-1, 1]) {
        S(cx + s * eyeOff, eyeY + eyeW * 0.42, eyeW * 0.45, eyeW * 0.12, 1.1 * bag)
        SL([[cx + s * (eyeOff - eyeW * 0.4), eyeY + eyeW * 0.35], [cx + s * eyeOff, eyeY + eyeW * 0.62], [cx + s * (eyeOff + eyeW * 0.45), eyeY + eyeW * 0.45]], 1.3, -1.1 * bag)
      }
    }
    // sulcos nasolabiais (também aparecem em jovens, mais leves)
    const nl = clamp(0.25 + smooth(25, 75, age) * 0.9 + fat * 0.3) * gr
    for (const s of [-1, 1]) {
      SL([[cx + s * L.noseW * 0.55, noseY - L.noseLen * 0.12], [cx + s * L.mouthW * 0.55, mouthY - 4], [cx + s * L.mouthW * 0.62, mouthY + 6 + old * 6]], 2.4 - old, -1.7 * nl)
      S(cx + s * L.mouthW * 0.72, mouthY - 6, 7, 10, 1.6 * nl)
      // linhas de marionete e bochechas caídas
      if (L.old > 0.15) {
        SL([[cx + s * L.mouthW * 0.52, mouthY + 3], [cx + s * L.mouthW * 0.56, mouthY + 16 + L.old * 6]], 1.5, -1.3 * L.old)
        S(cx + s * L.jawW * 0.85, L.jawY + 6, 9, 8, 2.4 * L.jowl)
      }
    }
    // linhas verticais do lábio (idosos)
    if (L.old > 0.35) for (let k = -3; k <= 3; k++) if (k) SL([[cx + k * L.mouthW * 0.07, mouthY - L.lipU - 4], [cx + k * L.mouthW * 0.065, mouthY - L.lipU * 0.3]], 0.7, -0.7 * (L.old - 0.3))
    // pescoço com anéis
    if (age > 40) for (let k = 0; k < 2; k++) {
      const y = L.chinY + 14 + k * 11
      SL([[cx - L.neckW * 0.42, y + 2], [cx, y + 4], [cx + L.neckW * 0.42, y + 2]], 1.4, -0.8 * smooth(40, 85, age))
    }
    // orelhas: hélice e concha
    for (const e of ears) {
      S(e.fx + e.s * e.out * 0.55, e.mid, e.out * 0.28, L.earH * 0.28, -3)
      SL([[e.fx + e.s * e.out * 0.5, e.top + 3], [e.fx + e.s * e.out * 0.85, e.top + L.earH * 0.25], [e.fx + e.s * e.out * 0.8, e.mid + 4]], 1.6, 2)
    }

    // textura fina: poros e irregularidade
    const seed = hash32(g.id) % 1000
    const poreAmp = 0.14 + old * 0.3 + (1 - g.skin.quality) * 0.25
    for (let py = 0; py < ph; py++) {
      for (let px = 0; px < pw; px++) {
        const i = py * pw + px
        if (Mh[i] + Mb[i] + Me[i] < 0.01) continue
        const x = px / res, y = py / res
        Hm[i] += (fbm(x * 0.9, y * 0.9, seed) - 0.5) * poreAmp + (vnoise(x * 2.3, y * 2.3, seed + 5) - 0.5) * poreAmp * 0.6
        if (old > 0.3) Hm[i] += (fbm(x * 0.35, y * 1.4, seed + 9) - 0.5) * (old - 0.3) * 0.8
      }
    }

    // ---------- albedo ----------
    const A = new Float32Array(N * 3)
    const red = new Float32Array(N)
    const dark = new Float32Array(N)
    const lipM = new Float32Array(N)
    const spec = new Float32Array(N)
    const beardShadow = new Float32Array(N)
    const RS = (x, y, rx2, ry2, amp) => stamp(red, pw, ph, res, x, y, rx2, ry2, amp)
    const DS = (x, y, rx2, ry2, amp) => stamp(dark, pw, ph, res, x, y, rx2, ry2, amp)
    const rosy = g.skin.rosy * (1 - P.mel * 0.6)
    for (const s of [-1, 1]) {
      RS(cx + s * rx * 0.55, eyeY + eyeW * 1.1, rx * 0.26, rx * 0.2, 0.28 * rosy + baby * 0.18 + makeup * 0.1)
      DS(cx + s * eyeOff, eyeY + eyeW * 0.45, eyeW * 0.4, eyeW * 0.14, 0.14 + old * 0.12 + (1 - g.skin.quality) * 0.1)
      DS(cx + s * eyeOff * 0.9, eyeY - eyeW * 0.35, eyeW * 0.5, eyeW * 0.18, 0.05 - makeup * 0.05)
      RS(cx + s * rx * 1.02, (L.browY + L.noseY) / 2 + 6, 10, 18, 0.25)
    }
    RS(cx, noseY - L.noseLen * 0.12, L.noseW * 0.4, L.noseW * 0.3, 0.22 * rosy + old * 0.08)
    RS(cx, chinY - 10, L.chinW * 0.8, 8, 0.1 * rosy)
    // áreas de brilho (zona T)
    stamp(spec, pw, ph, res, cx, browY - 24, rx * 0.45, 18, 0.55)
    stamp(spec, pw, ph, res, tipX, tipY, tipR * 1.2, tipR, 0.6)
    stamp(spec, pw, ph, res, cx, noseY - L.noseLen * 0.5, 4, L.noseLen * 0.35, 0.25)
    stamp(spec, pw, ph, res, cx, mouthY + L.lipL * 0.6, L.mouthW * 0.25, L.lipL * 0.3, 0.9)
    for (const s of [-1, 1]) stamp(spec, pw, ph, res, cx + s * rx * 0.55, eyeY + eyeW * 0.85, 14, 9, 0.35)
    // máscara dos lábios
    {
      mc.clearRect(0, 0, W, H)
      mc.fillStyle = "#fff"
      mc.fill(lipsPath(L))
      const d = mc.getImageData(0, 0, pw, ph).data
      for (let i = 0; i < N; i++) lipM[i] = d[i * 4 + 3] / 255
      const lb = boxBlur(lipM, pw, ph, Math.max(1, Math.round(res)))
      lipM.set(lb)
    }
    // sombra da barba raspada (homens adultos)
    if (g.sex === "M" && age > 17) {
      mc.clearRect(0, 0, W, H)
      mc.fillStyle = "#fff"
      mc.fill(beardRegionPath(L, ["mus", "chin", "cheek", "neck"], 0))
      const d = mc.getImageData(0, 0, pw, ph).data
      const tmp = new Float32Array(N)
      for (let i = 0; i < N; i++) tmp[i] = d[i * 4 + 3] / 255
      const bl = blur3(tmp, pw, ph, Math.round(3 * res))
      const k = g.hair.beardDensity * P.hairEu * (1 - P.mel * 0.8) * smooth(17, 25, age) * 0.35
      for (let i = 0; i < N; i++) beardShadow[i] = bl[i] * k
    }
    // pintas, sardas, manchas senis, acne
    const mr = makeRng(hash32(g.id + ":marks"))
    const moles = []
    for (let i = 0; i < Math.round(g.skin.moles * smooth(2, 25, age)); i++) moles.push([cx + mr.normal() * rx * 0.55, lerp(L.hairlineY + 10, chinY + 30, mr()), 0.5 + mr() * 0.7])
    const frk = []
    const fN = Math.floor(P.freckle * 260 * (1 - smooth(50, 80, age) * 0.5))
    for (let i = 0; i < fN; i++) {
      const s = mr.chance(0.5) ? -1 : 1
      frk.push([cx + s * Math.abs(mr.normal()) * rx * 0.42, eyeY + eyeW * 0.4 + mr.normal() * eyeW * 0.7, 0.6 + mr() * 0.9, 0.2 + mr() * 0.4])
    }
    const spots = []
    const spN = Math.floor(smooth(55, 90, age) * 14 * (1 - P.mel * 0.7) * g.skin.aging)
    for (let i = 0; i < spN; i++) spots.push([cx + mr.normal() * rx * 0.6, lerp(L.hairlineY - 20, noseY, mr()), 2 + mr() * 4, 0.12 + mr() * 0.14])
    const acne = []
    const acN = Math.floor((1 - g.skin.quality) * 30 * (smooth(12, 16, age) * (1 - smooth(22, 32, age)) + 0.25))
    for (let i = 0; i < acN; i++) acne.push([cx + mr.normal() * rx * 0.5, lerp(browY - 30, chinY - 6, mr()), 1 + mr() * 1.6])
    for (const [x, y, rr] of acne) {
      RS(x, y, rr * 1.8, rr * 1.8, 0.3)
      stamp(Hm, pw, ph, res, x, y, rr, rr, 1.2)
    }

    const baseTone = new Float32Array(N)
    const lipCol = mix(mul(skin, 0.8), [176, 84, 88], 0.5 * (1 - P.mel * 0.45))
    const lipstick = makeup > 0.5 ? mix(lipCol, [150 + makeup * 40, 40, 60], (makeup - 0.4) * 0.8) : lipCol
    for (let py = 0; py < ph; py++) {
      for (let px = 0; px < pw; px++) {
        const i = py * pw + px
        const m = Math.max(Mh[i], Mb[i], Me[i])
        if (m < 0.01) continue
        const x = px / res, y = py / res
        const n = fbm(x * 0.045, y * 0.045, seed + 3) - 0.5
        let c0 = skin[0] * (1 + n * 0.1), c1 = skin[1] * (1 + n * 0.1), c2 = skin[2] * (1 + n * 0.12)
        // neck a touch darker, ears redder
        if (Mh[i] < 0.5 && Mb[i] > 0.5) { c0 *= 0.95; c1 *= 0.93; c2 *= 0.93 }
        const rd = red[i]
        c0 = lerp(c0, c0 * 1.05 + 10, rd); c1 = lerp(c1, c1 * 0.8, rd); c2 = lerp(c2, c2 * 0.8, rd)
        const dk = dark[i]
        c0 *= 1 - dk * 0.5; c1 *= 1 - dk * 0.55; c2 *= 1 - dk * 0.4
        const bs = beardShadow[i]
        c0 = lerp(c0, 70, bs); c1 = lerp(c1, 72, bs); c2 = lerp(c2, 78, bs)
        const lm = lipM[i]
        c0 = lerp(c0, lipstick[0], lm); c1 = lerp(c1, lipstick[1], lm); c2 = lerp(c2, lipstick[2], lm)
        A[i * 3] = c0; A[i * 3 + 1] = c1; A[i * 3 + 2] = c2
        baseTone[i] = m
      }
    }
    const dot = (list, col, soft) => {
      for (const [x, y, rr, a = 0.6] of list) {
        const X = x * res, Y = y * res, R = rr * res * 1.6
        for (let py = Math.max(0, (Y - R) | 0); py <= Math.min(ph - 1, (Y + R) | 0); py++)
          for (let px = Math.max(0, (X - R) | 0); px <= Math.min(pw - 1, (X + R) | 0); px++) {
            const d = Math.hypot(px - X, py - Y) / (rr * res)
            if (d > 1.6) continue
            const t = a * (d < 1 ? 1 : 1 - (d - 1) / 0.6) * (soft ? 1 - d / 1.6 : 1)
            const i = py * pw + px
            A[i * 3] = lerp(A[i * 3], col[0], t); A[i * 3 + 1] = lerp(A[i * 3 + 1], col[1], t); A[i * 3 + 2] = lerp(A[i * 3 + 2], col[2], t)
          }
      }
    }
    dot(frk, mul(skin, 0.72).map((v, k) => v * [1.05, 0.92, 0.8][k]), true)
    dot(spots, mul(skin, 0.7).map((v, k) => v * [1.02, 0.9, 0.78][k]), true)
    dot(moles.map(([x, y, rr]) => [x, y, rr, 0.7]), mul(skin, 0.5), true)

    // ---------- iluminação ----------
    const Hb = blur3(Hm, pw, ph, Math.round(5 * res))
    // sombra projetada da cabeça no pescoço
    const sh = new Float32Array(N)
    const shift = Math.round(9 * res), sx = Math.round(3 * res)
    for (let py = 0; py < ph; py++) for (let px = 0; px < pw; px++) {
      const sy = py - shift, sxx = px - sx
      if (sy >= 0 && sxx >= 0) sh[py * pw + px] = Mh[sy * pw + sxx]
    }
    const shB = blur3(sh, pw, ph, Math.round(7 * res))
    const Lx = -0.42, Ly = -0.52, Lz = 0.74
    const hx = Lx, hy = Ly, hz = Lz + 1
    const hl = Math.hypot(hx, hy, hz)
    const img = ctx.getImageData(0, 0, pw, ph)
    const out = img.data
    const k = 0.34 / res
    const oil = 0.5 + (1 - g.skin.quality) * 0.3 - old * 0.25
    for (let py = 1; py < ph - 1; py++) {
      for (let px = 1; px < pw - 1; px++) {
        const i = py * pw + px
        const m = baseTone[i]
        if (m < 0.01) continue
        const dx = (Hm[i + 1] - Hm[i - 1]) * k
        const dy = (Hm[i + pw] - Hm[i - pw]) * k
        const inv = 1 / Math.sqrt(dx * dx + dy * dy + 1)
        const nx = -dx * inv, ny = -dy * inv, nz = inv
        const d = nx * Lx + ny * Ly + nz * Lz
        const cav = clamp((Hb[i] - Hm[i]) * 0.06, 0, 0.45)
        let ao = 1 - cav * 0.8
        if (Mh[i] < 0.5) ao *= 1 - shB[i] * 0.42 // pescoço sob o queixo
        const wR = clamp((d + 0.42) / 1.42), wG = clamp((d + 0.32) / 1.32), wB = clamp((d + 0.3) / 1.3)
        const amb = 0.36
        const sp = Math.pow(Math.max(0, (nx * hx + ny * hy + nz * hz) / hl), 34) * (0.05 + spec[i] * oil * 0.22)
        let r0 = A[i * 3] * (amb + wR * 0.8) * ao + sp * 255
        let g0 = A[i * 3 + 1] * (amb + wG * 0.8) * ao + sp * 245
        let b0 = A[i * 3 + 2] * (amb + wB * 0.8) * ao + sp * 240
        const lum = r0 * 0.3 + g0 * 0.59 + b0 * 0.11
        r0 = lerp(lum, r0, 0.86); g0 = lerp(lum, g0, 0.86); b0 = lerp(lum, b0, 0.86)
        const o = i * 4
        out[o] = lerp(out[o], r0, m)
        out[o + 1] = lerp(out[o + 1], g0, m)
        out[o + 2] = lerp(out[o + 2], b0, m)
        out[o + 3] = 255
      }
    }
    ctx.putImageData(img, 0, 0)
  }

  // =====================================================================
  // PELE — modo vetorial
  function drawSkinVector(ctx, g, L, P, skin, headPath, earPaths, bodyPath, ears, age, makeup, beardStyle) {
    const shade = mul(skin, 0.78)
    ctx.fillStyle = rgb(mul(skin, 0.9))
    ctx.fill(bodyPath)
    // sombra do queixo no pescoço
    ctx.save()
    ctx.clip(bodyPath)
    ctx.fillStyle = rgb(mul(skin, 0.7), 0.7)
    ctx.beginPath()
    ctx.ellipse(L.cx + 3, L.chinY + 4, L.jawW * 0.8, 16, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()
    for (const p of earPaths) {
      ctx.fillStyle = rgb(mix(skin, [200, 110, 100], 0.12))
      ctx.fill(p)
    }
    for (const e of ears) {
      ctx.strokeStyle = rgb(shade, 0.8)
      ctx.lineWidth = 1.4
      ctx.beginPath()
      ctx.moveTo(e.fx + e.s * e.out * 0.45, e.top + 5)
      ctx.quadraticCurveTo(e.fx + e.s * e.out * 0.85, e.mid - 4, e.fx + e.s * e.out * 0.45, e.bot - 6)
      ctx.stroke()
    }
    ctx.fillStyle = rgb(skin)
    ctx.fill(headPath)
    ctx.save()
    ctx.clip(headPath)
    const gsh = ctx.createLinearGradient(L.cx - L.rx, 0, L.cx + L.rx, 0)
    gsh.addColorStop(0, rgb(mix(skin, [255, 240, 225], 0.12), 1))
    gsh.addColorStop(0.55, rgb(skin, 0))
    gsh.addColorStop(1, rgb(shade, 0.9))
    ctx.fillStyle = gsh
    ctx.fillRect(0, 0, W, H)
    const blush = ctx.createRadialGradient(0, 0, 0, 0, 0, 1)
    blush.addColorStop(0, `rgba(220,90,90,${0.18 * g.skin.rosy + L.baby * 0.15 + makeup * 0.1})`)
    blush.addColorStop(1, "rgba(220,90,90,0)")
    for (const s of [-1, 1]) {
      ctx.save()
      ctx.translate(L.cx + s * L.rx * 0.55, L.eyeY + L.eyeW * 1.1)
      ctx.scale(L.rx * 0.3, L.rx * 0.22)
      ctx.fillStyle = blush
      ctx.fillRect(-1, -1, 2, 2)
      ctx.restore()
    }
    // rugas simples
    const ag = smooth(30, 85, age)
    ctx.strokeStyle = rgb(shade, 0.55 * ag)
    ctx.lineWidth = 1
    for (let i = 0; i < 3; i++) {
      const y = L.browY - (L.browY - L.hairlineY) * (0.3 + i * 0.17)
      ctx.beginPath()
      ctx.moveTo(L.cx - L.rx * 0.45, y)
      ctx.quadraticCurveTo(L.cx, y - 3, L.cx + L.rx * 0.45, y)
      ctx.stroke()
    }
    for (const s of [-1, 1]) {
      ctx.strokeStyle = rgb(shade, 0.35 + ag * 0.4)
      ctx.lineWidth = 1.4
      ctx.beginPath()
      ctx.moveTo(L.cx + s * L.noseW * 0.55, L.noseY - L.noseLen * 0.12)
      ctx.quadraticCurveTo(L.cx + s * L.mouthW * 0.62, L.mouthY - 6, L.cx + s * L.mouthW * 0.6, L.mouthY + 6 + L.old * 6)
      ctx.stroke()
      if (ag > 0.2) {
        for (let k = -1; k <= 1; k++) {
          ctx.beginPath()
          const ox = L.cx + s * (L.eyeOff + L.eyeW * 0.62)
          ctx.moveTo(ox, L.eyeY + k * 3)
          ctx.lineTo(ox + s * L.eyeW * 0.35, L.eyeY + k * 5 - 2)
          ctx.stroke()
        }
      }
    }
    ctx.restore()
    // lábios preenchidos aqui (drawMouth faz a linha)
    ctx.fillStyle = rgb(mix(mul(skin, 0.8), [180, 90, 90], 0.35 * (1 - P.mel * 0.5)))
    ctx.fill(lipsPath(L))
  }

  // =====================================================================
  function lipsPath(L) {
    const { cx, mouthY, mouthW, lipU, lipL, asymMouth } = L
    const hw = mouthW / 2
    const droop = L.old * 3
    const p = new Path2D()
    const lx = cx - hw + asymMouth * 0.3, rx = cx + hw + asymMouth * 0.3
    p.moveTo(lx, mouthY + droop)
    p.bezierCurveTo(cx - hw * 0.6, mouthY - lipU * 0.7, cx - hw * 0.35, mouthY - lipU * 1.15, cx - hw * 0.14, mouthY - lipU * 1.05)
    p.quadraticCurveTo(cx, mouthY - lipU * 0.78, cx + hw * 0.14, mouthY - lipU * 1.05)
    p.bezierCurveTo(cx + hw * 0.35, mouthY - lipU * 1.15, cx + hw * 0.6, mouthY - lipU * 0.7, rx, mouthY + droop)
    p.bezierCurveTo(cx + hw * 0.6, mouthY + lipL * 1.2, cx - hw * 0.6, mouthY + lipL * 1.2, lx, mouthY + droop)
    p.closePath()
    return p
  }

  function drawMouth(ctx, g, L, P, skin, mode, makeup, age) {
    const { cx, mouthY, mouthW, lipU, lipL, asymMouth } = L
    const hw = mouthW / 2
    const droop = L.old * 3 - (makeup > 0 ? 0.3 : 0)
    const lx = cx - hw + asymMouth * 0.3, rx = cx + hw + asymMouth * 0.3
    // linha entre os lábios
    ctx.save()
    ctx.lineCap = "round"
    const lineCol = mix(mul(skin, 0.35), [60, 20, 20], 0.3)
    ctx.strokeStyle = rgb(lineCol, 0.85)
    ctx.lineWidth = mode === "real" ? 1.3 : 1.6
    ctx.beginPath()
    ctx.moveTo(lx, mouthY + droop)
    ctx.bezierCurveTo(cx - hw * 0.5, mouthY + 0.8, cx - hw * 0.1, mouthY + 1.4, cx, mouthY + 0.6)
    ctx.bezierCurveTo(cx + hw * 0.1, mouthY + 1.4, cx + hw * 0.5, mouthY + 0.8, rx, mouthY + droop)
    ctx.stroke()
    // cantos
    for (const [x, s] of [[lx, -1], [rx, 1]]) {
      const gr = ctx.createRadialGradient(x, mouthY + droop, 0, x, mouthY + droop, 4)
      gr.addColorStop(0, rgb(lineCol, 0.5))
      gr.addColorStop(1, rgb(lineCol, 0))
      ctx.fillStyle = gr
      ctx.fillRect(x - 5, mouthY + droop - 5, 10, 10)
    }
    // brilho do lábio inferior
    const hl = ctx.createRadialGradient(cx - hw * 0.12, mouthY + lipL * 0.55, 0, cx - hw * 0.12, mouthY + lipL * 0.55, hw * 0.4)
    hl.addColorStop(0, `rgba(255,240,235,${mode === "real" ? 0.18 + makeup * 0.12 : 0.22})`)
    hl.addColorStop(1, "rgba(255,240,235,0)")
    ctx.fillStyle = hl
    ctx.beginPath()
    ctx.ellipse(cx - hw * 0.12, mouthY + lipL * 0.55, hw * 0.4, lipL * 0.4, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()
  }

  function drawNose(ctx, L, skin, mode) {
    const tipX = L.cx + L.asymNose, y = L.noseY
    const nc = mul(skin, 0.38)
    for (const s of [-1, 1]) {
      ctx.save()
      ctx.translate(tipX + s * L.noseW * 0.19, y - 1)
      ctx.rotate(s * 0.35)
      ctx.fillStyle = rgb(nc, mode === "real" ? 0.55 : 0.75)
      ctx.beginPath()
      ctx.ellipse(0, 0, L.noseW * 0.1, L.noseW * 0.052, 0, 0, Math.PI * 2)
      ctx.fill()
      ctx.restore()
    }
    if (mode === "vector") {
      ctx.strokeStyle = rgb(mul(skin, 0.6), 0.9)
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.moveTo(tipX - L.noseW * 0.5, y - L.noseLen * 0.1)
      ctx.quadraticCurveTo(tipX - L.noseW * 0.55, y + 1, tipX - L.noseW * 0.2, y + 1)
      ctx.moveTo(tipX + L.noseW * 0.5, y - L.noseLen * 0.1)
      ctx.quadraticCurveTo(tipX + L.noseW * 0.55, y + 1, tipX + L.noseW * 0.2, y + 1)
      ctx.stroke()
      ctx.strokeStyle = rgb(mul(skin, 0.75), 0.6)
      ctx.beginPath()
      ctx.moveTo(tipX + 4, L.browY + 8)
      ctx.quadraticCurveTo(tipX + 6, y - L.noseLen * 0.4, tipX + L.noseW * 0.25, y - L.noseLen * 0.15)
      ctx.stroke()
    }
  }

  // =====================================================================
  function drawEye(ctx, g, L, P, s, eyeCol, mode, makeup, age, r) {
    const w = L.eyeW
    const ex = L.cx + s * L.eyeOff
    const ey = L.eyeY + L.asymEye[s < 0 ? 0 : 1]
    const h = w * L.open
    const tilt = L.tilt * w
    const X = (u) => ex + s * u
    const hood = clamp(0.25 * g.z.hood + L.old * 0.9 + (g.z.lidFold < -0.6 ? 0.3 : 0), 0, 1.2)
    const monolid = g.z.lidFold < -0.6
    const inner = [X(-w / 2), ey + tilt * 0.5 + w * 0.04]
    const outer = [X(w / 2), ey - tilt * 0.5 - hood * w * 0.0]
    const up1 = [X(-w * 0.22), ey - h * 1.02 + tilt * 0.2]
    const up2 = [X(w * 0.22), ey - h * (1.0 - hood * 0.22) - tilt * 0.25]
    const lo1 = [X(w * 0.24), ey + h * 0.62 - tilt * 0.1]
    const lo2 = [X(-w * 0.2), ey + h * 0.6 + tilt * 0.15]
    const eyePath = new Path2D()
    eyePath.moveTo(...inner)
    eyePath.bezierCurveTo(...up1, ...up2, ...outer)
    eyePath.bezierCurveTo(...lo1, ...lo2, ...inner)
    eyePath.closePath()

    ctx.save()
    ctx.clip(eyePath)
    // esclera
    const sc = ctx.createRadialGradient(ex, ey, 0, ex, ey, w * 0.6)
    sc.addColorStop(0, "rgb(226,220,214)")
    sc.addColorStop(0.65, "rgb(205,194,188)")
    sc.addColorStop(1, "rgb(170,135,130)")
    ctx.fillStyle = sc
    ctx.fillRect(ex - w, ey - w, w * 2, w * 2)
    // íris
    const ir = w * lerp(0.255, 0.205, L.gr) * (1 - L.old * 0.03)
    const ix = ex + s * w * 0.01, iy = ey - h * 0.08
    const ig = ctx.createRadialGradient(ix, iy, ir * 0.25, ix, iy, ir)
    ig.addColorStop(0, rgb(mix(eyeCol, [200, 170, 90], 0.25)))
    ig.addColorStop(0.45, rgb(eyeCol))
    ig.addColorStop(0.85, rgb(mul(eyeCol, 0.72)))
    ig.addColorStop(1, rgb(mul(eyeCol, 0.35)))
    ctx.fillStyle = ig
    ctx.beginPath()
    ctx.arc(ix, iy, ir, 0, Math.PI * 2)
    ctx.fill()
    if (mode === "real") {
      // fibras da íris
      const fr = makeRng(hash32(g.id + s))
      ctx.lineWidth = 0.5
      for (let i = 0; i < 70; i++) {
        const an = fr() * Math.PI * 2
        const r0 = ir * (0.35 + fr() * 0.1), r1 = ir * (0.75 + fr() * 0.22)
        ctx.strokeStyle = fr() < 0.5 ? rgb(mix(eyeCol, [255, 240, 200], 0.35), 0.35) : rgb(mul(eyeCol, 0.55), 0.35)
        ctx.beginPath()
        ctx.moveTo(ix + Math.cos(an) * r0, iy + Math.sin(an) * r0)
        ctx.lineTo(ix + Math.cos(an + 0.08) * r1, iy + Math.sin(an + 0.08) * r1)
        ctx.stroke()
      }
      // anel limbal
      ctx.strokeStyle = `rgba(20,15,12,${0.55 - L.old * 0.25})`
      ctx.lineWidth = ir * 0.12
      ctx.beginPath()
      ctx.arc(ix, iy, ir * 0.94, 0, Math.PI * 2)
      ctx.stroke()
      if (L.old > 0.5) {
        ctx.strokeStyle = `rgba(210,210,215,${(L.old - 0.5) * 0.6})` // arco senil
        ctx.lineWidth = ir * 0.1
        ctx.beginPath()
        ctx.arc(ix, iy, ir * 0.92, 0, Math.PI * 2)
        ctx.stroke()
      }
    }
    // pupila
    ctx.fillStyle = "#0b0909"
    ctx.beginPath()
    ctx.arc(ix, iy, ir * lerp(0.46, 0.36, L.gr) * (1 - L.old * 0.12), 0, Math.PI * 2)
    ctx.fill()
    // sombra da pálpebra superior sobre o olho
    const ls = ctx.createLinearGradient(0, ey - h, 0, ey + h * 0.2)
    ls.addColorStop(0, "rgba(40,20,15,0.6)")
    ls.addColorStop(0.45, "rgba(40,20,15,0.15)")
    ls.addColorStop(1, "rgba(40,20,15,0)")
    ctx.fillStyle = ls
    ctx.fillRect(ex - w, ey - w, w * 2, w * 2)
    // reflexo
    ctx.fillStyle = "rgba(255,255,255,0.92)"
    ctx.beginPath()
    ctx.ellipse(ix - ir * 0.38, iy - ir * 0.38, ir * 0.17, ir * 0.14, -0.5, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = "rgba(255,255,255,0.25)"
    ctx.beginPath()
    ctx.arc(ix + ir * 0.35, iy + ir * 0.35, ir * 0.07, 0, Math.PI * 2)
    ctx.fill()
    // carúncula
    ctx.fillStyle = "rgba(205,120,115,0.7)"
    ctx.beginPath()
    ctx.ellipse(inner[0] + s * w * 0.05, inner[1] - 0.5, w * 0.06, h * 0.25, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()

    // pálpebra superior: linha dos cílios
    const lashCol = makeup > 0.3 ? "rgba(8,6,6,0.95)" : `rgba(${22 + (1 - P.hairEu) * 40},${16 + (1 - P.hairEu) * 25},${14 + (1 - P.hairEu) * 12},0.9)`
    ctx.save()
    ctx.lineCap = "round"
    ctx.strokeStyle = lashCol
    ctx.lineWidth = w * (0.038 + makeup * 0.03) * (mode === "real" ? 1 : 1.3)
    ctx.beginPath()
    ctx.moveTo(inner[0] + s * w * 0.05, inner[1] - 0.5)
    ctx.bezierCurveTo(...up1, ...up2, ...outer)
    ctx.stroke()
    if (makeup > 0.55) {
      // delineado com gatinho
      ctx.lineWidth = w * 0.05
      ctx.beginPath()
      ctx.moveTo(outer[0] - s * w * 0.1, outer[1] - 0.5)
      ctx.lineTo(outer[0] + s * w * 0.18, outer[1] - w * 0.12)
      ctx.stroke()
    }
    // cílios
    const lashN = mode === "real" ? 40 : 8
    const lashLen = w * (g.sex === "F" ? 0.11 : 0.07) * (1 + L.baby * 0.4 + makeup * 0.5) * (1 - L.old * 0.3)
    ctx.lineWidth = mode === "real" ? 0.45 : 1
    for (let i = 4; i < lashN; i++) {
      const t = i / lashN
      const bx = bez(inner[0], up1[0], up2[0], outer[0], t), by = bez(inner[1], up1[1], up2[1], outer[1], t)
      const len = lashLen * (0.5 + t * 0.7)
      ctx.beginPath()
      ctx.moveTo(bx, by)
      ctx.quadraticCurveTo(bx + s * len * (0.2 + t * 0.6), by - len * 0.9, bx + s * len * (0.4 + t * 0.9), by - len * 0.8)
      ctx.stroke()
    }
    // espessura da pálpebra inferior (linha d'água clara)
    ctx.strokeStyle = "rgba(235,190,180,0.35)"
    ctx.lineWidth = 1.2
    ctx.beginPath()
    ctx.moveTo(outer[0] - s * w * 0.08, outer[1] + 1)
    ctx.bezierCurveTo(lo1[0], lo1[1] - 1.2, lo2[0], lo2[1] - 1.2, inner[0] + s * w * 0.08, inner[1])
    ctx.stroke()
    // sombra sob o vinco da pálpebra
    {
      const sg = ctx.createLinearGradient(0, ey - h * 1.6, 0, ey - h * 0.8)
      sg.addColorStop(0, "rgba(60,30,20,0)")
      sg.addColorStop(1, "rgba(60,30,20,0.14)")
      ctx.fillStyle = sg
      ctx.beginPath()
      ctx.moveTo(...inner)
      ctx.bezierCurveTo(X(-w * 0.2), ey - h * 1.7, X(w * 0.25), ey - h * 1.65, ...outer)
      ctx.bezierCurveTo(...up2, ...up1, ...inner)
      ctx.fill()
    }
    // pálpebra inferior
    ctx.strokeStyle = `rgba(90,50,45,${mode === "real" ? 0.35 : 0.5})`
    ctx.lineWidth = 0.9
    ctx.beginPath()
    ctx.moveTo(...outer)
    ctx.bezierCurveTo(...lo1, ...lo2, ...inner)
    ctx.stroke()
    // vinco palpebral ou dobra epicântica
    const skinDark = "rgba(70,35,25,"
    if (!monolid) {
      const cr = h * (0.55 + 0.25 * clamp(g.z.lidFold, -1, 1.5)) * (1 - hood * 0.6)
      ctx.strokeStyle = skinDark + (0.28 + L.old * 0.15) + ")"
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(X(-w * 0.34), ey - h * 0.7 - cr * 0.4)
      ctx.bezierCurveTo(X(-w * 0.1), ey - h - cr, X(w * 0.22), ey - h - cr * 0.95, X(w * 0.52), ey - h * 0.45 - cr * 0.3 + hood * 3)
      ctx.stroke()
    } else {
      ctx.strokeStyle = skinDark + "0.25)"
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(inner[0] - s * 1, inner[1] + 1)
      ctx.quadraticCurveTo(X(-w * 0.35), ey - h * 0.95, X(-w * 0.05), ey - h * 1.05)
      ctx.stroke()
    }
    // pálpebra caída (encapuzada) na velhice
    if (hood > 0.35) {
      ctx.fillStyle = `rgba(0,0,0,${0.08 * hood})`
      ctx.beginPath()
      ctx.moveTo(X(w * 0.05), ey - h * 1.05)
      ctx.quadraticCurveTo(X(w * 0.4), ey - h * 0.95, outer[0] + s * w * 0.08, outer[1] + 1)
      ctx.quadraticCurveTo(X(w * 0.35), ey - h * 0.7, X(w * 0.05), ey - h * 1.05)
      ctx.fill()
    }
    if (makeup > 0.4) {
      ctx.fillStyle = `rgba(90,60,70,${(makeup - 0.4) * 0.25})`
      ctx.beginPath()
      ctx.ellipse(X(w * 0.08), ey - h * 1.1, w * 0.48, h * 0.55, 0, Math.PI, 0)
      ctx.fill()
    }
    ctx.restore()
  }
  function bez(a, b, c, d, t) {
    const u = 1 - t
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
  }

  function drawBrow(ctx, g, L, s, col, age, r) {
    const w = L.eyeW
    const ex = L.cx + s * L.eyeOff
    const by = L.browY + L.asymBrow[s < 0 ? 0 : 1] - 1
    const F = g.sex === "F"
    const thick = w * (F ? 0.1 : 0.14) * (1 + 0.3 * g.z.browThick) * lerp(0.45, 1, L.gr)
    const arch = w * (F ? 0.16 : 0.09) * (1 + 0.4 * g.z.browArch)
    const len = w * (1.15 + 0.1 * g.z.browLen)
    const gap = w * (0.5 + 0.12 * g.z.browGap)
    const x0 = L.cx + s * gap
    const x1 = x0 + s * len
    const peakT = 0.65
    const yAt = (t) => by - arch * Math.sin(Math.PI * Math.min(t / peakT, 1) * 0.5) * (t > peakT ? 1 - ((t - peakT) / (1 - peakT)) * 0.9 : 1) + (t > peakT ? (t - peakT) * w * 0.25 : 0) + (1 - t) * w * 0.02
    const br = makeRng(hash32(g.id + "brow" + s))
    const n = Math.floor(90 * (1 + 0.3 * g.z.browThick) * lerp(0.4, 1, L.gr))
    const bushy = L.old * (F ? 0.2 : 1)
    ctx.save()
    ctx.lineCap = "round"
    for (let i = 0; i < n; i++) {
      const t = br()
      const x = lerp(x0, x1, t)
      const y = yAt(t) + (br() - 0.5) * thick * (1.2 - t * 0.7)
      const ang = t < 0.25 ? -Math.PI / 2 + s * 0.5 : s > 0 ? -0.35 + t * 0.5 : Math.PI + 0.35 - t * 0.5
      const l = (thick * 0.9 + br() * thick * 0.6) * (1 + bushy * br() * 1.2)
      const shade = 0.75 + br() * 0.45
      ctx.strokeStyle = rgb(mul(col, shade * (L.baby > 0.5 ? 1.3 : 1)), (0.35 + br() * 0.45) * lerp(0.4, 1, L.gr))
      ctx.lineWidth = 0.55 + br() * 0.5
      ctx.beginPath()
      ctx.moveTo(x, y)
      ctx.quadraticCurveTo(x + Math.cos(ang) * l * 0.5, y + Math.sin(ang) * l * 0.5 - 0.5, x + Math.cos(ang) * l, y + Math.sin(ang) * l + 0.3)
      ctx.stroke()
    }
    // monocelha
    if (g.z.browGap < -1.3 && L.gr > 0.5) {
      ctx.strokeStyle = rgb(col, 0.25)
      for (let i = 0; i < 18; i++) {
        const x = lerp(L.cx - gap, L.cx + gap, br()) , y = by + (br() - 0.5) * thick
        ctx.beginPath()
        ctx.moveTo(x, y)
        ctx.lineTo(x + (br() - 0.5) * 2, y - 2.5)
        ctx.stroke()
      }
    }
    ctx.restore()
  }

  // =====================================================================
  // ROUPA
  function drawClothes(ctx, g, L, age, mode) {
    const pref = g.pref
    let kind = pref.shirt
    if (age < 3) kind = "crew"
    if (kind === "tank" && g.sex === "M" && age < 16) kind = "crew"
    const h = age < 3 ? pref.shirtHue : pref.shirtHue
    const col = age < 3 ? hslToRgb(h, 0.22, 0.7) : hslToRgb(h, 0.06 + pref.shirtTone * 0.16, 0.18 + pref.shirtTone * 0.34)
    const { cx, neckW, shoulderY, shoulderW, chinY } = L
    const nl = cx - neckW / 2, nr = cx + neckW / 2
    const neckBase = shoulderY - 4
    const p = new Path2D()
    const collarDepth = kind === "vneck" ? 34 : kind === "tank" ? 30 : kind === "collar" ? 14 : 8
    p.moveTo(nl - 6, neckBase - 2)
    if (kind === "vneck") p.lineTo(cx, neckBase + collarDepth)
    else p.quadraticCurveTo(cx, neckBase + collarDepth * 1.6, nr + 6, neckBase - 2)
    if (kind === "vneck") p.lineTo(nr + 6, neckBase - 2)
    if (kind === "tank") {
      p.lineTo(nr + 14, neckBase - 4)
      p.lineTo(nr + 20, shoulderY + 30)
      p.quadraticCurveTo(cx + shoulderW * 0.42, shoulderY + 34, cx + shoulderW * 0.5, shoulderY + 70)
    } else {
      p.quadraticCurveTo(cx + shoulderW * 0.35, shoulderY - 8, cx + shoulderW * 0.47, shoulderY + 10)
      p.quadraticCurveTo(cx + shoulderW * 0.56, shoulderY + 25, cx + shoulderW * 0.6, shoulderY + 70)
    }
    p.lineTo(cx + shoulderW * 0.62, H + 10)
    p.lineTo(cx - shoulderW * 0.62, H + 10)
    if (kind === "tank") {
      p.lineTo(cx - shoulderW * 0.5, shoulderY + 70)
      p.quadraticCurveTo(cx - shoulderW * 0.42, shoulderY + 34, nl - 20, shoulderY + 30)
      p.lineTo(nl - 14, neckBase - 4)
    } else {
      p.lineTo(cx - shoulderW * 0.6, shoulderY + 70)
      p.quadraticCurveTo(cx - shoulderW * 0.56, shoulderY + 25, cx - shoulderW * 0.47, shoulderY + 10)
      p.quadraticCurveTo(cx - shoulderW * 0.35, shoulderY - 8, nl - 6, neckBase - 2)
    }
    p.closePath()
    ctx.save()
    ctx.fillStyle = rgb(col)
    ctx.fill(p)
    ctx.clip(p)
    const gl = ctx.createLinearGradient(cx - shoulderW / 2, shoulderY, cx + shoulderW / 2, H)
    gl.addColorStop(0, "rgba(255,255,255,0.12)")
    gl.addColorStop(0.5, "rgba(0,0,0,0)")
    gl.addColorStop(1, "rgba(0,0,0,0.4)")
    ctx.fillStyle = gl
    ctx.fillRect(0, 0, W, H)
    // sombra do pescoço/queixo na gola
    const sh = ctx.createRadialGradient(cx + 4, neckBase + 4, 2, cx + 4, neckBase + 4, neckW)
    sh.addColorStop(0, "rgba(0,0,0,0.35)")
    sh.addColorStop(1, "rgba(0,0,0,0)")
    ctx.fillStyle = sh
    ctx.fillRect(0, 0, W, H)
    if (mode === "real") {
      // dobras
      const fr = makeRng(hash32(g.id + "folds"))
      for (let i = 0; i < 6; i++) {
        const x = cx + (fr() - 0.5) * shoulderW * 0.9
        ctx.strokeStyle = `rgba(0,0,0,${0.04 + fr() * 0.05})`
        ctx.filter = 'blur(3px)'
        ctx.lineWidth = 6 + fr() * 8
        ctx.beginPath()
        ctx.moveTo(x, shoulderY + 30 + fr() * 30)
        ctx.quadraticCurveTo(x + (fr() - 0.5) * 30, shoulderY + 90, x + (fr() - 0.5) * 20, H)
        ctx.stroke()
      }
      ctx.filter = 'none'
    }
    if (kind === "sweater") {
      ctx.strokeStyle = "rgba(0,0,0,0.25)"
      ctx.lineWidth = 1
      for (let k = 0; k < 4; k++) {
        ctx.beginPath()
        ctx.moveTo(nl - 6, neckBase + k * 2.5)
        ctx.quadraticCurveTo(cx, neckBase + collarDepth * 1.6 + k * 2.5, nr + 6, neckBase + k * 2.5)
        ctx.stroke()
      }
    }
    ctx.restore()
    if (kind === "collar") {
      const cc = mix(col, [240, 240, 235], 0.12)
      ctx.fillStyle = rgb(cc)
      for (const s of [-1, 1]) {
        ctx.beginPath()
        ctx.moveTo(cx + s * (neckW / 2 + 4), neckBase - 8)
        ctx.lineTo(cx + s * 4, neckBase + collarDepth + 6)
        ctx.lineTo(cx + s * (neckW / 2 + 26), neckBase + 12)
        ctx.closePath()
        ctx.fill()
        ctx.strokeStyle = "rgba(0,0,0,0.3)"
        ctx.stroke()
      }
    }
  }

  // =====================================================================
  // BARBA
  function beardRegionPath(L, parts, len, st = {}) {
    const p = new Path2D()
    const { cx, mouthY, noseY, chinY, eyeY, mouthW, lipU, lipL, noseW, jawY } = L
    const hw = mouthW / 2
    const fw = (y) => C.faceHalfWidth(L, y)
    const ext = len * L.Ht * 0.55
    const cheekTop = eyeY + (noseY - eyeY) * 0.85
    const add = (pts, tension = 6) => {
      const c = C.catmull(pts, true, tension)
      c.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)))
      p.closePath()
    }
    const lowPts = (width) => {
      // borda inferior estendida pelo comprimento
      const point = st.point || 0, round = st.round || 0, boxed = st.boxed || 0
      const pts = []
      const n = 8
      for (let i = 0; i <= n; i++) {
        const t = i / n
        const u = t * 2 - 1
        const x = cx + u * width * (1 + round * 0.25 * (1 - Math.abs(u)))
        const base = chinY + 3 - (1 - Math.cos(u * Math.PI / 2)) * (chinY - jawY) * 0.8
        const drop = ext * (boxed ? 1 - Math.pow(Math.abs(u), 4) * 0.6 : Math.cos(u * Math.PI / 2) * (1 - point) + point * Math.max(0, 1 - Math.abs(u) * 1.3))
        pts.push([x, base + drop])
      }
      return pts.reverse()
    }
    for (const part of parts) {
      if (part === "mus") {
        const m = st.mus || "standard"
        const top = noseY + 2
        const bot = mouthY - lipU * 0.55
        const wide = m === "pencil" ? 0.9 : m === "handlebar" ? 1.15 : m === "walrus" ? 1.2 : m === "english" ? 1.35 : m === "pencilWide" ? 1.05 : 1.02
        const t = m === "pencil" || m === "pencilWide" || m === "english" ? 0.35 : m === "walrus" ? 1.3 : 1
        const y0 = lerp(bot, top, t)
        const pts = [
          [cx, y0 - 1], [cx + noseW * 0.4, top + (y0 - top) * 0.3], [cx + hw * wide, bot + (m === "walrus" ? lipU * 1.1 : 1)],
          [cx + hw * wide * 0.8, bot + 1.5], [cx, bot - 1], [cx - hw * wide * 0.8, bot + 1.5],
          [cx - hw * wide, bot + (m === "walrus" ? lipU * 1.1 : 1)], [cx - noseW * 0.4, top + (y0 - top) * 0.3],
        ]
        if (st.musGap) { add(pts.slice(0, 5).concat([[cx + 1, bot - 2]])); add([[cx - 1, bot - 2], ...pts.slice(4)]) } else add(pts)
        if (m === "handlebar") for (const s of [-1, 1]) add([[cx + s * hw * 1.05, bot - 1], [cx + s * hw * 1.5, bot - 6], [cx + s * hw * 1.62, bot - 13], [cx + s * hw * 1.45, bot - 5], [cx + s * hw * 1.1, bot + 2]])
        if (m === "chevron") add([[cx - hw * 1.05, bot + 3], [cx, top - 1], [cx + hw * 1.05, bot + 3], [cx, bot + 1]])
      } else if (part === "chin" || part === "cheek" || part === "cheekLow" || part === "neck") {
        continue // tratados juntos abaixo
      } else if (part === "goatee" || part === "goateeFree" || part === "goateeWide" || part === "goateeRound" || part === "anchor") {
        const gw = part === "goateeWide" ? hw * 1.15 : part === "goateeRound" ? hw * 1.12 : hw * 0.72
        const top = mouthY + lipL * (part === "goateeRound" || part === "goatee" ? 0.3 : 1.1)
        const pts = [[cx - gw, top], [cx - gw * 0.4, mouthY + lipL * 1.25], [cx + gw * 0.4, mouthY + lipL * 1.25], [cx + gw, top]]
        const low = lowPts(gw * 0.95)
        add(pts.concat(low))
        if (part === "goateeRound" || part === "goatee") for (const s of [-1, 1]) add([[cx + s * hw * 0.95, mouthY - lipU * 0.5], [cx + s * hw * 1.12, mouthY], [cx + s * hw * 1.02, mouthY + lipL * 1.5], [cx + s * hw * 0.8, mouthY + lipL * 1.2]])
        if (part === "anchor") add([[cx - hw * 0.3, mouthY + lipL * 1.2], [cx, mouthY + lipL * 1.1], [cx + hw * 0.3, mouthY + lipL * 1.2], [cx, mouthY + lipL * 2.1]])
        if (part === "goateeWide") add([[cx - 5, mouthY + lipL * 1.1], [cx + 5, mouthY + lipL * 1.1], [cx + 4, mouthY + lipL * 2.2], [cx - 4, mouthY + lipL * 2.2]])
      } else if (part === "soul") {
        add([[cx - 5, mouthY + lipL * 1.15], [cx + 5, mouthY + lipL * 1.15], [cx + 3.5, mouthY + lipL * 1.15 + 10], [cx - 3.5, mouthY + lipL * 1.15 + 10]])
      } else if (part === "strap") {
        const pts = []
        for (let i = 0; i <= 12; i++) {
          const y = lerp(cheekTop + 16, chinY, i / 12)
          pts.push([cx + fw(y) - 1, y])
        }
        const inner = pts.map(([x, y]) => [cx + (x - cx) * 0.9 - 3, y - 5]).reverse()
        const pl = pts.map(([x, y]) => [2 * cx - x, y]).reverse()
        const il = inner.map(([x, y]) => [2 * cx - x, y]).reverse()
        add(pts.concat([[cx, chinY + 3]], pl.slice(0).reverse().reverse(), il, [[cx, chinY - 7]], inner), 2)
      } else if (part === "burns" || part === "chops") {
        for (const s of [-1, 1]) {
          const y0 = L.browY + 6
          const y1 = part === "burns" ? noseY + 6 : mouthY + 8
          const pts = []
          for (let i = 0; i <= 6; i++) {
            const y = lerp(y0, y1, i / 6)
            pts.push([cx + s * (fw(y) + 1), y])
          }
          const w2 = part === "burns" ? 11 : 28
          const inner = pts.map(([x, y], i) => [x - s * (w2 * (i / 6) + 7), y]).reverse()
          if (part === "chops") inner[0] = [cx + s * (hw * 1.25), mouthY + 4]
          add(pts.concat(inner), 3)
        }
      } else if (part === "horseshoe") {
        for (const s of [-1, 1]) add([[cx + s * hw * 0.85, mouthY - 2], [cx + s * hw * 1.12, mouthY - 3], [cx + s * hw * 1.15, chinY - 2], [cx + s * hw * 0.92, chinY - 2]], 2)
      } else if (part === "fumanchu") {
        for (const s of [-1, 1]) add([[cx + s * hw * 0.9, mouthY - 2], [cx + s * hw * 1.05, mouthY - 3], [cx + s * hw * 1.05, chinY + 35], [cx + s * hw * 0.95, chinY + 36]], 2)
      }
    }
    // barba de face inteira
    const hasChin = parts.includes("chin"), hasCheek = parts.includes("cheek") || parts.includes("cheekLow")
    if (hasChin || hasCheek) {
      const low = parts.includes("cheekLow")
      const topY = low ? mouthY : cheekTop
      const right = []
      for (let i = 0; i <= 10; i++) {
        const y = lerp(topY - 22, chinY, i / 10)
        right.push([cx + fw(y) + 1.5, y])
      }
      // borda da bochecha (linha da barba), da orelha até o canto da boca
      const cheekLine = hasCheek
        ? [[cx + fw(topY - 20) - 2, topY - 22], [cx + fw(topY) * 0.72, topY + 3], [cx + hw * 1.25, mouthY - lipU * 1.2], [cx + noseW * 0.55, noseY + 3]]
        : [[cx + hw * 1.1, mouthY - 2], [cx + hw * 1.1, mouthY - 2]]
      const pts = []
      const w0 = fw(chinY - 6)
      if (hasCheek) {
        right.forEach((q) => pts.push(q))
      } else {
        pts.push([cx + hw * 1.1, mouthY - 2])
      }
      lowPts(hasCheek ? Math.max(w0, L.chinW * 1.3) : hw * 1.05).forEach((q) => pts.push(q))
      if (hasCheek) right.slice().reverse().forEach(([x, y]) => pts.push([2 * cx - x, y]))
      else pts.push([cx - hw * 1.1, mouthY - 2])
      const cl = cheekLine.slice().reverse().map(([x, y]) => [2 * cx - x, y])
      cl.forEach((q) => pts.push(q))
      pts.push([cx, mouthY + lipL * 1.3])
      cheekLine.forEach((q) => pts.push(q))
      add(pts, 3)
    }
    if (parts.includes("neck")) {
      add([[cx - L.jawW * 0.7, L.jawY + 6], [cx + L.jawW * 0.7, L.jawY + 6], [cx + L.neckW * 0.42, chinY + 22], [cx, chinY + 30], [cx - L.neckW * 0.42, chinY + 22]])
    }
    return p
  }

  function drawBeard(ctx, g, L, style, col, greyFrac, age, res, mode, r) {
    const young = smooth(13, 24, age)
    let len = (style.len || 0.1) * (0.3 + young * 0.7)
    let density = g.hair.beardDensity * lerp(0.25, 1, young)
    if (style.fuzz || age < 17) density *= 0.5
    const stubble = style.stubble || (age < 18 ? 0.6 : 0)
    const pw = W * res, ph = H * res
    const mk = makeCanvas(pw, ph)
    const mc = mk.getContext("2d")
    mc.setTransform(res, 0, 0, res, 0, 0)
    mc.fillStyle = "#fff"
    const parts = style.parts
    const path = beardRegionPath(L, parts, stubble ? 0 : len, style)
    mc.fill(path, "nonzero")
    // tira os lábios
    mc.globalCompositeOperation = "destination-out"
    mc.fill(lipsPath(L))
    mc.globalCompositeOperation = "source-over"
    const md = mc.getImageData(0, 0, pw, ph).data
    const aAt = (x, y) => {
      const X = (x * res) | 0, Y = (y * res) | 0
      if (X < 0 || Y < 0 || X >= pw || Y >= ph) return 0
      return md[(Y * pw + X) * 4 + 3] / 255
    }
    const lay = makeCanvas(pw, ph)
    const lc = lay.getContext("2d")
    lc.setTransform(res, 0, 0, res, 0, 0)
    const br = makeRng(hash32(g.id + "beard" + style.id))
    const patchSeed = hash32(g.id + "patch") % 1000
    const patchy = (style.patchy || 0) + (1 - g.hair.beardDensity) * 0.8 + (1 - young) * 0.5
    const grey = [205, 202, 196]
    const colFor = () => {
      const isGrey = br() < greyFrac
      const base = isGrey ? mix(grey, [255, 255, 255], br() * 0.3) : mul(col, 0.7 + br() * 0.6)
      return base
    }
    const bb = path
    // bounding box grosseiro
    const x0 = L.cx - L.rx * 1.3, x1 = L.cx + L.rx * 1.3, y0 = L.noseY - 30, y1 = Math.min(H, L.chinY + len * L.Ht * 0.6 + 40)
    if (stubble || len < 0.06) {
      // barba curta: pontinhos
      lc.fillStyle = rgb(mix(mul(col, 0.8), [70, 72, 80], 0.3), 0.32 * density * (stubble || 0.5) + len * 2)
      lc.fill(bb)
      const n = Math.floor(16000 * density * (stubble || 0.5) * (mode === "real" ? 1 : 0.3))
      for (let i = 0; i < n; i++) {
        const x = lerp(x0, x1, br()), y = lerp(y0, y1, br())
        const a = aAt(x, y)
        if (a < 0.3) continue
        if (patchy > 0.3 && vnoise(x * 0.08, y * 0.08, patchSeed) < patchy * 0.5) continue
        const c = colFor()
        lc.fillStyle = rgb(c, 0.22 * a)
        const l = 0.5 + len * 14
        lc.fillRect(x, y, 0.5, l)
      }
    } else {
      // fios
      const flow = (x, y) => {
        const dx = x - L.cx
        if (y < L.mouthY && Math.abs(dx) < L.mouthW * 0.8) return [Math.sign(dx || 1) * 0.9, 0.7] // bigode
        return [dx / (L.rx * 2.2), 1]
      }
      lc.fillStyle = rgb(mul(col, 0.55), 0.85 * density)
      lc.fill(bb)
      const n = Math.floor(5200 * density * (mode === "real" ? 1 : 0.25) * (0.6 + len))
      const curl = clamp(C.phenotype(g, age).tex / 3) * 2.5 + (style.wild ? 2 : 0)
      for (let i = 0; i < n; i++) {
        const x = lerp(x0, x1, br()), y = lerp(y0, y1, br())
        const a = aAt(x, y)
        if (a < 0.2) continue
        if (patchy > 0.3 && vnoise(x * 0.08, y * 0.08, patchSeed) < patchy * 0.45) continue
        const c = colFor()
        const [fx, fy] = flow(x, y)
        const fl = Math.hypot(fx, fy)
        const l = (4 + br() * 8) * (0.5 + len * 1.4)
        const light = clamp(0.75 + (-(x - L.cx) / L.rx) * 0.2 - (y - L.mouthY) / 200)
        lc.strokeStyle = rgb(mul(c, light), 0.55 + br() * 0.4)
        lc.lineWidth = mode === "real" ? 0.6 + br() * 0.5 : 1.4
        lc.beginPath()
        lc.moveTo(x, y)
        const ex = x + (fx / fl) * l, ey = y + (fy / fl) * l
        lc.quadraticCurveTo((x + ex) / 2 + (br() - 0.5) * curl * 3, (y + ey) / 2 + (br() - 0.5) * curl * 2, ex + (br() - 0.5) * curl, ey)
        lc.stroke()
      }
    }
    lc.setTransform(1, 0, 0, 1, 0, 0)
    lc.globalCompositeOperation = "destination-in"
    lc.filter = `blur(${(stubble ? 1.2 : 0.8) * res}px)`
    lc.drawImage(mk, 0, 0)
    lc.filter = "none"
    ctx.save()
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.drawImage(lay, 0, 0)
    ctx.restore()
  }

  // =====================================================================
  // CABELO — geometria
  function buildHair(L, st, P, bald, age, r) {
    const { cx, rx, browY, y0, chinY, shoulderY, hairlineY, skullRy } = L
    const special = st.special
    const texBase = P.tex
    const tex = clamp(texBase + (st.curlBoost ? Math.max(0, st.curlBoost - texBase) * 0.8 : 0) + (st.wavyBoost ? Math.max(0, 1 - texBase) : 0), 0, 3)
    const young = smooth(0.8, 4, age)
    const volTex = tex > 1.5 ? (tex - 1.5) * 0.06 : 0
    let vt = Math.min((st.volTop + volTex) * rx * 2.9 * lerp(0.3, 1, young), y0 - 18)
    let vs = (st.volSide + volTex * 0.8) * rx * 2.2 * lerp(0.3, 1, young)
    const lenK = lerp(0.35, 1, smooth(1, 8, age))
    const ySide = (sv) => {
      sv *= lenK
      if (sv <= 0.5) return lerp(browY - 12, chinY, sv / 0.5)
      if (sv <= 1) return lerp(chinY, shoulderY + 12, (sv - 0.5) / 0.5)
      return lerp(shoulderY + 12, 560, (sv - 1) / 0.8)
    }
    let sideY = ySide(st.side ?? 0.1)
    if ((st.side ?? 0) >= 0.42 && !st.tucked && !st.tie) {
      const earMid = L.browY + 2 + L.earH / 2
      const earTip = C.faceHalfWidth(L, earMid) - 3 + L.earW * (0.8 + L.earOut) - rx
      vs = Math.max(vs, earTip + 4)
    }
    const backY = ySide(st.back ?? st.side ?? 0.1)
    const part = (st.part ?? 0.25) * (r.chance(0.5) ? 1 : -1)

    // calvície: sobe a linha do cabelo e abre as entradas
    const recede = bald * 0.9
    const hlY = hairlineY - recede * (hairlineY - y0) * 0.55
    const templeInX = rx * (0.72 - recede * 0.25)
    const templeY = lerp(hairlineY + (browY - hairlineY) * 0.35, y0 + skullRy * 0.35, recede)
    const horseshoe = special === "horseshoe" || bald > 0.78
    const crownThin = special === "thin" ? 0.5 : clamp((bald - 0.45) * 1.6)

    const geo = { tex, style: st, flyaways: tex < 2.2, density: P ? 1 : 1, vt, vs, cx, part, sideY, backY, crownThin, horseshoe, hlY, L }

    const outerPoint = (theta, vtop, vside) => {
      const k = theta / (Math.PI / 2)
      const v = lerp(vtop, vside, Math.pow(k, 0.8))
      return [Math.sin(theta) * (rx + v), browY - Math.cos(theta) * (skullRy + v)]
    }

    // raspados/penugem/tranças nagô: só a calota
    const capOnly = special === "shaved" || special === "buzz" || special === "fuzz" || special === "cornrows" || special === "mohawk"
    const capPath = (inflate = 1.5) => {
      const p = new Path2D()
      const pts = []
      for (let i = 0; i <= 12; i++) {
        const th = -Math.PI / 2 + (i / 12) * Math.PI
        const [x, y] = outerPoint(Math.abs(th), inflate, inflate)
        pts.push([cx + Math.sign(th) * x, y])
      }
      // desce até acima da orelha
      pts.push([cx + rx + inflate, browY + 4])
      pts.push([cx + rx * 0.97, browY + 16])
      pts.push([cx + templeInX + 2, templeY + 2])
      pts.push([cx + rx * 0.25, hlY + 3])
      pts.push([cx, hlY + (recede > 0.2 ? 0 : 4)])
      pts.push([cx - rx * 0.25, hlY + 3])
      pts.push([cx - templeInX - 2, templeY + 2])
      pts.push([cx - rx * 0.97, browY + 16])
      pts.push([cx - rx - inflate, browY + 4])
      pts.reverse()
      const c = C.catmull(pts, true, 4)
      c.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)))
      p.closePath()
      return p
    }

    if (capOnly) {
      geo.kind = special
      geo.front = (mc) => {
        if (special === "mohawk") {
          const p = new Path2D()
          const w = rx * 0.22
          p.moveTo(cx - w, hlY + 4)
          p.bezierCurveTo(cx - w * 1.1, y0 - vt * 0.6, cx - w * 0.4, y0 - vt * 1.1, cx, y0 - vt)
          p.bezierCurveTo(cx + w * 0.4, y0 - vt * 1.1, cx + w * 1.1, y0 - vt * 0.6, cx + w, hlY + 4)
          p.closePath()
          mc.fill(p)
          mc.globalAlpha = 0.35
          mc.fill(capPath(0.5))
          mc.globalAlpha = 1
        } else mc.fill(capPath(special === "fuzz" ? 0.5 : 1.5))
      }
      return geo
    }

    // ---- massa da frente (calota + laterais) ----
    const frontMass = (mc) => {
      const pts = []
      const N = 14
      // contorno externo: lado esquerdo de baixo até o topo e desce pela direita
      const side = (s) => {
        const arr = []
        for (let i = 0; i <= N; i++) {
          const th = (i / N) * (Math.PI / 2)
          const [x, y] = outerPoint(th, vt, vs)
          arr.push([cx + s * x, y])
        }
        return arr // do topo para o lado
      }
      const R = side(1), Lft = side(-1)
      const sideBottom = horseshoe ? Math.min(Math.max(sideY, browY + 10), L.noseY - 10) : Math.max(sideY, browY - 8)
      const outerDown = (s) => {
        const arr = []
        const steps = 10
        const jr = makeRng(hash32(st.id + s))
        for (let i = 1; i <= steps; i++) {
          const y = lerp(browY, sideBottom, i / steps)
          let x = rx + vs
          if (y > L.jawY) {
            // cai rente ao maxilar e abre sobre os ombros
            const k = clamp((y - L.jawY) / Math.max(1, shoulderY - L.jawY))
            const drape = L.neckW * 0.5 + (L.shoulderW * 0.5 - L.neckW * 0.5) * (st.sideSwept ? 0.35 : 0.5)
            x = lerp(rx + vs - 2, Math.max(drape, rx + vs * 0.6), smooth(0, 1, k)) + tex * 4 * k
          }
          if (y > shoulderY) x = Math.min(x + (y - shoulderY) * 0.12, L.shoulderW * 0.56)
          if (st.layered && y > chinY) x *= 1 - ((y - chinY) / (sideBottom - chinY + 1)) * 0.1
          arr.push([cx + s * (x + (tex > 1 ? Math.sin(i * 1.7) * tex : 0) + (jr() - 0.5) * 2), y])
        }
        // pontas irregulares
        if (sideBottom > chinY) {
          const last = arr[arr.length - 1]
          const inner = L.neckW * 0.5 + 8
          const n = 5
          for (let k = 1; k <= n; k++) {
            const t = k / (n + 1)
            const x = lerp(Math.abs(last[0] - cx), inner, t)
            arr.push([cx + s * x, sideBottom + (k % 2 ? 6 + jr() * 10 : -4 - jr() * 6) * (st.layered ? 1.6 : 1) - t * 8])
          }
        }
        return arr
      }
      const innerUp = (s) => {
        const arr = []
        const steps = 8
        const inset = st.tucked ? -4 : sideBottom > chinY ? 3 : 1
        for (let i = steps; i >= 0; i--) {
          const y = lerp(browY + 6, sideBottom, i / steps)
          let x = C.faceHalfWidth(L, y) - inset
          if (y > chinY - 4) x = L.neckW * 0.5 + 6
          if (sideBottom <= browY + 20) x = rx * 0.97
          arr.push([cx + s * Math.max(x, L.neckW * 0.4), y])
        }
        return arr
      }
      // linha do cabelo (frente)
      const hairline = [
        [cx + s1(rx * 0.95), browY - 2],
        [cx + templeInX, templeY],
        [cx + rx * 0.35, hlY + 2],
        [cx, hlY + (recede < 0.2 ? 3 : 0)],
        [cx - rx * 0.35, hlY + 2],
        [cx - templeInX, templeY],
        [cx - rx * 0.95, browY - 2],
      ]
      function s1(v) { return v }
      if (horseshoe) {
        // só laterais e nuca, rentes à cabeça
        vs = Math.min(vs, rx * 0.06)
        for (const s of [-1, 1]) {
          const p = []
          const topY = browY - skullRy * 0.42
          p.push([cx + s * (rx * 0.9), topY])
          p.push([cx + s * (rx + vs + 1), topY + 6])
          outerDown(s).forEach((q) => p.push(q))
          innerUp(s).forEach((q) => p.push(q))
          p.push([cx + s * rx * 0.8, browY - 8])
          mc.fill(pathFrom(C.catmull(p, true, 4)))
        }
        return
      }
      Lft.slice().reverse().forEach((q) => pts.push(q)) // lado -> topo (esquerda)
      pts.pop()
      R.forEach((q) => pts.push(q)) // topo -> lado (direita)
      const ptsFull = [...outerDown(-1).reverse(), ...pts, ...outerDown(1), ...innerUp(1), ...hairline, ...innerUp(-1).reverse()]
      mc.fill(pathFrom(C.catmull(ptsFull, true, 3)))
    }

    const fringe = (mc) => {
      const f = st.fringe
      if (!f || f === "back" || horseshoe) return
      const fl = st.fringeLen ?? 0.2
      let yB = lerp(hlY, L.eyeY + 4, fl / 0.5)
      if (fl < 0.5 || age < 12) yB = Math.min(yB, L.browY - 3)
      const wT = rx * 0.9
      const p = new Path2D()
      if (f === "straight") {
        p.moveTo(cx - wT, hlY - 10)
        p.lineTo(cx + wT, hlY - 10)
        p.lineTo(cx + rx * 0.86, Math.min(yB, browY + 20) - 6)
        const n = 10
        for (let i = 0; i <= n; i++) p.lineTo(cx + rx * 0.86 - (i / n) * rx * 1.72, yB + Math.sin(i * 2.1) * 1.5 - (i === 0 || i === n ? 5 : 0))
        p.closePath()
      } else if (f === "side" || f === "swept" || f === "wisp") {
        const d = Math.sign(part || 1)
        const low = f === "swept" ? lerp(hlY, browY, 0.35) : yB
        p.moveTo(cx + d * rx * 0.3, hlY - 12)
        p.bezierCurveTo(cx - d * rx * 0.3, hlY - 6, cx - d * rx * 0.75, low - 10, cx - d * rx * 0.98, low)
        p.lineTo(cx - d * rx * 0.99, hlY - 10)
        p.closePath()
        if (f === "swept") {
          p.moveTo(cx + d * rx * 0.25, hlY - 14)
          p.quadraticCurveTo(cx - d * rx * 0.1, hlY - 16 - vt * 0.5, cx - d * rx * 0.7, hlY + 4)
          p.lineTo(cx - d * rx * 0.5, hlY - 10)
          p.closePath()
        }
      } else if (f === "curtain") {
        for (const s of [-1, 1]) {
          p.moveTo(cx + s * 2, hlY - 8)
          p.bezierCurveTo(cx + s * rx * 0.2, hlY + 4, cx + s * rx * 0.55, yB - 8, cx + s * rx * 0.98, yB + 6)
          p.lineTo(cx + s * rx * 0.98, hlY)
          p.closePath()
        }
      } else if (f === "spiky") {
        p.moveTo(cx - rx * 0.9, hlY - 6)
        const n = 9
        for (let i = 0; i <= n; i++) {
          const x = cx - rx * 0.85 + (i / n) * rx * 1.7
          p.lineTo(x - rx * 0.06, hlY - 2)
          p.lineTo(x + (i % 2 ? 3 : -2), yB + (i % 3) * 3)
        }
        p.lineTo(cx + rx * 0.9, hlY - 6)
        p.closePath()
      } else if (f === "quiff" || f === "pomp") {
        const h = vt * (f === "pomp" ? 1.25 : 1.1)
        p.moveTo(cx - rx * 0.62, hlY + 2)
        p.bezierCurveTo(cx - rx * 0.7, hlY - h * 1.2, cx + rx * 0.2, hlY - h * 1.6, cx + rx * 0.62, hlY - h * 0.6)
        p.lineTo(cx + rx * 0.62, hlY + 2)
        p.closePath()
      }
      mc.fill(p)
    }

    const backMass = (mc) => {
      const b = Math.max(backY, sideY)
      if (b < chinY - 10 && !st.tie) return
      const p = []
      const topY = browY - skullRy * 0.2
      for (const s of [1]) {
        p.push([cx + s * (rx + vs * 0.9), topY])
      }
      const wBot = Math.min(L.shoulderW * 0.5, rx + vs + (b - chinY) * 0.35 + tex * 6)
      p.push([cx + rx + vs * 0.95, chinY])
      p.push([cx + wBot, b - 6])
      p.push([cx + wBot * 0.6, b + (tex > 1 ? 4 : 0)])
      p.push([cx, b - 4])
      p.push([cx - wBot * 0.6, b + (tex > 1 ? 4 : 0)])
      p.push([cx - wBot, b - 6])
      p.push([cx - rx - vs * 0.95, chinY])
      p.push([cx - (rx + vs * 0.9), topY])
      p.push([cx, browY - skullRy])
      if (st.tie !== "ponytail" && st.tie !== "bun" && st.tie !== "topknot" && st.tie !== "pigtails" && st.tie !== "braids" && st.tie !== "puffs" && st.tie !== "afropuff" && st.tie !== "sidebraid")
        mc.fill(pathFrom(C.catmull(p, true, 4)))
    }

    geo.front = (mc) => {
      if (special === "afro") {
        // massa redonda
        const p = new Path2D()
        const R0 = rx + vs
        const top = y0 - vt
        const bot = Math.max(sideY, browY + 20)
        const pts = []
        for (let i = 0; i <= 24; i++) {
          const a = -Math.PI + (i / 24) * Math.PI
          pts.push([cx + Math.cos(a) * R0 * 1.02, lerp(browY, top, Math.sin(-a)) + (1 - Math.sin(-a)) * 0])
        }
        pts.push([cx + R0 * 0.95, bot])
        pts.push([cx + rx * 0.96, bot - 4])
        pts.push([cx + rx * 0.95, browY])
        pts.push([cx + templeInX, templeY])
        pts.push([cx, hlY + 3])
        pts.push([cx - templeInX, templeY])
        pts.push([cx - rx * 0.95, browY])
        pts.push([cx - rx * 0.96, bot - 4])
        pts.push([cx - R0 * 0.95, bot])
        const c = C.catmull(pts, true, 4)
        c.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)))
        p.closePath()
        mc.fill(p)
        return
      }
      frontMass(mc)
      fringe(mc)
      // amarrações visíveis de frente
      const t = st.tie
      if (t === "bun" || t === "messybun") {
        mc.beginPath()
        mc.ellipse(cx + part * 4, y0 - rx * 0.18, rx * 0.34, rx * 0.26, 0, 0, Math.PI * 2)
        mc.fill()
      } else if (t === "topknot") {
        mc.beginPath()
        mc.ellipse(cx, y0 - rx * 0.1, rx * 0.22, rx * 0.17, 0, 0, Math.PI * 2)
        mc.fill()
      } else if (t === "afropuff") {
        mc.beginPath()
        mc.ellipse(cx, y0 - rx * 0.28, rx * 0.62, rx * 0.42, 0, 0, Math.PI * 2)
        mc.fill()
      } else if (t === "puffs") {
        for (const s of [-1, 1]) {
          mc.beginPath()
          mc.ellipse(cx + s * rx * 0.72, y0 + rx * 0.1, rx * 0.36, rx * 0.34, 0, 0, Math.PI * 2)
          mc.fill()
        }
      } else if (t === "pigtails") {
        for (const s of [-1, 1]) {
          const p = new Path2D()
          const ax = cx + s * (rx + 4), ay = browY - 18
          p.moveTo(ax, ay - 10)
          p.bezierCurveTo(ax + s * 34, ay - 6, ax + s * 38, ay + 60 * lenK, ax + s * 16, ay + (70 + 40 * st.len) * lenK)
          p.bezierCurveTo(ax + s * 4, ay + 50, ax - s * 2, ay + 10, ax, ay - 10)
          mc.fill(p)
        }
      } else if (t === "braids" || t === "sidebraid") {
        const sides = t === "braids" ? [-1, 1] : [Math.sign(part || 1)]
        for (const s of sides) {
          const x0 = cx + s * (rx * 0.92), yA = browY + 12
          const yEnd = Math.min(ySide(st.len), 520)
          for (let y = yA; y < yEnd; y += 9) {
            const k = (y - yA) / (yEnd - yA + 1)
            const x = y < L.jawY ? cx + s * (C.faceHalfWidth(L, y) + 8) : lerp(cx + s * (C.faceHalfWidth(L, L.jawY) + 8), cx + s * (L.neckW * 0.5 + 16), clamp((y - L.jawY) / 40))
            mc.beginPath()
            mc.ellipse(x, y, 10 - k * 3, 7, 0, 0, Math.PI * 2)
            mc.fill()
          }
        }
      } else if (t === "halfup") {
        // já coberto pela massa longa
      }
    }
    geo.back = (mc) => {
      if (special === "afro") return
      backMass(mc)
      if (st.tie === "ponytail" || st.tie === "lowtail") {
        const s = Math.sign(part || 1)
        const p = new Path2D()
        const topY = st.tie === "ponytail" ? browY - skullRy * 0.5 : chinY - 10
        p.moveTo(cx + s * rx * 0.6, topY)
        p.bezierCurveTo(cx + s * (rx + 30), topY + 20, cx + s * (rx + 24), chinY + 40, cx + s * (L.neckW * 0.5 + 18), ySide(st.len) - 20)
        p.lineTo(cx + s * (L.neckW * 0.5 + 4), chinY + 30)
        p.closePath()
        mc.fill(p)
      }
      if (st.tie === "lowbun") {
        for (const s of [-1, 1]) {
          mc.beginPath()
          mc.ellipse(cx + s * (L.neckW * 0.55 + 10), chinY + 4, 16, 14, 0, 0, Math.PI * 2)
          mc.fill()
        }
      }
    }
    // especiais que desenham textura própria
    if (special === "locs" || special === "boxbraids" || special === "twists") geo.kind = special
    if (special === "flattop") {
      const f = geo.front
      geo.front = (mc) => {
        mc.save()
        mc.beginPath()
        mc.rect(0, y0 - vt * 0.55, W, H)
        mc.clip()
        f(mc)
        mc.restore()
      }
    }
    return geo
  }

  function hairPalette(base, greyFrac, geo) {
    return { base, greyFrac, grey: [206, 204, 200], white: [236, 234, 230] }
  }

  // =====================================================================
  // CABELO — pintura (fios)
  function paintHair(lc, geo, layer, alphaAt, cols, mode, res, r) {
    const L = geo.L
    const { cx, rx, browY, y0 } = L
    const tex = geo.tex
    const st = geo.style
    const hr = makeRng(hash32(L.cx + ":" + st.id + layer + geo.part))
    const x0 = 0, x1 = W, yA = Math.max(0, y0 - geo.vt - 60), yB = H
    const pickCol = (x, y, k = 1, single = false) => {
      const g = single && hr() < cols.greyFrac
      let c = g ? mix(cols.grey, cols.white, hr()) : mix(mul(cols.base, 0.8 + hr() * 0.4), mix(cols.grey, cols.white, 0.4), cols.greyFrac * (0.75 + hr() * 0.25))
      // iluminação: vem de cima-esquerda
      const nx = (x - cx) / (rx + geo.vs + 10), ny = (y - (browY - 20)) / (L.skullRy + geo.vt + 10)
      const lit = clamp(0.62 + (-nx * 0.35 - ny * 0.45) * 0.7)
      const back = layer === "back" ? 0.55 : 1
      c = mul(c, (0.45 + lit * 0.85) * back * k)
      // brilho especular numa faixa da calota
      const band = Math.exp(-Math.pow((Math.hypot(nx + 0.25, ny + 0.55) - 0.55) * 5, 2))
      if (!g) c = mix(c, [255, 245, 230], band * 0.22 * (1 - tex * 0.2))
      return c
    }
    // base
    lc.save()
    lc.fillStyle = rgb(mix(mul(cols.base, layer === "back" ? 0.42 : 0.62), mul(cols.grey, 0.7), cols.greyFrac * 0.85), 1)
    const thin = geo.crownThin
    if (geo.kind === "shaved" || geo.kind === "buzz" || geo.kind === "fuzz") {
      const k = geo.kind === "shaved" ? 0.12 : geo.kind === "buzz" ? 0.35 : 0.25
      lc.fillStyle = rgb(mix(cols.base, [120, 120, 120], cols.greyFrac * 0.6), k)
      lc.fillRect(0, 0, W, H)
      const n = geo.kind === "fuzz" ? 1500 : 9000
      for (let i = 0; i < n; i++) {
        const x = hr() * W, y = yA + hr() * (browY + 30 - yA)
        const a = alphaAt(x, y)
        if (a < 0.2) continue
        const c = pickCol(x, y)
        lc.fillStyle = rgb(c, (geo.kind === "fuzz" ? 0.35 : 0.55) * a)
        lc.fillRect(x, y, 0.8, geo.kind === "shaved" ? 0.8 : 1.6)
      }
      lc.restore()
      return
    }
    if (geo.kind === "cornrows") {
      lc.fillStyle = rgb(mul(cols.base, 0.45), 0.9)
      lc.fillRect(0, 0, W, H)
      const rows = 9
      for (let i = 0; i < rows; i++) {
        const t = (i + 0.5) / rows
        const xs = cx + (t - 0.5) * rx * 1.7
        for (let k = 0; k < 16; k++) {
          const v = k / 16
          const x = lerp(xs, cx + (t - 0.5) * rx * 0.6, v)
          const y = lerp(geo.hlY + 4, y0 - 4, v)
          lc.fillStyle = rgb(pickCol(x, y, 1.1), 0.95)
          lc.beginPath()
          lc.ellipse(x, y, 4.6, 3.2, (t - 0.5) * 0.9 + 0.6, 0, Math.PI * 2)
          lc.fill()
        }
      }
      lc.restore()
      return
    }
    lc.fillRect(0, 0, W, H)
    if (thin > 0 && layer === "front") {
      // couro cabeludo aparecendo no topo
      lc.globalCompositeOperation = "destination-out"
      const gr = lc.createRadialGradient(cx, y0 + 10, 0, cx, y0 + 10, rx * 0.9)
      gr.addColorStop(0, `rgba(0,0,0,${0.9 * thin})`)
      gr.addColorStop(1, "rgba(0,0,0,0)")
      lc.fillStyle = gr
      lc.fillRect(0, 0, W, H)
      lc.globalCompositeOperation = "source-over"
    }

    // textura afro/crespa: miríade de cachinhos
    if (tex > 2.2 || geo.kind === "twists") {
      const n = Math.floor(mode === "real" ? 26000 : 3000)
      for (let i = 0; i < n; i++) {
        const x = x0 + hr() * (x1 - x0), y = yA + hr() * (yB - yA)
        const a = alphaAt(x, y)
        if (a < 0.1) continue
        if (thin > 0 && Math.hypot(x - cx, y - y0 - 10) < rx * 0.7 && hr() < thin) continue
        const c = pickCol(x, y)
        lc.strokeStyle = rgb(c, 0.5 + hr() * 0.4)
        lc.lineWidth = mode === "real" ? 0.7 : 1.4
        const rr = geo.kind === "twists" ? 2.6 : 1.2 + hr() * 1.8
        lc.beginPath()
        const s0 = hr() * Math.PI * 2
        lc.arc(x, y, rr, s0, s0 + Math.PI * (1 + hr()))
        lc.stroke()
      }
      if (geo.kind === "twists") {
        for (let i = 0; i < 260; i++) {
          const x = x0 + hr() * (x1 - x0), y = yA + hr() * (browY - yA)
          if (alphaAt(x, y) < 0.5) continue
          const c = pickCol(x, y, 1.1)
          lc.strokeStyle = rgb(c, 0.9)
          lc.lineWidth = 3
          const ang = Math.atan2(y - (browY + 20), x - cx)
          lc.beginPath()
          lc.moveTo(x, y)
          lc.lineTo(x + Math.cos(ang) * 8, y + Math.sin(ang) * 8)
          lc.stroke()
        }
      }
      lc.restore()
      return
    }

    if (geo.kind === "locs" || geo.kind === "boxbraids") {
      const thick = geo.kind === "locs" ? 5.5 : 3.6
      const n = geo.kind === "locs" ? 70 : 130
      for (let i = 0; i < n; i++) {
        const t = hr()
        const sx = cx + (t - 0.5) * (rx + geo.vs) * 2.1
        const topY = browY - Math.sqrt(Math.max(0, 1 - Math.pow((sx - cx) / (rx + geo.vs + 2), 2))) * (L.skullRy + geo.vt) + 6
        const endY = geo.sideY + hr() * 20
        let x = sx
        const dir = Math.sign(sx - cx)
        for (let y = topY; y < endY; y += thick * 0.8) {
          const k = (y - topY) / (endY - topY)
          if (y < browY) x = sx + dir * (y - topY) * 0.25
          else x += dir * 0.15 + (hr() - 0.5) * 0.6
          if (alphaAt(x, y) < 0.3) continue
          const c = pickCol(x, y, 0.9 + (Math.floor(y / thick) % 2) * 0.25)
          lc.fillStyle = rgb(c, 0.95)
          lc.beginPath()
          lc.ellipse(x, y, thick * (1 - k * 0.15), thick * 0.7, geo.kind === "boxbraids" ? ((Math.floor(y / thick) % 2) - 0.5) * 0.8 : 0, 0, Math.PI * 2)
          lc.fill()
        }
      }
      lc.restore()
      return
    }

    // fios: seguem um campo de direção
    const partX = cx + geo.part * rx * 0.9
    const partY = y0 - 14
    const slick = st.slick || st.fringe === "back"
    const flow = (x, y) => {
      let dx, dy
      if (y < browY - 4) {
        if (slick) {
          dx = (cx - x) * 0.3
          dy = -(y - y0 + 30)
        } else {
          dx = x - partX
          dy = y - partY + 12
        }
        const gw = clamp((y - (y0 + 20)) / 60)
        const n = Math.hypot(dx, dy) || 1
        dx = dx / n
        dy = dy / n
        dx = lerp(dx, dx * 0.4, gw)
        dy = lerp(dy, 1, gw)
      } else {
        dx = (x - cx) * 0.004 * (tex + 0.5)
        dy = 1
      }
      // franja cai para baixo
      if (st.fringe && st.fringe !== "back" && Math.abs(x - cx) < rx * 0.9 && y > geo.hlY - 14 && y < L.eyeY + 10) {
        const side = st.fringe === "side" || st.fringe === "swept" ? -Math.sign(geo.part || 1) : st.fringe === "curtain" ? Math.sign(x - cx) : 0
        dx = side * 0.6
        dy = st.fringe === "quiff" || st.fringe === "pomp" ? -0.8 : 1
      }
      const n = Math.hypot(dx, dy) || 1
      return [dx / n, dy / n]
    }
    const wave = tex < 0.4 ? 0.4 : tex < 1.4 ? 0.4 + (tex - 0.4) * 3 : 3.4 + (tex - 1.4) * 3
    const period = tex < 1.4 ? 64 - tex * 16 : 34 - (tex - 1.4) * 12
    const long = geo.sideY > L.chinY
    const seedN = hash32(st.id) % 997
    // coleta sementes dentro da máscara
    const seeds = []
    const want = Math.floor((mode === "real" ? (long ? 1100 : 650) : long ? 170 : 110) * (layer === "back" ? 0.7 : 1))
    let guard = 0
    while (seeds.length < want && guard++ < want * 60) {
      const x = x0 + hr() * (x1 - x0), y = yA + hr() * (yB - yA)
      if (alphaAt(x, y) < 0.4) continue
      if (thin > 0 && y < browY - L.skullRy * 0.3 && hr() < thin * 0.85) continue
      seeds.push([x, y])
    }
    // mechas de baixo primeiro; as de cima (raiz mais alta) ficam por cima
    seeds.sort((a, b) => b[1] - a[1])
    const step = 2
    const spine = (x, y, len, phase) => {
      const pts = []
      let px = x, py = y
      for (let s = 0; s < len; s += step) {
        const [fx, fy] = flow(px, py)
        const off = wave * Math.sin((py / period) * Math.PI * 2 + vnoise(px * 0.02, 0, seedN) * 3 + phase * 0.15)
        pts.push([px - fy * off, py + fx * off, fx, fy])
        px += fx * step
        py += fy * step
        if (alphaAt(px, py) < 0.05) break
      }
      return pts
    }
    const ribbon = (pts, w0) => {
      const left = [], right = []
      const n = pts.length
      for (let k = 0; k < n; k++) {
        const t = k / (n - 1)
        const taper = Math.min(1, t * 6 + 0.35) * (1 - t * 0.75)
        const [x, y, fx, fy] = pts[k]
        const w = (w0 / 2) * taper
        left.push([x - fy * w, y + fx * w])
        right.push([x + fy * w, y - fx * w])
      }
      const p = new Path2D()
      p.moveTo(left[0][0], left[0][1])
      for (let k = 1; k < n; k++) p.lineTo(left[k][0], left[k][1])
      for (let k = n - 1; k >= 0; k--) p.lineTo(right[k][0], right[k][1])
      p.closePath()
      return p
    }
    for (const [x, y] of seeds) {
      const len = (long ? 50 + hr() * 110 : 12 + hr() * 26) * (layer === "back" ? 1.3 : 1) * (tex > 1.4 ? 0.8 : 1)
      const phase = vnoise(x * 0.03, y * 0.01, seedN) * Math.PI * 4 + hr() * 0.8
      const pts = spine(x, y, len, phase)
      if (pts.length < 3) continue
      const mid = pts[pts.length >> 1]
      const c = pickCol(mid[0], mid[1])
      const cw = (long ? 5 + hr() * 7 : 3 + hr() * 4) * (1 + tex * 0.12) * (mode === "real" ? 1 : 1.6)
      lc.fillStyle = rgb(mul(c, 0.88), 0.92)
      lc.fill(ribbon(pts, cw))
      lc.fillStyle = rgb(mul(c, 1.05), 0.55)
      lc.fill(ribbon(pts, cw * 0.45))
      if (mode === "real") {
        const nf = 2 + ((hr() * 3) | 0)
        for (let f = 0; f < nf; f++) {
          const o = (hr() - 0.5) * cw * 0.8
          const cc = hr() < cols.greyFrac ? mix(cols.grey, cols.white, hr()) : hr() < 0.5 ? mul(c, 1.25) : mul(c, 0.7)
          lc.strokeStyle = rgb(cc, 0.35 + hr() * 0.35)
          lc.lineWidth = 0.35 + hr() * 0.4
          lc.beginPath()
          for (let k = 0; k < pts.length; k++) {
            const [px, py, fx, fy] = pts[k]
            const t = k / (pts.length - 1)
            const xx = px - fy * o * (1 - t * 0.6), yy = py + fx * o * (1 - t * 0.6)
            k ? lc.lineTo(xx, yy) : lc.moveTo(xx, yy)
          }
          lc.stroke()
        }
      }
    }
    // fios finos soltos por cima (textura)
    if (mode === "real") {
      for (let i = 0; i < 900; i++) {
        const x = x0 + hr() * (x1 - x0), y = yA + hr() * (yB - yA)
        if (alphaAt(x, y) < 0.5) continue
        const pts = spine(x, y, long ? 30 + hr() * 60 : 8 + hr() * 14, vnoise(x * 0.03, y * 0.01, seedN) * Math.PI * 4)
        if (pts.length < 2) continue
        lc.strokeStyle = rgb(pickCol(x, y, 1.2, true), 0.3)
        lc.lineWidth = 0.35
        lc.beginPath()
        pts.forEach(([px, py], k) => (k ? lc.lineTo(px, py) : lc.moveTo(px, py)))
        lc.stroke()
      }
    }
    // degradê: laterais raspadas com transição
    if (st.fade && layer === "front") {
      const fz = clamp(st.fade / 1.5)
      const topCut = browY - L.skullRy * (0.25 + fz * 0.4)
      lc.globalCompositeOperation = "destination-out"
      for (const s of [-1, 1]) {
        const gx = lc.createLinearGradient(cx + s * rx * 0.55, 0, cx + s * rx * 0.85, 0)
        gx.addColorStop(0, "rgba(0,0,0,0)")
        gx.addColorStop(1, "rgba(0,0,0,1)")
        lc.fillStyle = gx
        lc.fillRect(s < 0 ? 0 : cx, topCut, W / 2, H)
      }
      const gy = lc.createLinearGradient(0, topCut - 30, 0, topCut)
      lc.globalCompositeOperation = "destination-in"
      gy.addColorStop(0, "rgba(0,0,0,1)")
      gy.addColorStop(1, "rgba(0,0,0,1)")
      lc.globalCompositeOperation = "source-over"
      // pontinhos do cabelo raspado
      for (let i = 0; i < 5000; i++) {
        const x = hr() * W, y = topCut - 30 + hr() * (browY + 20 - topCut + 30)
        if (Math.abs(x - cx) < rx * 0.5 || alphaAt(x, y) < 0.3) continue
        lc.fillStyle = rgb(pickCol(x, y, 0.9), 0.4 * (1 - fz * 0.5))
        lc.fillRect(x, y, 0.6, 1.2)
      }
    }
    // sombra interna perto do rosto (oclusão)
    if (layer === "front") {
      const g2 = lc.createLinearGradient(0, L.eyeY - 30, 0, H)
      g2.addColorStop(0, "rgba(0,0,0,0)")
      g2.addColorStop(1, "rgba(0,0,0,0.35)")
      lc.fillStyle = g2
      lc.fillRect(0, 0, W, H)
    }
    lc.restore()
  }

  // penugem na linha do cabelo: transição suave entre couro cabeludo e testa
  function drawBabyHairs(ctx, geo, alphaAt, cols) {
    const L = geo.L
    const br = makeRng(hash32(L.cx + "baby" + geo.style.id))
    ctx.save()
    ctx.lineCap = "round"
    for (let i = 0; i < 420; i++) {
      const x = L.cx + (br() - 0.5) * L.rx * 2
      let y = geo.hlY - 20 + br() * (L.browY - geo.hlY + 20)
      if (alphaAt(x, y) < 0.5 || alphaAt(x, y + 4) > 0.4) continue
      const c = mul(cols.base, 0.8 + br() * 0.4)
      ctx.strokeStyle = rgb(c, 0.28 + br() * 0.25)
      ctx.lineWidth = 0.35 + br() * 0.3
      const dx = (x - L.cx) / L.rx
      ctx.beginPath()
      ctx.moveTo(x, y - 2)
      ctx.quadraticCurveTo(x + dx * 2, y + 2, x + dx * 3 + (br() - 0.5) * 2, y + 3 + br() * 4)
      ctx.stroke()
    }
    ctx.restore()
  }

  function drawFlyaways(ctx, geo, alphaAt, cols, r) {
    const L = geo.L
    const fr = makeRng(hash32(L.cx + "fly" + geo.style.id))
    ctx.save()
    ctx.lineWidth = 0.45
    for (let i = 0; i < 60; i++) {
      const x = L.cx + (fr() - 0.5) * (L.rx + geo.vs) * 2.3
      const y = L.y0 - geo.vt + fr() * 60
      if (alphaAt(x, y) > 0.2 || alphaAt(x, y + 5) < 0.5) continue
      const c = mul(cols.base, 0.9 + fr() * 0.5)
      ctx.strokeStyle = rgb(c, 0.35)
      ctx.beginPath()
      ctx.moveTo(x, y + 5)
      ctx.quadraticCurveTo(x + (fr() - 0.5) * 10, y - 4, x + (fr() - 0.5) * 16, y - 6 - fr() * 6)
      ctx.stroke()
    }
    ctx.restore()
  }

  // =====================================================================
  function drawGlasses(ctx, L, kind, r) {
    const w = L.eyeW
    const fr = makeRng(hash32(kind + L.cx))
    const frameCol = kind === "aviador" ? "rgba(190,170,120,0.95)" : kind === "grosso" ? "rgba(15,12,10,0.95)" : fr() < 0.5 ? "rgba(40,30,25,0.95)" : "rgba(90,60,40,0.95)"
    ctx.save()
    ctx.strokeStyle = frameCol
    ctx.lineWidth = kind === "grosso" ? 3.6 : kind === "aviador" ? 1.2 : 2
    for (const s of [-1, 1]) {
      const ex = L.cx + s * L.eyeOff, ey = L.eyeY + 2
      ctx.beginPath()
      if (kind === "redondo") ctx.arc(ex, ey, w * 0.62, 0, Math.PI * 2)
      else if (kind === "aviador") {
        ctx.moveTo(ex - s * w * 0.62, ey - w * 0.42)
        ctx.lineTo(ex + s * w * 0.66, ey - w * 0.45)
        ctx.quadraticCurveTo(ex + s * w * 0.75, ey + w * 0.55, ex + s * w * 0.1, ey + w * 0.62)
        ctx.quadraticCurveTo(ex - s * w * 0.6, ey + w * 0.4, ex - s * w * 0.62, ey - w * 0.42)
      } else if (kind === "gatinho") {
        ctx.moveTo(ex - s * w * 0.62, ey - w * 0.3)
        ctx.quadraticCurveTo(ex, ey - w * 0.55, ex + s * w * 0.78, ey - w * 0.58)
        ctx.quadraticCurveTo(ex + s * w * 0.6, ey + w * 0.5, ex, ey + w * 0.45)
        ctx.quadraticCurveTo(ex - s * w * 0.66, ey + w * 0.4, ex - s * w * 0.62, ey - w * 0.3)
      } else {
        const rw = w * 0.7, rh = w * (kind === "grosso" ? 0.5 : 0.44)
        ctx.roundRect(ex - rw, ey - rh, rw * 2, rh * 2, kind === "grosso" ? 6 : 4)
      }
      ctx.fillStyle = kind === "aviador" ? "rgba(60,70,60,0.28)" : "rgba(200,220,240,0.06)"
      ctx.fill()
      ctx.stroke()
      // reflexo
      ctx.save()
      ctx.clip()
      const g = ctx.createLinearGradient(ex - w, ey - w, ex + w, ey + w)
      g.addColorStop(0.3, "rgba(255,255,255,0)")
      g.addColorStop(0.42, "rgba(255,255,255,0.16)")
      g.addColorStop(0.5, "rgba(255,255,255,0)")
      ctx.fillStyle = g
      ctx.fillRect(ex - w, ey - w, w * 2, w * 2)
      ctx.restore()
      // haste
      ctx.beginPath()
      ctx.moveTo(ex + s * w * 0.66, ey - w * 0.25)
      ctx.lineTo(L.cx + s * (L.rx + 2), ey - w * 0.35)
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.moveTo(L.cx - L.eyeOff + w * 0.62, L.eyeY - 2)
    ctx.quadraticCurveTo(L.cx, L.eyeY - 7, L.cx + L.eyeOff - w * 0.62, L.eyeY - 2)
    ctx.stroke()
    ctx.restore()
  }

  root.FaceRender = { render, W, H }
})(typeof window !== "undefined" ? window : globalThis)
