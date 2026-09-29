// Cabelo 2,5D. A área coberta é definida na superfície (u, y) de uma casca inflada
// em volta da cabeça; mechas, cachos e tranças também vivem em (u, y) e são projetados a cada ângulo.

import { seededRandom, hashText, type Phenotype } from "@paralelo/simulation"
import { GREY_HAIR, WHITE_HAIR, hairColor } from "./color"
import { ellipseD, polyD, smoothD, type Painter } from "./display"
import type { FaceLayout } from "./geometry"
import type { Head } from "./head"
import { clamp, hex, lerp, mix, mul, smooth, valueNoise, type Pt, type RGB } from "./math"
import { coverageHull, projectRuns, regionPolygons, shellPoint, View, wrap, type Shell } from "./shell"
import type { HairParams } from "./styles"

type V3 = { x: number; y: number; z: number }
type Clump = { pts: Pt[]; w: number; tone: number; prot: number }
type Tie = { kind: "sphere"; c: V3; r: number; curly: boolean } | { kind: "tube"; pts: V3[]; r: number; braid: boolean }

export type HairModel = {
  params: HairParams
  color: RGB
  grey: number
  tex: number
  shell: Shell
  tight: Shell
  top: (u: number) => number
  bot: (u: number) => number
  buzz: { top: (u: number) => number; bot: (u: number) => number; alpha: number } | null
  clumps: Clump[]
  curls: Pt[]
  strands: { pts: Pt[]; w: number; tone: number }[]
  rows: Pt[][]
  dots: Pt[]
  ties: Tie[]
  sheenY: number
  thin: number
  capOnly: boolean
  capAlpha: number
}

const UT = 0.6 // têmpora
const UE = 1.5 // orelha
const UB = 2.25 // nuca

