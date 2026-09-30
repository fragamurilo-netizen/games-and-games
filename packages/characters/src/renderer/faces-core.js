// PARALELO — protótipo de rostos procedurais.
// Parte 1: RNG determinístico, genoma, herança e geometria por idade.
// Tudo aqui é puro (sem DOM) para depois virar packages/simulation + packages/ui.
;(function (root) {
  "use strict"

  // ---------- utilidades ----------
  const clamp = (x, a = 0, b = 1) => (x < a ? a : x > b ? b : x)
  const lerp = (a, b, t) => a + (b - a) * t
  const smooth = (a, b, x) => {
    const t = clamp((x - a) / (b - a))
    return t * t * (3 - 2 * t)
  }

  function hash32(str) {
    let h = 2166136261 >>> 0
    for (let i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i)
      h = Math.imul(h, 16777619)
    }
    return h >>> 0
  }

  // mulberry32 com helpers. Nunca Math.random (bíblia §38).
  function makeRng(seed) {
    let a = seed >>> 0
    const f = () => {
      a |= 0
      a = (a + 0x6d2b79f5) | 0
      let t = Math.imul(a ^ (a >>> 15), 1 | a)
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
    f.range = (lo, hi) => lo + (hi - lo) * f()
    f.normal = () => {
      let u = 0
      while (!u) u = f()
      return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * f())
    }
    f.z = (sd = 1) => clamp(f.normal() * sd, -2.6, 2.6)
    f.pick = (arr) => arr[Math.floor(f() * arr.length)]
    f.chance = (p) => f() < p
    return f
  }

  // ---------- genoma ----------
  // Traços contínuos guardados como z-scores (média 0, desvio 1).
  const Z_KEYS = [
    "faceW", "faceL", "jawW", "jawSq", "chinL", "chinW", "cheekB", "forehead", "skullH",
    "eyeSize", "eyeSpace", "eyeTilt", "eyeOpen", "eyeY", "lidFold", "hood",
    "browThick", "browArch", "browY", "browLen", "browGap",
    "noseL", "noseW", "noseBridge", "noseTip", "noseHook",
    "mouthW", "lipU", "lipL", "mouthY", "cupid",
    "earSize", "earOut", "neck",
  ]

  // Ideal de "beleza média" por sexo (atratividade emerge de proporção, simetria e pele).
  const IDEAL = {
    F: { eyeSize: 0.9, eyeOpen: 0.4, lipU: 0.7, lipL: 0.9, noseW: -0.6, noseL: -0.4, noseTip: -0.3, jawW: -0.5, jawSq: -0.6, cheekB: 0.9, chinW: -0.4, browThick: -0.2, browArch: 0.5, eyeTilt: 0.5, earSize: -0.3, earOut: -0.6 },
    M: { jawW: 0.8, jawSq: 0.9, cheekB: 0.7, chinL: 0.4, chinW: 0.3, browThick: 0.4, eyeSize: 0.2, noseW: -0.2, lipL: 0.3, eyeTilt: 0.3, earOut: -0.6, faceL: 0.2 },
  }
  const UGLY = {
    noseL: 1.6, noseW: 1.5, noseTip: 1.4, noseHook: 1.2, eyeSize: -1.4, eyeOpen: -1.0, earSize: 1.6, earOut: 1.8,
    chinL: -1.6, jawSq: -0.8, lipU: -1.2, lipL: -1.0, browGap: -1.8, forehead: 1.4, cheekB: -1.2, mouthW: 1.1,
  }

  const EYE_ALLELES = { blue: 0.05, gray: 0.15, green: 0.35, hazel: 0.55, brown: 0.8, dark: 0.97 }

  // Origem populacional grosseira: só enviesa a amostragem (pele, olhos, cabelo, dobra palpebral).
  const ANCESTRY = {
    euro: { mel: [0.1, 0.07], eye: [0.45, 0.3], hairEu: [0.5, 0.28], red: 0.12, tex: [0.45, 0.5], lid: 0.8, nose: 0.5, lips: -0.3 },
    afro: { mel: [0.78, 0.1], eye: [0.93, 0.04], hairEu: [0.95, 0.04], red: 0.0, tex: [2.6, 0.35], lid: 0.8, nose: -0.2, lips: 0.9 },
    east: { mel: [0.24, 0.06], eye: [0.92, 0.05], hairEu: [0.93, 0.05], red: 0.0, tex: [0.1, 0.2], lid: -1.4, nose: -0.6, lips: 0 },
    south: { mel: [0.5, 0.1], eye: [0.88, 0.08], hairEu: [0.9, 0.06], red: 0.0, tex: [0.7, 0.5], lid: 0.7, nose: 0.4, lips: 0.2 },
    latin: { mel: [0.36, 0.14], eye: [0.78, 0.18], hairEu: [0.82, 0.12], red: 0.02, tex: [1.0, 0.7], lid: 0.5, nose: 0.1, lips: 0.3 },
    mena: { mel: [0.3, 0.08], eye: [0.82, 0.12], hairEu: [0.88, 0.08], red: 0.03, tex: [1.1, 0.6], lid: 0.6, nose: 0.9, lips: 0.1 },
  }

  function makeGenome(seed, opts = {}) {
    const r = makeRng(typeof seed === "number" ? seed : hash32(String(seed)))
    const sex = opts.sex || (r.chance(0.5) ? "F" : "M")
    const ancestry = opts.ancestry || r.pick(Object.keys(ANCESTRY))
    const anc = ANCESTRY[ancestry]
    const z = {}
    for (const k of Z_KEYS) z[k] = r.z()
    z.lidFold = clamp(anc.lid + r.z(0.6), -2.6, 2.6)
    z.noseBridge = clamp(anc.nose + r.z(0.8), -2.6, 2.6)
    z.lipU = clamp(z.lipU * 0.8 + anc.lips, -2.6, 2.6)
    z.lipL = clamp(z.lipL * 0.8 + anc.lips, -2.6, 2.6)
    if (anc === ANCESTRY.afro) z.noseW = clamp(z.noseW * 0.7 + 0.9, -2.6, 2.6)
    if (anc === ANCESTRY.east) z.noseBridge = clamp(z.noseBridge - 0.3, -2.6, 2.6)

    const beauty = opts.beauty ?? 0 // -1 feio ... +1 bonito
    if (beauty > 0) {
      const ideal = IDEAL[sex]
      for (const k of Z_KEYS) z[k] = lerp(z[k], ideal[k] ?? 0, beauty * 0.75)
    } else if (beauty < 0) {
      const b = -beauty
      for (const k of Object.keys(UGLY)) if (r.chance(0.6)) z[k] = clamp(lerp(z[k], UGLY[k] * (1.1 + r() * 0.9), b), -3.8, 3.8)
    }

    const allele = (m, sd) => clamp(m + r.normal() * sd)
    const eyeA = () => {
      const base = allele(anc.eye[0], anc.eye[1])
      return base
    }
    const g = {
      id: String(seed),
      sex,
      z,
      asym: clamp(Math.abs(r.normal()) * 0.35 + (beauty < 0 ? -beauty * 0.9 : 0) - (beauty > 0 ? beauty * 0.3 : 0), 0.02, 1.4),
      asymSeed: Math.floor(r() * 1e9),
      skin: {
        mel: [allele(anc.mel[0], anc.mel[1]), allele(anc.mel[0], anc.mel[1])],
        under: r.z(0.8), // -: oliva/amarelado, +: rosado
        rosy: clamp(0.3 + r.normal() * 0.2),
        freckle: [r() < 0.25 ? r() : 0, r() < 0.25 ? r() : 0],
        quality: clamp(0.75 + r.normal() * 0.15 + beauty * 0.25),
        aging: clamp(1 + r.normal() * 0.15, 0.7, 1.4), // velocidade de envelhecimento da pele
        moles: Math.floor(r() * 6 + (r() < 0.2 ? 6 : 0)),
      },
      eye: { dark: [eyeA(), eyeA()], green: [r(), r()] },
      hair: {
        eu: [allele(anc.hairEu[0], anc.hairEu[1]), allele(anc.hairEu[0], anc.hairEu[1])],
        red: [r.chance(anc.red * 2.2), r.chance(anc.red * 2.2)],
        tex: [clamp(anc.tex[0] + r.normal() * anc.tex[1], 0, 3), clamp(anc.tex[0] + r.normal() * anc.tex[1], 0, 3)],
        density: clamp(0.85 + r.normal() * 0.12, 0.45, 1),
        greyOnset: clamp(38 + r.normal() * 8, 22, 65),
        bald: sex === "M" ? clamp(r() * 1.1 - 0.1) : clamp(r() * 0.25 - 0.1),
        baldOnset: clamp(30 + r.normal() * 8, 19, 60),
        beardDensity: clamp(0.72 + r.normal() * 0.2, 0.15, 1),
        beardRed: clamp(r() * 0.35),
      },
      body: {
        fat: clamp(0.35 + r.normal() * 0.2), // tendência genética
        heightZ: r.z(),
      },
      pref: {}, // preferências de estilo, preenchidas abaixo
    }
    g.pref = defaultPrefs(g, r)
    if (opts.hair) g.pref.hair = opts.hair
    if (opts.beard) g.pref.beard = opts.beard
    Object.assign(g.body, bodyTraits(g))
    g.ancestry = { [ancestry]: 1 }
    return g
  }

  // Herança: metade de cada pai + mutação. Alelos de olho/cabelo são sorteados como na genética real.
  function childGenome(mother, father, seed, opts = {}) {
    const r = makeRng(typeof seed === "number" ? seed : hash32(String(seed)))
    const sex = opts.sex || (r.chance(0.5) ? "F" : "M")
    const z = {}
    for (const k of Z_KEYS) z[k] = clamp((mother.z[k] + father.z[k]) / 2 + r.normal() * 0.62, -2.6, 2.6)
    const pickA = (pa, pb) => [pa[r.chance(0.5) ? 0 : 1], pb[r.chance(0.5) ? 0 : 1]]
    const mut = (x, s = 0.04) => clamp(x + r.normal() * s)
    const g = {
      id: String(seed),
      sex,
      z,
      asym: clamp((mother.asym + father.asym) / 2 + r.normal() * 0.15, 0.02, 1.4),
      asymSeed: Math.floor(r() * 1e9),
      skin: {
        mel: pickA(mother.skin.mel, father.skin.mel).map((x) => mut(x)),
        under: (mother.skin.under + father.skin.under) / 2 + r.normal() * 0.3,
        rosy: mut((mother.skin.rosy + father.skin.rosy) / 2, 0.08),
        freckle: pickA(mother.skin.freckle, father.skin.freckle),
        quality: mut((mother.skin.quality + father.skin.quality) / 2, 0.1),
        aging: clamp((mother.skin.aging + father.skin.aging) / 2 + r.normal() * 0.08, 0.7, 1.4),
        moles: Math.floor((mother.skin.moles + father.skin.moles) / 2 + r() * 3),
      },
      eye: { dark: pickA(mother.eye.dark, father.eye.dark), green: pickA(mother.eye.green, father.eye.green) },
      hair: {
        eu: pickA(mother.hair.eu, father.hair.eu).map((x) => mut(x, 0.05)),
        red: pickA(mother.hair.red, father.hair.red),
        tex: pickA(mother.hair.tex, father.hair.tex),
        density: mut((mother.hair.density + father.hair.density) / 2, 0.06),
        greyOnset: clamp((mother.hair.greyOnset + father.hair.greyOnset) / 2 + r.normal() * 4, 22, 65),
        // calvície: componente ligado ao X vem da mãe
        bald: sex === "M" ? clamp(mother.hair.bald * 0.3 + (r.chance(0.5) ? 0.9 : 0.2) * r() + father.hair.bald * 0.25) : clamp(r() * 0.2 - 0.08),
        baldOnset: clamp((mother.hair.baldOnset + father.hair.baldOnset) / 2 + r.normal() * 5, 19, 60),
        beardDensity: mut((mother.hair.beardDensity + father.hair.beardDensity) / 2, 0.1),
        beardRed: mut((mother.hair.beardRed + father.hair.beardRed) / 2, 0.05),
      },
      body: { fat: mut((mother.body.fat + father.body.fat) / 2, 0.1), heightZ: clamp((mother.body.heightZ + father.body.heightZ) / 2 + r.normal() * 0.7, -2.6, 2.6) },
      pref: {},
    }
    g.pref = defaultPrefs(g, r)
    const inheritedBody = makeRng(hash32(g.id + ":body:inherit"))
    const mb = bodyTraits(mother), fb = bodyTraits(father)
    for (const key of Object.keys(mb)) {
      g.body[key] = clamp((mb[key] + fb[key]) / 2 + inheritedBody.normal() * 0.12, 0, 1)
    }
    const ma = mother.ancestry || {}, fa = father.ancestry || {}
    g.ancestry = Object.fromEntries([...new Set([...Object.keys(ma), ...Object.keys(fa)])].map(k => [k, ((ma[k] || 0) + (fa[k] || 0)) / 2]))
    g.parents = [mother.id, father.id]
    return g
  }

  // ---------- fenótipo expresso ----------
  const expressDark = ([a, b]) => Math.max(a, b) * 0.78 + Math.min(a, b) * 0.22 // escuro domina
  const expressAvg = ([a, b]) => (a + b) / 2

  function phenotype(g, age) {
    const mel = expressAvg(g.skin.mel)
    const redHair = g.hair.red[0] && g.hair.red[1]
    let eu = expressAvg(g.hair.eu)
    // cabelo claro de criança escurece até a adolescência
    const kidLight = (1 - smooth(1, 14, age)) * (1 - eu) * 0.55
    eu = clamp(eu - kidLight * (eu < 0.85 ? 1 : 0.2))
    const pheo = redHair ? 0.85 : 0.18 + (1 - eu) * 0.2
    return {
      mel,
      eyeDark: expressDark(g.eye.dark),
      eyeGreen: expressAvg(g.eye.green),
      hairEu: eu,
      hairPheo: pheo,
      redHair,
      tex: expressAvg(g.hair.tex),
      freckle: Math.max(...g.skin.freckle) * (redHair ? 1.4 : 1) + (mel < 0.2 && redHair ? 0.3 : 0),
    }
  }

  // ---------- cores ----------
  function skinRGB(mel, under) {
    // rampa baseada em tons reais de pele (claro -> muito escuro)
    const ramp = [
      [0.0, [247, 222, 204]],
      [0.12, [236, 198, 172]],
      [0.25, [222, 176, 142]],
      [0.4, [196, 146, 108]],
      [0.55, [164, 114, 80]],
      [0.7, [126, 84, 58]],
      [0.84, [92, 60, 42]],
      [1.0, [60, 40, 30]],
    ]
    let c = ramp[0][1]
    for (let i = 1; i < ramp.length; i++) {
      if (mel <= ramp[i][0]) {
        const [t0, c0] = ramp[i - 1]
        const [t1, c1] = ramp[i]
        const t = (mel - t0) / (t1 - t0)
        c = [lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t)]
        break
      }
    }
    const u = under * 6 * (1 - mel * 0.6)
    return [c[0] + u * 0.4, c[1] - Math.abs(u) * 0.15, c[2] - u * 0.7 + (u < 0 ? u * 0.4 : 0)]
  }

  function hairRGB(eu, pheo) {
    // eumelanina escurece; feomelanina avermelha
    const blonde = [228, 196, 140]
    const black = [22, 18, 16]
    const e = Math.pow(eu, 0.8)
    let c = [lerp(blonde[0], black[0], e), lerp(blonde[1], black[1], e), lerp(blonde[2], black[2], e)]
    const redAmt = pheo > 0.6 ? (pheo - 0.2) * (1 - eu * 0.7) : pheo * 0.3 * (1 - eu)
    c = [c[0] + redAmt * 80, c[1] - redAmt * 5, c[2] - redAmt * 55]
    return c.map((v) => clamp(v, 0, 255))
  }

  function eyeRGB(dark, green) {
    if (dark > 0.72) return [lerp(110, 45, (dark - 0.72) / 0.28), lerp(70, 30, (dark - 0.72) / 0.28), lerp(40, 22, (dark - 0.72) / 0.28)]
    if (dark > 0.45) return [lerp(120, 110, (dark - 0.45) / 0.27), lerp(110 + green * 20, 70, (dark - 0.45) / 0.27), lerp(60, 40, (dark - 0.45) / 0.27)]
    if (dark > 0.25) return green > 0.5 ? [95, 128, 80] : [118, 124, 110]
    return green > 0.6 ? [110, 140, 150] : [92, 132, 176]
  }

  // ---------- estilos ----------
  // Parametrização: volTop/volSide em unidades de cabeça; side/back = até onde vai (0 = raspado, 1 = ombro, 1.6 = meio das costas).
  // fringe: none|straight|side|curtain|spiky|swept|wisp ; tie: ponytail|bun|topknot|pigtails|braids|braid|halfup|puffs ; special: afro|locs|cornrows|mohawk|bald
  const HAIR_STYLES = [
    // curtos
    { id: "raspado-zero", name: "Raspado na zero", len: 0, side: 0.02, volTop: 0, volSide: 0, special: "shaved" },
    { id: "maquina-2", name: "Máquina 2", len: 0.05, side: 0.05, volTop: 0.01, volSide: 0.005, special: "buzz" },
    { id: "militar", name: "Corte militar", len: 0.1, side: 0.04, volTop: 0.03, volSide: 0.005, fade: 1 },
    { id: "social-curto", name: "Social curto", len: 0.22, side: 0.12, volTop: 0.05, volSide: 0.02, part: 0.35, fringe: "swept" },
    { id: "risca-lado", name: "Risca lateral", len: 0.3, side: 0.14, volTop: 0.07, volSide: 0.025, part: 0.45, fringe: "swept" },
    { id: "topete", name: "Topete", len: 0.4, side: 0.08, volTop: 0.16, volSide: 0.015, fringe: "quiff", fade: 0.6 },
    { id: "pompadour", name: "Pompadour", len: 0.5, side: 0.1, volTop: 0.22, volSide: 0.025, fringe: "pomp" },
    { id: "cesar", name: "Corte César", len: 0.18, side: 0.08, volTop: 0.04, volSide: 0.015, fringe: "straight", fringeLen: 0.12 },
    { id: "crop-texturizado", name: "Crop texturizado", len: 0.25, side: 0.05, volTop: 0.08, volSide: 0.01, fringe: "spiky", fringeLen: 0.18, fade: 0.9 },
    { id: "degrade-navalhado", name: "Degradê navalhado", len: 0.28, side: 0.02, volTop: 0.1, volSide: 0.004, fade: 1.2, fringe: "swept" },
    { id: "flat-top", name: "Flat top", len: 0.3, side: 0.03, volTop: 0.22, volSide: 0.01, special: "flattop", fade: 0.8 },
    { id: "espetado", name: "Espetado", len: 0.3, side: 0.06, volTop: 0.14, volSide: 0.02, fringe: "spiky", fringeLen: 0.1 },
    { id: "lambido", name: "Penteado para trás", len: 0.35, side: 0.12, volTop: 0.06, volSide: 0.02, fringe: "back" },
    { id: "moicano", name: "Moicano", len: 0.4, side: 0.0, volTop: 0.26, volSide: 0, special: "mohawk" },
    { id: "undercut", name: "Undercut", len: 0.45, side: 0.02, volTop: 0.12, volSide: 0.004, fade: 1.5, fringe: "side", fringeLen: 0.25 },
    { id: "cacheado-curto", name: "Cacheado curto", len: 0.25, side: 0.1, volTop: 0.1, volSide: 0.04, curlBoost: 1.5 },
    { id: "black-power-curto", name: "Black curto", len: 0.2, side: 0.1, volTop: 0.1, volSide: 0.06, special: "afro", curlBoost: 3 },
    { id: "twists-curtos", name: "Twists curtos", len: 0.28, side: 0.12, volTop: 0.1, volSide: 0.05, special: "twists" },
    { id: "cigano", name: "Pixie", len: 0.25, side: 0.14, volTop: 0.06, volSide: 0.03, fringe: "side", fringeLen: 0.32, part: 0.4 },
    { id: "joaozinho", name: "Joãozinho", len: 0.2, side: 0.1, volTop: 0.05, volSide: 0.02, fringe: "wisp", fringeLen: 0.2 },
    // médios
    { id: "tigela", name: "Tigela", len: 0.5, side: 0.42, volTop: 0.06, volSide: 0.05, fringe: "straight", fringeLen: 0.42 },
    { id: "cortina", name: "Franja cortina (anos 90)", len: 0.55, side: 0.45, volTop: 0.05, volSide: 0.04, fringe: "curtain", fringeLen: 0.5, part: 0 },
    { id: "chanel", name: "Chanel", len: 0.6, side: 0.62, volTop: 0.05, volSide: 0.06, part: 0.35 },
    { id: "chanel-franja", name: "Chanel com franja", len: 0.6, side: 0.6, volTop: 0.05, volSide: 0.06, fringe: "straight", fringeLen: 0.45 },
    { id: "long-bob", name: "Long bob", len: 0.75, side: 0.82, volTop: 0.05, volSide: 0.06, part: 0.3 },
    { id: "shag", name: "Shag repicado", len: 0.7, side: 0.8, volTop: 0.09, volSide: 0.09, fringe: "curtain", fringeLen: 0.45, layered: 1 },
    { id: "mullet", name: "Mullet", len: 0.8, side: 0.25, back: 1.0, volTop: 0.08, volSide: 0.03, fringe: "spiky", fringeLen: 0.2 },
    { id: "surfista", name: "Surfista", len: 0.65, side: 0.6, volTop: 0.07, volSide: 0.05, part: 0.1, fringe: "curtain", fringeLen: 0.55, wavyBoost: 1 },
    { id: "medio-cacheado", name: "Médio cacheado", len: 0.6, side: 0.62, volTop: 0.12, volSide: 0.12, curlBoost: 1.5, part: 0.2 },
    { id: "atras-orelha", name: "Médio atrás da orelha", len: 0.55, side: 0.45, volTop: 0.06, volSide: 0.02, part: 0.4, tucked: 1 },
    // longos
    { id: "longo-liso", name: "Longo liso", len: 1.3, side: 1.35, volTop: 0.04, volSide: 0.05, part: 0.2 },
    { id: "longo-repartido", name: "Longo repartido ao meio", len: 1.2, side: 1.25, volTop: 0.03, volSide: 0.05, part: 0 },
    { id: "longo-ondulado", name: "Longo ondulado", len: 1.2, side: 1.25, volTop: 0.07, volSide: 0.12, part: 0.3, wavyBoost: 1.2 },
    { id: "longo-franja", name: "Longo com franja", len: 1.2, side: 1.2, volTop: 0.05, volSide: 0.06, fringe: "straight", fringeLen: 0.45 },
    { id: "longo-camadas", name: "Longo em camadas", len: 1.25, side: 1.2, volTop: 0.07, volSide: 0.1, fringe: "curtain", fringeLen: 0.6, layered: 1 },
    { id: "longo-cacheado", name: "Longo cacheado", len: 1.05, side: 1.05, volTop: 0.16, volSide: 0.2, curlBoost: 1.5, part: 0.2 },
    { id: "muito-longo", name: "Muito longo", len: 1.7, side: 1.75, volTop: 0.04, volSide: 0.05, part: 0.1 },
    { id: "cabelo-grisalho-longo", name: "Longo solto de lado", len: 1.1, side: 1.0, volTop: 0.05, volSide: 0.06, part: 0.55, sideSwept: 1 },
    { id: "black-power", name: "Black power", len: 0.7, side: 0.55, volTop: 0.34, volSide: 0.34, special: "afro", curlBoost: 3 },
    { id: "black-power-grande", name: "Black power volumoso", len: 1, side: 0.7, volTop: 0.5, volSide: 0.5, special: "afro", curlBoost: 3 },
    { id: "dreads-curtos", name: "Dreads curtos", len: 0.5, side: 0.5, volTop: 0.08, volSide: 0.06, special: "locs" },
    { id: "dreads-longos", name: "Dreads longos", len: 1.35, side: 1.35, volTop: 0.08, volSide: 0.08, special: "locs" },
    { id: "trancas-nago", name: "Tranças nagô", len: 0.1, side: 0.05, volTop: 0.02, volSide: 0.01, special: "cornrows" },
    { id: "box-braids", name: "Box braids", len: 1.4, side: 1.45, volTop: 0.06, volSide: 0.08, special: "boxbraids" },
    // presos
    { id: "rabo-de-cavalo", name: "Rabo de cavalo", len: 1.1, side: 0.12, volTop: 0.03, volSide: 0.01, tie: "ponytail", slick: 1 },
    { id: "rabo-baixo", name: "Rabo baixo", len: 1.0, side: 0.2, volTop: 0.03, volSide: 0.02, tie: "lowtail", part: 0 },
    { id: "coque-alto", name: "Coque alto", len: 1.0, side: 0.1, volTop: 0.03, volSide: 0.01, tie: "bun", slick: 1 },
    { id: "coque-baixo", name: "Coque baixo", len: 1.0, side: 0.18, volTop: 0.03, volSide: 0.02, tie: "lowbun", part: 0.3 },
    { id: "coque-banana", name: "Coque bagunçado", len: 1.0, side: 0.2, volTop: 0.05, volSide: 0.03, tie: "messybun", strays: 1 },
    { id: "coque-masculino", name: "Coque masculino (man bun)", len: 0.9, side: 0.03, volTop: 0.04, volSide: 0.005, tie: "topknot", fade: 1.2, slick: 1 },
    { id: "meio-preso", name: "Meio preso", len: 1.15, side: 1.15, volTop: 0.06, volSide: 0.05, tie: "halfup", part: 0 },
    { id: "maria-chiquinha", name: "Maria-chiquinha", len: 0.8, side: 0.12, volTop: 0.03, volSide: 0.01, tie: "pigtails", part: 0 },
    { id: "duas-trancas", name: "Duas tranças", len: 1.2, side: 0.12, volTop: 0.03, volSide: 0.02, tie: "braids", part: 0 },
    { id: "tranca-lateral", name: "Trança lateral", len: 1.2, side: 0.2, volTop: 0.04, volSide: 0.03, tie: "sidebraid", part: 0.4 },
    { id: "puffs", name: "Dois puffs", len: 0.6, side: 0.05, volTop: 0.03, volSide: 0.01, tie: "puffs", part: 0, curlBoost: 3 },
    { id: "coque-afro", name: "Afro puff alto", len: 0.7, side: 0.05, volTop: 0.03, volSide: 0.01, tie: "afropuff", curlBoost: 3 },
    // calvície / infantis
    { id: "calvo", name: "Calvo (natural)", len: 0.12, side: 0.1, volTop: 0.02, volSide: 0.02, special: "horseshoe" },
    { id: "calvo-ralo", name: "Coroa rala", len: 0.18, side: 0.12, volTop: 0.02, volSide: 0.02, special: "thin" },
    { id: "bebe", name: "Penugem de bebê", len: 0.04, side: 0.03, volTop: 0.01, volSide: 0.005, special: "fuzz", minAge: 0 },
    { id: "infantil-franjinha", name: "Franjinha infantil", len: 0.3, side: 0.28, volTop: 0.05, volSide: 0.04, fringe: "straight", fringeLen: 0.38 },
    { id: "infantil-arrepiado", name: "Arrepiado infantil", len: 0.2, side: 0.1, volTop: 0.08, volSide: 0.03, fringe: "spiky", fringeLen: 0.1 },
  ]

  const BEARD_STYLES = [
    { id: "nenhuma", name: "Barbeado" },
    { id: "sombra", name: "Sombra (5 da tarde)", parts: ["mus", "chin", "cheek", "neck"], len: 0.02, stubble: 0.35 },
    { id: "por-fazer", name: "Barba por fazer", parts: ["mus", "chin", "cheek", "neck"], len: 0.05, stubble: 0.8 },
    { id: "rala-jovem", name: "Rala (jovem)", parts: ["mus", "chin", "cheek"], len: 0.1, stubble: 0.5, patchy: 0.6 },
    { id: "curta", name: "Barba curta", parts: ["mus", "chin", "cheek", "neck"], len: 0.12 },
    { id: "cheia", name: "Barba cheia", parts: ["mus", "chin", "cheek", "neck"], len: 0.3 },
    { id: "cheia-longa", name: "Barba longa", parts: ["mus", "chin", "cheek", "neck"], len: 0.7 },
    { id: "mago", name: "Barba de mago", parts: ["mus", "chin", "cheek", "neck"], len: 1.3, point: 0.6 },
    { id: "lenhador", name: "Lenhador (Bandholz)", parts: ["mus", "chin", "cheek", "neck"], len: 0.95, wild: 1 },
    { id: "garibaldi", name: "Garibaldi", parts: ["mus", "chin", "cheek", "neck"], len: 0.55, round: 1 },
    { id: "verdi", name: "Verdi", parts: ["mus", "chin", "cheek", "neck"], len: 0.4, round: 0.6, mus: "handlebar" },
    { id: "ducktail", name: "Ducktail", parts: ["mus", "chin", "cheek", "neck"], len: 0.45, point: 1 },
    { id: "quadrada", name: "Quadrada aparada", parts: ["mus", "chin", "cheek", "neck"], len: 0.2, boxed: 1 },
    { id: "cavanhaque", name: "Cavanhaque", parts: ["mus", "goatee"], len: 0.12 },
    { id: "cavanhaque-longo", name: "Cavanhaque longo", parts: ["mus", "goatee"], len: 0.4, point: 0.7 },
    { id: "barbicha", name: "Barbicha (só queixo)", parts: ["goatee"], len: 0.15 },
    { id: "van-dyke", name: "Van Dyke", parts: ["mus", "goateeFree"], len: 0.2, point: 0.5, mus: "handlebar" },
    { id: "balbo", name: "Balbo", parts: ["mus", "goateeWide"], len: 0.14, musGap: 1 },
    { id: "ancora", name: "Âncora", parts: ["mus", "anchor"], len: 0.14, musGap: 1, mus: "pencilWide" },
    { id: "circular", name: "Circular", parts: ["mus", "goateeRound"], len: 0.1 },
    { id: "mosca", name: "Mosca (soul patch)", parts: ["soul"], len: 0.08 },
    { id: "queixeira", name: "Queixeira (chin strap)", parts: ["strap"], len: 0.05 },
    { id: "cortina-queixo", name: "Barba sem bigode (Amish)", parts: ["chin", "cheekLow", "neck"], len: 0.45 },
    { id: "costeletas", name: "Costeletas longas", parts: ["burns"], len: 0.06 },
    { id: "suicas", name: "Suíças (mutton chops)", parts: ["chops"], len: 0.12 },
    { id: "suicas-bigode", name: "Suíças com bigode", parts: ["chops", "mus"], len: 0.12, mus: "walrus" },
    { id: "bigode", name: "Bigode clássico", parts: ["mus"], len: 0.08 },
    { id: "bigode-lapis", name: "Bigode lápis", parts: ["mus"], len: 0.03, mus: "pencil" },
    { id: "bigode-chevron", name: "Bigode chevron", parts: ["mus"], len: 0.1, mus: "chevron" },
    { id: "bigode-guidao", name: "Bigode guidão", parts: ["mus"], len: 0.1, mus: "handlebar" },
    { id: "bigode-ferradura", name: "Bigode ferradura", parts: ["mus", "horseshoe"], len: 0.08 },
    { id: "bigode-morsa", name: "Bigode morsa", parts: ["mus"], len: 0.14, mus: "walrus" },
    { id: "fu-manchu", name: "Fu Manchu", parts: ["mus", "fumanchu"], len: 0.08, mus: "pencilWide" },
    { id: "bigode-ingles", name: "Bigode inglês", parts: ["mus"], len: 0.05, mus: "english" },
    { id: "bigode-barba-rala", name: "Bigode e barba por fazer", parts: ["mus", "chin", "cheek", "neck"], len: 0.05, stubble: 0.8, musLen: 0.1 },
    { id: "penugem", name: "Penugem de adolescente", parts: ["mus"], len: 0.03, stubble: 0.35, fuzz: 1 },
  ]

  const HAIR_BY_ID = Object.fromEntries(HAIR_STYLES.map((s) => [s.id, s]))
  const BEARD_BY_ID = Object.fromEntries(BEARD_STYLES.map((s) => [s.id, s]))

  function defaultPrefs(g, r) {
    const F = g.sex === "F"
    const tex = expressAvg(g.hair.tex)
    let pool
    if (F) {
      pool = tex > 2
        ? ["black-power", "black-power-grande", "box-braids", "puffs", "coque-afro", "longo-cacheado", "trancas-nago", "twists-curtos", "dreads-longos", "medio-cacheado", "coque-alto"]
        : ["longo-liso", "longo-ondulado", "longo-franja", "longo-camadas", "chanel", "chanel-franja", "long-bob", "shag", "rabo-de-cavalo", "coque-alto", "coque-baixo", "coque-banana", "meio-preso", "cigano", "tranca-lateral", "longo-repartido", "muito-longo", "medio-cacheado"]
    } else {
      pool = tex > 2
        ? ["black-power-curto", "maquina-2", "degrade-navalhado", "twists-curtos", "dreads-curtos", "dreads-longos", "black-power", "raspado-zero", "trancas-nago", "flat-top"]
        : ["social-curto", "risca-lado", "topete", "militar", "crop-texturizado", "degrade-navalhado", "undercut", "espetado", "lambido", "cesar", "surfista", "cortina", "atras-orelha", "coque-masculino", "maquina-2", "mullet", "pompadour", "longo-liso", "cacheado-curto"]
    }
    const additional = HAIR_STYLES.filter(s => s.catalogTexture != null && (F ? s.len > .4 : s.len < .9) && (tex > 2 ? s.special || s.catalogTexture >= 2 : !s.special)).map(s => s.id)
    pool = [...pool, ...additional]
    // cabelo longo em homem existe, mas é minoria: sem isso metade sairia de cabelo nos ombros
    if (!F) {
      const short = pool.filter((id) => HAIR_BY_ID[id] && HAIR_BY_ID[id].len < 0.45)
      if (short.length && !r.chance(0.12)) pool = short
    }
    const beards = BEARD_STYLES.map((b) => b.id)
    return {
      hair: r.pick(pool),
      beard: F ? "nenhuma" : r.chance(0.35) ? "nenhuma" : r.pick(beards.slice(1)),
      glasses: r.chance(0.22) ? r.pick(["redondo", "retangular", "gatinho", "aviador", "grosso"]) : null,
      makeup: F ? clamp(r() * 1.2 - 0.2) : 0,
      shirt: r.pick(["crew", "collar", "vneck", "sweater", "tank"]),
      shirtHue: r(),
      shirtTone: r(),
    }
  }

  // Estilo apropriado para a idade (a preferência adulta só vale a partir da adolescência).
  function hairForAge(g, age, forced) {
    if (age < 1.2) return HAIR_BY_ID.bebe
    const r = makeRng(hash32(g.id + "kid"))
    if (forced) return HAIR_BY_ID[forced]
    if (age < 11) {
      const tex = expressAvg(g.hair.tex)
      const kidF = tex > 2 ? ["puffs", "maria-chiquinha", "duas-trancas", "trancas-nago", "coque-afro"] : ["maria-chiquinha", "duas-trancas", "chanel-franja", "rabo-de-cavalo", "longo-liso", "infantil-franjinha"]
      const kidM = tex > 2 ? ["black-power-curto", "maquina-2", "twists-curtos"] : ["infantil-franjinha", "infantil-arrepiado", "tigela", "social-curto", "maquina-2"]
      return HAIR_BY_ID[r.pick(g.sex === "F" ? kidF : kidM)]
    }
    const balding = sexBalding(g, age)
    if (balding > 0.78) return HAIR_BY_ID.calvo
    if (balding > 0.4) return HAIR_BY_ID["calvo-ralo"]
    return HAIR_BY_ID[g.pref.hair]
  }

  function sexBalding(g, age) {
    return g.sex === "M" ? smooth(g.hair.baldOnset, g.hair.baldOnset + 30, age) * g.hair.bald : 0
  }

  // ---------- geometria dependente de idade/peso ----------
  function catmull(pts, closed, seg = 8) {
    const out = []
    const n = pts.length
    const get = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))])
    const last = closed ? n : n - 1
    for (let i = 0; i < last; i++) {
      const p0 = get(i - 1), p1 = get(i), p2 = get(i + 1), p3 = get(i + 2)
      for (let s = 0; s < seg; s++) {
        const t = s / seg, t2 = t * t, t3 = t2 * t
        out.push([
          0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3),
          0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3),
        ])
      }
    }
    if (!closed) out.push(pts[n - 1])
    return out
  }

  function layout(g, st) {
    const a = st.age
    const z = g.z
    const F = g.sex === "F"
    const gr = smooth(0, 17, a) // crescimento
    const baby = 1 - smooth(0, 7, a)
    const old = smooth(45, 100, a) * g.skin.aging
    const fat = st.fat
    const thin = clamp(0.3 - fat) / 0.3
    const ar = makeRng(g.asymSeed)
    const asym = () => ar.normal() * g.asym * 1.8

    const scale = lerp(0.8, 1, smooth(0, 16, a))
    const cx = 200 + asym() * 1.2
    let rx = 90 * (1 + 0.045 * z.faceW) * (F ? 0.955 : 1) * scale * lerp(1.07, 1, gr)
    const Ht = rx * lerp(2.18, 2.66, gr) * (1 + 0.045 * z.faceL) * (1 + 0.02 * z.skullH)
    const chinY = lerp(340, 352, gr) + fat * 14
    const y0 = chinY - Ht
    const eyeY = y0 + Ht * (lerp(0.6, 0.495, gr) + 0.012 * z.eyeY + old * 0.006)
    const browY = eyeY - Ht * lerp(0.068, 0.078, gr) * (1 + 0.08 * z.browY) + old * 3
    const noseY = eyeY + Ht * lerp(0.15, 0.195, gr) * (1 + 0.09 * z.noseL) + old * Ht * 0.018
    const mouthY = noseY + Ht * lerp(0.07, 0.08, gr) * (1 + 0.06 * z.mouthY) + old * 2
    const eyeW = rx * 2 * lerp(0.225, 0.2, gr) * (1 + 0.06 * z.eyeSize) * (1 - old * 0.05)
    const eyeOff = eyeW * (1.0 + 0.1 * z.eyeSpace) * lerp(0.98, 1, gr)
    const open = clamp(lerp(0.43, 0.29, gr) * (1 + 0.13 * z.eyeOpen) - old * 0.045 - fat * 0.035, 0.15, 0.48)
    const hairlineY = browY - (chinY - browY) * lerp(0.66, 0.45, gr) * (1 + 0.1 * z.forehead)

    const jowl = old * (0.4 + fat * 0.8)
    const cheekbone = rx * (0.975 + 0.03 * z.cheekB) + fat * rx * 0.1
    const cheek = rx * (0.87 + fat * 0.34 + baby * 0.1 - thin * 0.1 + 0.02 * z.faceW) - old * 2
    const jawW = rx * lerp(0.93, F ? 0.72 : 0.77, gr) * (1 + 0.06 * z.jawW) + fat * rx * 0.34 - thin * rx * 0.05 + jowl * 7
    const jawY = mouthY + (chinY - mouthY) * lerp(0.2, 0.33 + 0.05 * z.jawSq, gr) + jowl * 6
    const chinW = rx * lerp(0.46, F ? 0.28 : 0.34, gr) * (1 + 0.1 * z.chinW) + fat * rx * 0.2
    const chinFlat = F ? 0.4 : 0.55 + 0.1 * z.jawSq

    const pR = [] // lado direito, de cima para baixo
    const skullRy = browY - y0
    const segs = 6
    for (let i = 0; i < segs; i++) {
      const t = (i / segs) * (Math.PI / 2)
      pR.push([Math.sin(t) * rx * (i === 0 ? 1 : 1.0), browY - Math.cos(t) * skullRy])
    }
    pR.push([rx * 0.99, browY])
    pR.push([cheekbone, eyeY + eyeW * 0.4])
    pR.push([cheek, mouthY - Ht * 0.03])
    pR.push([jawW, jawY])
    if (jowl > 0.05) pR.push([jawW * 0.86 + jowl * 3, jawY + (chinY - jawY) * 0.55 + jowl * 5])
    pR.push([chinW, chinY - Ht * 0.03 * (1 - chinFlat * 0.4)])
    pR.push([chinW * chinFlat * 0.8, chinY - Ht * 0.004])

    const right = pR.map(([x, y], i) => [cx + x + (i > 5 ? asym() * 0.8 : 0), y])
    const left = pR.map(([x, y], i) => [cx - x + (i > 5 ? asym() * 0.8 : 0), y]).reverse()
    // topo único e queixo único
    const ring = [...right, [cx, chinY + 0.5], ...left.slice(0, -1)]
    const outline = catmull(ring, true, 6)

    // pescoço e ombros
    const neckW = rx * lerp(0.62, F ? 0.6 : 0.7, gr) * (1 + 0.06 * z.neck) * (1 + fat * 0.8 - thin * 0.12) + old * 2
    const shoulderY = chinY + Ht * lerp(0.14, 0.24, gr) - fat * 6
    const shoulderW = rx * lerp(1.55, F ? 2.05 : 2.35, gr) * (1 + fat * 0.28)

    const earH = (noseY - browY) * (1 + 0.08 * z.earSize) * (1 + old * 0.14) * lerp(1.08, 1, gr)
    const earW = earH * 0.36
    const earOut = clamp(0.12 + 0.07 * z.earOut, 0.02, 0.38)

    const mouthW = eyeW * 2 * 0.74 * (1 + 0.07 * z.mouthW) * lerp(0.72, 1, gr) + fat * 2
    const lipU = mouthW * 0.13 * (1 + 0.22 * z.lipU) * (1 - old * 0.4) * (F ? 1.1 : 1)
    const lipL = mouthW * 0.17 * (1 + 0.22 * z.lipL) * (1 - old * 0.35) * (F ? 1.1 : 1)

    const noseW = eyeW * (0.98 + 0.14 * z.noseW) * lerp(0.72, 1, gr) + old * 2 + fat * 2
    const noseLen = noseY - browY

    return {
      a, F, gr, baby, old, fat, thin, jowl, cx, rx, Ht, y0, chinY, eyeY, browY, noseY, mouthY, eyeW, eyeOff, open,
      hairlineY, skullRy, cheek, cheekbone, jawW, jawY, chinW, outline, neckW, shoulderY, shoulderW, earH, earW, earOut,
      mouthW, lipU, lipL, noseW, noseLen,
      asymEye: [asym() * 1.2, asym() * 1.2],
      asymBrow: [asym() * 1.6, asym() * 1.6],
      asymMouth: asym() * 1.4,
      asymNose: asym() * 1.3,
      tilt: (0.06 * z.eyeTilt + (F ? 0.03 : 0.015)) * (1 - old * 0.6),
    }
  }

  // Largura da face (lado direito) numa altura y, a partir do contorno.
  function faceHalfWidth(L, y) {
    let best = 0
    const o = L.outline
    for (let i = 0; i < o.length; i++) {
      const p = o[i], q = o[(i + 1) % o.length]
      if (p[0] < L.cx && q[0] < L.cx) continue
      if ((p[1] - y) * (q[1] - y) <= 0 && p[1] !== q[1]) {
        const t = (y - p[1]) / (q[1] - p[1])
        const x = p[0] + (q[0] - p[0]) * t - L.cx
        if (x > best) best = x
      }
    }
    return best
  }

  // Estado derivado: gordura corporal atual (genética + idade + ajuste manual).
  function bodyFatAt(g, age, override) {
    if (override != null) return override
    const babyFat = (1 - smooth(0, 5, age)) * 0.35
    const mid = smooth(25, 55, age) * 0.15
    return clamp(g.body.fat + babyFat + mid - smooth(80, 100, age) * 0.12)
  }

  function heightCm(g, age) {
    const adult = (g.sex === "F" ? 162 : 175) + g.body.heightZ * 7
    // curva de crescimento simplificada (OMS aproximada)
    const pts = [[0, 0.29], [1, 0.43], [2, 0.5], [5, 0.62], [10, 0.79], [13, 0.88], [16, 0.97], [19, 1]]
    let f = 1
    for (let i = 1; i < pts.length; i++) {
      if (age <= pts[i][0]) {
        const t = (age - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0])
        f = lerp(pts[i - 1][1], pts[i][1], t)
        break
      }
    }
    const shrink = smooth(60, 100, age) * 5
    return adult * f - shrink
  }

  // Independent stream: new body traits never change the existing face genome.
  function bodyTraits(g) {
    const r = makeRng(hash32(g.id + ":body"))
    const traits = {}
    for (const key of ["muscle", "frame", "shoulders", "hips", "legLength", "armLength", "waist", "posture"]) {
      traits[key] = g.body[key] ?? clamp(0.5 + r.normal() * 0.16)
    }
    return traits
  }

  // Normalized anatomy, shared by the renderer and future simulation adapters.
  function bodyLayout(g, opts = {}) {
    const age = clamp(opts.age ?? 30, 0, 110)
    const b = bodyTraits(g), adult = smooth(3, 19, age), puberty = smooth(10, 19, age)
    const old = smooth(55, 105, age), F = g.sex === "F"
    const fat = bodyFatAt(g, age, opts.fat)
    const muscle = clamp(opts.muscle ?? b.muscle) * smooth(5, 19, age) * (1 - old * 0.4)
    const head = lerp(0.25, 0.132, adult)
    const shoulders = lerp(0.105, F ? 0.113 : 0.133, adult) + b.shoulders * 0.018 + muscle * 0.022 + fat * 0.013
    const hips = lerp(0.098, F ? 0.121 : 0.103, puberty) + b.hips * 0.013 + fat * 0.032
    const waist = lerp(0.091, F ? 0.076 : 0.086, puberty) + b.waist * 0.012 + fat * 0.067 + muscle * 0.008
    const crotch = lerp(0.61, 0.505 + (0.5 - b.legLength) * 0.055, adult)
    return {
      age, adult, old, fat, muscle, F, height: heightCm(g, age), head, shoulders, hips, waist,
      chest: shoulders * 0.83 + fat * 0.02, neck: lerp(0.034, 0.027, adult) + fat * 0.012 + muscle * 0.006,
      shoulderY: head + lerp(0.028, 0.043, adult), chestY: lerp(0.38, 0.285, adult),
      waistY: crotch - 0.12, hipY: crotch - 0.041, crotch,
      kneeY: crotch + (0.956 - crotch) * 0.53, ankleY: 0.956,
      upperArm: 0.022 + fat * 0.02 + muscle * 0.014, wrist: 0.013 + fat * 0.004,
      thigh: 0.038 + fat * 0.028 + muscle * 0.011, calf: 0.023 + fat * 0.012 + muscle * 0.009,
      elbowY: crotch - 0.13, wristY: crotch + 0.065 + (b.armLength - 0.5) * 0.035,
      stoop: old * 0.026 + (b.posture - 0.5) * 0.007,
    }
  }

  root.FaceCore = {
    clamp, lerp, smooth, hash32, makeRng, makeGenome, childGenome, phenotype, skinRGB, hairRGB, eyeRGB,
    HAIR_STYLES, BEARD_STYLES, HAIR_BY_ID, BEARD_BY_ID, hairForAge, layout, faceHalfWidth, catmull, bodyFatAt, heightCm,
    ANCESTRY, bodyTraits, bodyLayout,
  }
})(typeof window !== "undefined" ? window : globalThis)