export function buildHair(L: FaceLayout, head: Head, params: HairParams, ph: Phenotype, age: number, seed: string): HairModel {
  const r = seededRandom(hashText(seed + ":hair"))
  const { rx, browY, y0, chinY, shoulderY, skullRy, noseY, jawY } = L
  const special = params.special
  const tex = clamp(ph.texture + (params.curlBoost ? Math.max(0, params.curlBoost - ph.texture) * 0.8 : 0) + (params.wavyBoost ? Math.max(0, 1 - ph.texture) : 0), 0, 3)
  const young = smooth(0.8, 4, age)
  const volTex = tex > 1.5 ? (tex - 1.5) * 0.06 : 0
  const vt = Math.min((params.volTop + volTex) * rx * 2.9 * lerp(0.3, 1, young) + 2, y0 - 18)
  let vs = (params.volSide + volTex * 0.8) * rx * 2.2 * lerp(0.3, 1, young) + 1.5
  const lenK = lerp(0.35, 1, smooth(1, 8, age))
  const ySide = (sv: number): number => {
    const v = sv * lenK
    if (v <= 0.5) return lerp(browY - 12, chinY, v / 0.5)
    if (v <= 1) return lerp(chinY, shoulderY + 12, (v - 0.5) / 0.5)
    return Math.min(lerp(shoulderY + 12, 560, (v - 1) / 0.8), 545)
  }
  const long = params.side >= 0.42 && !params.tucked && !params.tie
  if (long) vs = Math.max(vs, L.earW * (0.8 + L.earOut) * 0.9 + 3)
  const vF = params.fringe === "quiff" ? vt * 0.9 : params.fringe === "pomp" ? vt * 1.1 : 0
  const vB = vt * 0.8 + vs

  // calvície
  const bald = special === "horseshoe" ? 1 : ph.baldness
  const recede = bald * 0.9
  const hlY = L.hairlineY - recede * (L.hairlineY - y0) * 0.55
  const templeY = lerp(L.hairlineY + (browY - L.hairlineY) * 0.35, y0 + skullRy * 0.35, recede)
  const horseshoe = special === "horseshoe" || bald > 0.78
  const thin = special === "thin" ? 0.5 : clamp((bald - 0.45) * 1.6)

  const sideY = Math.max(ySide(params.side), browY - 8)
  const backY = ySide(params.back ?? Math.max(params.side, special === "shaved" || special === "buzz" ? 0.1 : 0.28))
  const napeY = Math.max(backY, noseY + (chinY - noseY) * 0.2)
  const flatY = special === "flattop" ? y0 - vt * 0.55 : -Infinity

  // casca do cabelo
  const hs = (y: number): { w: number; zF: number; zB: number; nF: number } => {
    const yy = Math.max(y, flatY)
    if (yy <= browY) {
      const t = clamp((browY - yy) / (skullRy + vt))
      const k = Math.sqrt(Math.max(0, 1 - t * t))
      const tb = clamp((browY + skullRy * 0.1 - yy) / (skullRy * 1.1 + vt))
      const front = vF * Math.exp(-Math.pow((yy - (hlY - vt * 0.3)) / (vt * 0.6 + 8), 2))
      return { w: Math.max(0.5, (rx + vs) * k), zF: (head.F0 + 2 + front) * Math.pow(k, 0.55), zB: -(head.B0 + vB) * Math.sqrt(Math.max(0, 1 - tb * tb)), nF: 2.1 }
    }
    if (yy <= jawY) {
      const s = (yy - browY) / Math.max(1, jawY - browY)
      return { w: rx + vs - s * 3, zF: head.shell.section(yy).zF * 0.86, zB: -(head.B0 + vB) * lerp(1, 0.92, s), nF: 2.3 }
    }
    const k = smooth(0, 1, (yy - jawY) / Math.max(1, shoulderY + 12 - jawY))
    const w = lerp(rx + vs - 3, Math.max(rx + vs, L.shoulderW * 0.38), k) + tex * 4 * k + Math.max(0, yy - shoulderY - 12) * 0.12
    return { w, zF: lerp(head.shell.section(jawY).zF * 0.6, rx * 0.2, k), zB: lerp(-(head.B0 + vB) * 0.92, -rx * 0.36 - L.shoulderW * 0.3, k), nF: 2 }
  }
  const yBot = Math.min(Math.max(sideY, backY, napeY) + 6, 548)
  const shell: Shell = { xc: 0, zc: 0, yTop: Math.max(y0 - vt, flatY === -Infinity ? -Infinity : flatY) === -Infinity ? y0 - vt : Math.max(y0 - vt, flatY), yBot, section: hs }
  // casca rente (raspados, laterais do degradê)
  const tight: Shell = {
    xc: 0,
    zc: 0,
    yTop: y0 - 1,
    yBot: noseY,
    section: (y) => {
      const s = head.shell.section(y)
      return { w: s.w + 1, zF: s.zF + 1, zB: s.zB - 1, nF: s.nF }
    },
  }

  // --- cobertura ---
  const hairline = (au: number): number => lerp(hlY, templeY, Math.pow(clamp(au / UT), 2))
  const fringeBot = (u: number): number => {
    const f = params.fringe
    const au = Math.abs(u)
    if (!f || f === "back" || f === "quiff" || f === "pomp" || horseshoe) return -Infinity
    const fl = params.fringeLen ?? 0.2
    let yB = lerp(hlY, L.eyeY + 4, fl / 0.5)
    if (fl < 0.5 || age < 12) yB = Math.min(yB, browY - 3)
    const edge = 1 - smooth(UT - 0.12, UT + 0.05, au)
    switch (f) {
      case "straight":
        return lerp(hlY, yB + Math.sin(u * 40) * 1.2, edge)
      case "side":
      case "wisp": {
        const d = Math.sign(params.part ?? 0.3) || 1
        const k = clamp(0.5 - (u * d) / (UT * 2))
        return lerp(hlY, lerp(hlY + 4, yB, k), edge)
      }
      case "swept": {
        const d = Math.sign(params.part ?? 0.3) || 1
        const k = clamp(0.5 - (u * d) / (UT * 2))
        return lerp(hlY, lerp(hlY, lerp(hlY, browY, 0.3), k), edge)
      }
      case "curtain":
        return lerp(hlY, lerp(hlY + 2, yB + 6, Math.pow(au / UT, 0.8)), edge)
      case "spiky":
        return lerp(hlY, lerp(hlY + 2, yB, (Math.sin(u * 22) + 1) / 2), edge)
      default:
        return -Infinity
    }
  }
  const sideBottom = (au: number): number => {
    if (params.tucked) return au < 1.3 ? lerp(templeY, browY, smooth(UT, 1.3, au)) : lerp(browY, sideY, smooth(1.3, 1.6, au))
    const sb = long ? sideY : Math.min(sideY, browY + 14)
    // costeleta curta à frente da orelha
    const burn = !long && !L.female && age > 14 ? Math.exp(-Math.pow((au - 1.42) / 0.07, 2)) * L.earH * 0.35 : 0
    return lerp(templeY, sb, smooth(UT, UT + (long ? 0.2 : 0.45), au)) + burn
  }
  const top = (u: number): number => {
    if (horseshoe) return browY - skullRy * lerp(0.42, 0.62, smooth(1.2, 2.6, Math.abs(u)))
    if (special === "mohawk") return Math.abs(u) < 0.26 || Math.abs(u) > 2.9 ? shell.yTop : Infinity
    return shell.yTop
  }
  const bot = (u: number): number => {
    const au = Math.abs(u)
    if (special === "mohawk") return au < 0.26 ? hlY : au > 2.9 ? napeY : -Infinity
    let b: number
    if (au <= UT) b = hairline(au)
    else if (au <= UE) b = sideBottom(au)
    else if (au <= UB) b = lerp(sideBottom(UE), napeY, smooth(UE, UB, au))
    else b = napeY
    if (au < UT + 0.05) b = Math.max(b, fringeBot(u))
    if (params.fade && au > 0.85 && !long) b = Math.min(b, browY - skullRy * (0.25 + clamp(params.fade / 1.5) * 0.4))
    return b
  }
  let buzz: HairModel["buzz"] = null
  if (params.fade && !long) {
    const fz = clamp(params.fade / 1.5)
    const fadeTop = browY - skullRy * (0.25 + fz * 0.4)
    buzz = { top: (u) => (Math.abs(u) > 0.7 ? fadeTop - 4 : Infinity), bot: (u) => {
        const au = Math.abs(u)
        if (au <= 0.7) return -Infinity
        if (au > UB) return napeY
        return au > 1.25 && au < 1.95 ? browY - 6 : browY - 1
      }, alpha: 0.32 * (1 - fz * 0.4) }
  }
  if (special === "mohawk") buzz = { top: () => y0, bot: (u) => (Math.abs(u) < 0.6 ? hairline(Math.abs(u)) : Math.abs(u) < UE ? browY + 8 : napeY), alpha: 0.3 }

  const capOnly = special === "shaved" || special === "buzz" || special === "fuzz" || special === "cornrows"
  const capAlpha = special === "shaved" ? 0.16 : special === "buzz" ? 0.42 : special === "fuzz" ? 0.3 : 1

  // --- mechas em (u, y) ---
  const partU = (params.part ?? 0.25) * (r.chance(0.5) ? 1 : -1) * 0.8
  const inside = (u: number, y: number): boolean => y >= top(u) && y <= bot(u)
  const wave = tex < 0.4 ? 0.4 : tex < 1.4 ? 0.4 + (tex - 0.4) * 3 : 3.4 + (tex - 1.4) * 3
  const period = tex < 1.4 ? 64 - tex * 16 : 34 - (tex - 1.4) * 12
  const clumps: Clump[] = []
  const curls: Pt[] = []
  const strands: HairModel["strands"] = []
  const rows: Pt[][] = []
  const dots: Pt[] = []
  const textured = special === "afro" || tex > 2.2 || special === "twists"
  const nSeeds = capOnly ? 0 : special === "locs" || special === "boxbraids" ? 0 : textured ? 0 : long ? 300 : 190
  const phaseSeed = hashText(seed) % 997
  const flow = (u: number, y: number): [number, number] => {
    const au = Math.abs(u)
    if (params.fringe && params.fringe !== "back" && au < UT && y > hlY - 14) {
      const f = params.fringe
      if (f === "quiff" || f === "pomp") return [0, -1]
      const side = f === "side" || f === "swept" || f === "wisp" ? -(Math.sign(partU) || 1) : f === "curtain" ? Math.sign(u) : 0
      return [side * 0.6, 1]
    }
    if (y < browY - 4) {
      if (params.slick || params.fringe === "back") return [0, au < 1.4 ? -1 : 1]
      const d = wrap(u - partU)
      const near = Math.exp(-(y - shell.yTop) / 45)
      return [Math.sign(d) * (au < 1.6 ? 0.9 : 0.3) * near + (1 - near) * 0.05 * Math.sign(d), 0.35 + (1 - near)]
    }
    return [Math.sign(u) * 0.04 * (tex + 0.5), 1]
  }
  let guard = 0
  while (clumps.length < nSeeds && guard++ < nSeeds * 40) {
    const u = -Math.PI + r.next() * Math.PI * 2
    const y = shell.yTop + r.next() * (yBot - shell.yTop)
    if (!inside(u, y)) continue
    if (thin > 0 && y < browY - skullRy * 0.3 && r.next() < thin * 0.85) continue
    const len = (long ? 50 + r.next() * 100 : 12 + r.next() * 24) * (tex > 1.4 ? 0.8 : 1)
    const pts: Pt[] = []
    let cu = u, cy = y
    const ph0 = r.next() * 0.8
    for (let s = 0; s < len; s += 5) {
      const w = Math.max(hs(cy).w, 4)
      const off = (wave * Math.sin((cy / period) * Math.PI * 2 + valueNoise(cu * 3, 0, phaseSeed) * 3 + ph0)) / w
      pts.push([cu + off, cy])
      const [fx, fy] = flow(cu, cy)
      const n = Math.hypot(fx, fy) || 1
      cu += ((fx / n) * 5) / w
      cy += (fy / n) * 5
      if (!inside(cu, cy)) break
    }
    if (pts.length < 2) continue
    clumps.push({ pts, w: (long ? 6 + r.next() * 7 : 4 + r.next() * 4) * (1 + tex * 0.12), tone: 0.78 + r.next() * 0.4, prot: 0.8 + r.next() * 2 })
  }
  // de baixo para cima: raízes mais altas por cima
  clumps.sort((a, b) => b.pts[0]![1] - a.pts[0]![1])

  if (textured) {
    for (let i = 0; i < 1400 && curls.length < 900; i++) {
      const u = -Math.PI + r.next() * Math.PI * 2
      const y = shell.yTop + r.next() * (yBot - shell.yTop)
      if (inside(u, y)) curls.push([u, y])
    }
  }
  if (special === "locs" || special === "boxbraids") {
    const n = special === "locs" ? 44 : 78
    for (let i = 0; i < n; i++) {
      const u = -Math.PI + ((i + r.next() * 0.6) / n) * Math.PI * 2
      const y1 = bot(u)
      const y0s = shell.yTop + 4
      if (y1 < y0s + 6) continue
      const pts: Pt[] = []
      for (let y = y0s; y <= y1; y += 6) pts.push([u + Math.sin(y * 0.05 + i) * 0.015, y])
      strands.push({ pts, w: special === "locs" ? 7 : 4.6, tone: 0.8 + r.next() * 0.35 })
    }
  }
  if (special === "cornrows") {
    for (let i = 0; i < 11; i++) {
      const uf = -1.35 + (i / 10) * 2.7
      const pts: Pt[] = []
      for (let k = 0; k <= 20; k++) {
        const t = k / 20
        const u = uf * (1 - t * 0.35)
        const y = lerp(bot(uf) - 2, shell.yTop + 6, t)
        pts.push([u, y])
      }
      rows.push(pts)
      const back: Pt[] = []
      const ub = Math.PI - (i - 5) * 0.16
      for (let k = 0; k <= 12; k++) back.push([wrap(ub), lerp(shell.yTop + 6, napeY - 2, k / 12)])
      rows.push(back)
    }
  }
  if (capOnly || buzz) {
    for (let i = 0; i < 1200; i++) dots.push([-Math.PI + r.next() * Math.PI * 2, y0 + r.next() * (napeY - y0)])
  }

  // --- amarrações ---
  const ties: Tie[] = []
  const P = (u: number, y: number, prot: number): V3 => {
    const p = shellPoint(shell, u, y, prot)
    return { x: p.x, y: p.y, z: p.z }
  }
  const curlyTie = tex > 2
  switch (params.tie) {
    case "bun":
    case "messybun":
      ties.push({ kind: "sphere", c: P(Math.PI * 0.92, y0 + skullRy * 0.12, rx * 0.2), r: rx * 0.33, curly: curlyTie })
      break
    case "topknot":
      ties.push({ kind: "sphere", c: P(Math.PI * 0.85, y0 + 2, rx * 0.12), r: rx * 0.22, curly: curlyTie })
      break
    case "afropuff":
      ties.push({ kind: "sphere", c: P(Math.PI * 0.8, y0 - 4, rx * 0.35), r: rx * 0.62, curly: true })
      break
    case "puffs":
      for (const s of [-1, 1]) ties.push({ kind: "sphere", c: P(s * 1.05, y0 + skullRy * 0.3, rx * 0.25), r: rx * 0.36, curly: true })
      break
    case "lowbun":
      ties.push({ kind: "sphere", c: P(Math.PI, noseY - 4, rx * 0.2), r: rx * 0.3, curly: curlyTie })
      break
    case "halfup":
      ties.push({ kind: "sphere", c: P(Math.PI * 0.95, browY - skullRy * 0.3, rx * 0.1), r: rx * 0.17, curly: curlyTie })
      break
    case "ponytail":
    case "lowtail": {
      const start = P(Math.PI, params.tie === "ponytail" ? y0 + skullRy * 0.35 : noseY + 6, 2)
      const end = ySide(params.len)
      const pts: V3[] = []
      for (let k = 0; k <= 14; k++) {
        const t = k / 14
        pts.push({ x: start.x + Math.sin(t * 3) * 4, y: lerp(start.y, end, t), z: start.z - 8 - Math.sin(t * Math.PI * 0.5) * 18 + t * 6 })
      }
      ties.push({ kind: "tube", pts, r: rx * 0.15 * (1 + tex * 0.2), braid: false })
      break
    }
    case "pigtails":
      for (const s of [-1, 1]) {
        const a = P(s * 1.45, browY - 16, 4)
        const pts: V3[] = []
        for (let k = 0; k <= 10; k++) {
          const t = k / 10
          pts.push({ x: a.x + s * Math.sin(t * 1.8) * 26, y: a.y + t * (60 + 50 * params.len) * lenK, z: a.z - 6 })
        }
        ties.push({ kind: "tube", pts, r: rx * 0.14, braid: false })
      }
      break
    case "braids":
    case "sidebraid": {
      const sides = params.tie === "braids" ? [-1, 1] : [Math.sign(partU) || 1]
      for (const s of sides) {
        const a = P(s * 1.3, browY + 8, 3)
        const end = Math.min(ySide(params.len), 540)
        const pts: V3[] = []
        for (let k = 0; k <= 16; k++) {
          const t = k / 16
          const y = lerp(a.y, end, t)
          const k2 = smooth(0, 1, (y - jawY) / 60)
          pts.push({ x: lerp(a.x, s * (L.neckW * 0.5 + 16), k2), y, z: lerp(a.z, rx * 0.25, k2) })
        }
        ties.push({ kind: "tube", pts, r: rx * 0.09, braid: true })
      }
      break
    }
    default:
      break
  }

  const base = hairColor(ph.hairEumelanin, ph.hairPheomelanin)
  return {
    params,
    color: base,
    grey: ph.grey,
    tex,
    shell,
    tight,
    top,
    bot,
    buzz,
    clumps,
    curls,
    strands,
    rows,
    dots,
    ties,
    sheenY: y0 + skullRy * 0.3 - vt * 0.2,
    thin,
    capOnly,
    capAlpha,
  }
}

// ---------------------------------------------------------------------------

function hairTone(H: HairModel, k: number): RGB {
  const c = mul(H.color, k)
  return mix(c, mix(GREY_HAIR, WHITE_HAIR, 0.4), H.grey * 0.85)
}

function ribbon(pts: readonly Pt[], w0: number): Pt[] {
  const n = pts.length
  const left: Pt[] = [], right: Pt[] = []
  for (let k = 0; k < n; k++) {
    const a = pts[Math.max(0, k - 1)]!, b = pts[Math.min(n - 1, k + 1)]!
    let dx = b[0] - a[0], dy = b[1] - a[1]
    const len = Math.hypot(dx, dy) || 1
    dx /= len
    dy /= len
    const t = k / Math.max(1, n - 1)
    const w = (w0 / 2) * Math.min(1, t * 5 + 0.4) * (1 - t * 0.7)
    const p = pts[k]!
    left.push([p[0] - dy * w, p[1] + dx * w])
    right.push([p[0] + dy * w, p[1] - dx * w])
  }
  return [...left, ...right.reverse()]
}

function drawTie(p: Painter, H: HairModel, view: View, t: Tie): void {
  const dark = hex(hairTone(H, 0.62))
  const mid = hex(hairTone(H, 0.95))
  const light = hex(hairTone(H, 1.25))
  if (t.kind === "sphere") {
    const c = view.project({ x: t.c.x, y: t.c.y, z: t.c.z, nx: 0, nz: 1 })
    const d = ellipseD(c.X, c.Y, t.r, t.r * 0.94)
    const g = p.radial(c.X - t.r * 0.35, c.Y - t.r * 0.4, t.r * 1.4, [[0, light, 1], [0.55, mid, 1], [1, dark, 1]])
    p.fill(d, g)
    // voltas do coque
    const n = t.curly ? 18 : 5
    for (let i = 0; i < n; i++) {
      const a0 = (i / n) * Math.PI * 2 + view.yaw
      const rr = t.r * (t.curly ? 0.3 + (i % 3) * 0.2 : 0.55 + (i % 2) * 0.25)
      const pts: Pt[] = []
      for (let k = 0; k <= 8; k++) {
        const a = a0 + (k / 8) * (t.curly ? 2.4 : 1.6)
        pts.push([c.X + Math.cos(a) * rr * (t.curly ? 1 : 1.1) + (t.curly ? Math.cos(a0 * 3) * t.r * 0.35 : 0), c.Y + Math.sin(a) * rr * 0.85 + (t.curly ? Math.sin(a0 * 2) * t.r * 0.3 : 0)])
      }
      p.stroke(smoothD(pts, false), i % 2 ? light : dark, t.curly ? 1.4 : 1.6, 0.55)
    }
    return
  }
  const pts: Pt[] = t.pts.map((q) => {
    const pr = view.project({ x: q.x, y: q.y, z: q.z, nx: 0, nz: 1 })
    return [pr.X, pr.Y] as Pt
  })
  const d = smoothD(pts, false)
  p.add({ d, stroke: dark, width: t.r * 2 + 2, cap: "round", join: "round" })
  p.add({ d, stroke: mid, width: t.r * 2 - 1, cap: "round", join: "round" })
  if (t.braid) {
    for (let i = 1; i < pts.length - 1; i++) {
      const a = pts[i - 1]!, b = pts[i + 1]!
      const q = pts[i]!
      const dx = b[0] - a[0], dy = b[1] - a[1]
      const len = Math.hypot(dx, dy) || 1
      const nx = -dy / len, ny = dx / len
      const s = i % 2 ? 1 : -1
      p.stroke(polyD([[q[0] + nx * t.r * s, q[1] + ny * t.r * s - 3], [q[0] - nx * t.r * s * 0.2, q[1] + 4]], false), dark, 1.4, 0.8)
    }
  } else {
    p.add({ d, stroke: light, width: t.r * 0.5, cap: "round", opacity: 0.35 })
  }
}

function tieDepth(view: View, t: Tie): number {
  const c = t.kind === "sphere" ? t.c : t.pts[Math.floor(t.pts.length / 2)]!
  return -c.x * view.s + c.z * view.c
}

/** Camada de trás: tudo que o cabelo cobre, antes do corpo e da cabeça. */
export function drawHairBack(p: Painter, H: HairModel, view: View): void {
  for (const t of H.ties) if (tieDepth(view, t) < -4) drawTie(p, H, view, t)
  if (H.capOnly) return
  const hull = coverageHull(H.shell, view, H.top, H.bot, 0, 6, 40)
  if (hull.length > 2) p.fill(smoothD(hull), hex(hairTone(H, 0.5)))
}

/** Frente: parte visível do cabelo, depois da cabeça. Devolve o polígono (para a sombra no rosto). */
export function hairFrontPolygons(H: HairModel, view: View): Pt[][] {
  if (H.capOnly) return []
  return regionPolygons(H.shell, view, H.top, H.bot, 0, 5, 44).filter((q) => q.length > 2)
}

export function drawHairFront(p: Painter, H: HairModel, view: View, polys: readonly Pt[][], L: FaceLayout): void {
  const poly: Pt[] = polys.flat()
  const base = hairTone(H, 1)
  // raspados e laterais do degradê
  const drawBuzz = (top: (u: number) => number, bot: (u: number) => number, alpha: number): void => {
    const bp = regionPolygons(H.tight, view, top, bot, 0.5, 5, 40).filter((q) => q.length > 2)
    if (bp.length === 0) return
    const d = bp.map((q) => smoothD(q)).join("")
    p.fill(d, hex(mix(base, [110, 110, 110], H.grey * 0.5)), alpha)
    const clip = p.clip(d)
    let dd = ""
    for (const [u, y] of H.dots) {
      if (y < top(u) || y > bot(u)) continue
      const q = view.project(shellPoint(H.tight, u, Math.min(y, H.tight.yBot), 0.6))
      if (q.facing <= 0.05) continue
      dd += `M${q.X.toFixed(1)} ${q.Y.toFixed(1)}h0.9v1.6h-0.9Z`
    }
    if (dd) p.fill(dd, hex(mul(base, 0.8)), Math.min(1, alpha + 0.25), clip)
  }
  if (H.capOnly) {
    if (H.params.special === "cornrows") {
      const cap = regionPolygons(H.tight, view, () => H.tight.yTop, H.bot, 0.5, 5, 40).filter((q) => q.length > 2)
      if (cap.length) p.fill(cap.map((q) => smoothD(q)).join(""), hex(mul(base, 0.45)))
      for (const row of H.rows) {
        for (const run of projectRuns(H.tight, view, row, 2)) {
          if (run.length < 2) continue
          const d = smoothD(run, false)
          p.add({ d, stroke: hex(mul(base, 0.75)), width: 7, cap: "round", join: "round" })
          p.add({ d, stroke: hex(mul(base, 1.15)), width: 2.2, cap: "round", join: "round", opacity: 0.6 })
        }
      }
      return
    }
    drawBuzz(() => H.tight.yTop, (u) => Math.min(H.bot(u), H.tight.yBot), H.capAlpha)
    return
  }
  if (H.buzz) drawBuzz(H.buzz.top, H.buzz.bot, H.buzz.alpha)
  if (poly.length < 3) {
    for (const t of H.ties) if (tieDepth(view, t) >= -4) drawTie(p, H, view, t)
    return
  }
  const d = polys.map((q) => smoothD(q)).join("")
  let xl = Infinity, xr = -Infinity, yt = Infinity
  for (const [x, y] of poly) {
    if (x < xl) xl = x
    if (x > xr) xr = x
    if (y < yt) yt = y
  }
  p.fill(d, hex(mul(base, 0.78)), H.thin > 0 ? 1 - H.thin * 0.35 : 1)
  const clip = p.clip(d)

  // mechas
  if (H.clumps.length) {
    const buckets = new Map<number, { fill: string; hi: string }>()
    const acc = new Map<number, string>()
    const accHi = new Map<number, string>()
    for (const c of H.clumps) {
      const tb = Math.round(clamp((c.tone - 0.78) / 0.4) * 4)
      for (const run of projectRuns(H.shell, view, c.pts, c.prot, 0.02)) {
        if (run.length < 2) continue
        const rib = ribbon(run, c.w)
        acc.set(tb, (acc.get(tb) ?? "") + polyD(rib))
        accHi.set(tb, (accHi.get(tb) ?? "") + polyD(run, false))
      }
      if (!buckets.has(tb)) {
        const k = 0.78 + (tb / 4) * 0.4
        buckets.set(tb, { fill: hex(hairTone(H, k * 0.95)), hi: hex(hairTone(H, k * 1.22)) })
      }
    }
    for (const [tb, path] of acc) {
      const b = buckets.get(tb)!
      p.fill(path, b.fill, 0.92, clip)
      const hi = accHi.get(tb)
      if (hi) p.add({ d: hi, stroke: b.hi, width: 1.6, opacity: 0.45, clip, cap: "round", join: "round" })
    }
  }
  // cachos crespos
  if (H.curls.length) {
    const acc: string[] = ["", "", ""]
    for (const [u, y] of H.curls) {
      const q = view.project(shellPoint(H.shell, u, Math.min(y, H.shell.yBot), 1))
      if (q.facing <= 0.02) continue
      const k = Math.abs(Math.floor(u * 97 + y * 13)) % 3
      const rr = 2.2 + ((Math.floor(y * 7) % 3) as number) * 0.8
      const a = (u * 5 + y) % 6.28
      acc[k] += `M${(q.X + Math.cos(a) * rr).toFixed(1)} ${(q.Y + Math.sin(a) * rr).toFixed(1)}a${rr.toFixed(1)} ${rr.toFixed(1)} 0 1 1 ${(-2 * Math.cos(a) * rr).toFixed(1)} ${(-2 * Math.sin(a) * rr).toFixed(1)}`
    }
    const tones = [0.6, 0.95, 1.3]
    acc.forEach((path, k) => {
      if (path) p.add({ d: path, stroke: hex(hairTone(H, tones[k]!)), width: 1.3, opacity: 0.7, clip, cap: "round" })
    })
    // borda fofa
    let fluff = ""
    for (let i = 0; i < poly.length; i++) {
      const [x, y] = poly[i]!
      if (y > L.browY + 20 && H.bot(0) < L.browY) continue
      const rr = 2.5 + ((i * 7) % 5) * 0.7
      fluff += ellipseD(x + ((i * 3) % 3) - 1, y + ((i * 5) % 3) - 1, rr, rr)
    }
    if (fluff) p.fill(fluff, hex(mul(base, 0.78)))
  }
  // dreads e box braids
  if (H.strands.length) {
    const acc = ["", ""]
    for (const s of H.strands) {
      for (const run of projectRuns(H.shell, view, s.pts, 2, 0.02)) {
        if (run.length < 2) continue
        acc[s.tone > 0.97 ? 1 : 0] += polyD(run, false)
      }
    }
    const w = H.params.special === "locs" ? 7 : 4.6
    acc.forEach((path, k) => {
      if (!path) return
      p.add({ d: path, stroke: hex(hairTone(H, k ? 1 : 0.72)), width: w, cap: "round", join: "round", clip })
      p.add({ d: path, stroke: hex(hairTone(H, 0.5)), width: w * 0.25, cap: "butt", join: "round", opacity: 0.5, clip })
    })
  }
  // brilho: faixa na calota que acompanha o giro
  const sp = view.project(shellPoint(H.shell, view.uFace - 0.55, H.sheenY, 2))
  const sheenCol = hex(mix(base, [255, 246, 228], 0.5))
  p.fill(d, p.radial(sp.X, sp.Y, L.rx * 0.7, [[0, sheenCol, H.tex > 2 ? 0.18 : 0.38], [1, sheenCol, 0]], 1, 0.45, -0.35), 1, clip)
  // volume: luz da esquerda, sombra embaixo
  const g = p.linear(xl, 0, xr, 0, [[0, "#fff4e6", 0.12], [0.35, "#000000", 0], [0.8, "#000000", 0.28], [1, "#000000", 0.4]])
  p.fill(d, g, 1, clip)
  const g2 = p.linear(0, yt, 0, L.shoulderY + 60, [[0, "#000000", 0], [0.55, "#000000", 0.1], [1, "#000000", 0.35]])
  p.fill(d, g2, 1, clip)
  for (const t of H.ties) if (tieDepth(view, t) >= -4) drawTie(p, H, view, t)
}

export function hairShadowOnFace(p: Painter, polys: readonly Pt[][], headClip: string): void {
  if (polys.length === 0) return
  const shift = (dx: number, dy: number): string => polys.map((poly) => polyD(poly.map(([x, y]) => [x + dx, y + dy] as Pt))).join("")
  p.fill(shift(2, 3), "#2a1410", 0.14, headClip)
  p.fill(shift(4, 7), "#2a1410", 0.1, headClip)
}
