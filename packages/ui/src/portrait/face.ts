// Rosto: traços desenhados de frente e embrulhados na cabeça (HeadView.warp).

import { seededRandom, hashText, type AppearanceGenome, type GlassesId, type Phenotype } from "@paralelo/simulation"
import { shadeAcross } from "./body"
import { ellipseD, polyD, smoothD, type Painter } from "./display"
import type { FaceLayout } from "./geometry"
import type { HeadView } from "./head"
import { clamp, cubicPts, hex, lerp, mix, mul, quadPts, smooth, type Pt, type RGB } from "./math"
import { shellPoint } from "./shell"

type Ctx = { p: Painter; hv: HeadView; L: FaceLayout; g: AppearanceGenome; ph: Phenotype; skin: RGB; age: number; makeup: number; headClip: string }

const sq = (f: number): number => clamp(f, 0.08, 1)

// ---------------- pele da cabeça ----------------
export function drawHeadSkin(c: Ctx, sil: readonly Pt[]): void {
  const { p, hv, L, skin, g } = c
  const d = smoothD(sil)
  let xl = Infinity, xr = -Infinity
  for (const [x] of sil) {
    if (x < xl) xl = x
    if (x > xr) xr = x
  }
  p.fill(d, hex(skin))
  shadeAcross(p, d, xl, xr, skin, undefined, 0.9)
  const clip = c.headClip
  // luz na testa e nas maçãs
  const fh = hv.warp(L.cx - L.rx * 0.15, L.browY - (L.browY - L.hairlineY) * 0.5)
  p.fill(d, p.radial(fh.X, fh.Y, L.rx * 0.55, [[0, "#fff6ea", 0.22], [1, "#fff6ea", 0]], sq(fh.facing), 0.7), 1, clip)
  // sombra sob as maçãs e mandíbula
  const jawShade = p.linear(0, L.mouthY, 0, L.chinY + 4, [[0, "#3a1a14", 0], [0.7, "#3a1a14", 0.1], [1, "#3a1a14", 0.24]])
  p.fill(d, jawShade, 1, clip)
  for (const s of [-1, 1]) {
    const ck = hv.warp(L.cx + s * L.rx * 0.62, L.mouthY - L.eyeW * 0.2)
    if (ck.facing > 0.1) p.fill(ellipseD(ck.X, ck.Y, L.rx * 0.28 * sq(ck.facing), L.rx * 0.22), p.radial(ck.X, ck.Y, L.rx * 0.3, [[0, "#3a1a14", 0.08 + L.thin * 0.12], [1, "#3a1a14", 0]], sq(ck.facing), 0.8), 1, clip)
    // bochecha rosada
    const bl = hv.warp(L.cx + s * L.rx * 0.55, L.eyeY + L.eyeW * 1.1)
    const rosy = 0.16 * g.skin.rosiness + L.baby * 0.15 + c.makeup * 0.1
    if (bl.facing > 0.05) p.fill(ellipseD(bl.X, bl.Y, L.rx * 0.34 * sq(bl.facing), L.rx * 0.25), p.radial(bl.X, bl.Y, L.rx * 0.32, [[0, "#dc5a5a", rosy], [1, "#dc5a5a", 0]], sq(bl.facing), 0.75), 1, clip)
    // órbita
    const eo = hv.warp(L.cx + s * L.eyeOff, L.eyeY - L.eyeW * 0.05)
    if (eo.facing > 0) p.fill(ellipseD(eo.X, eo.Y, L.eyeW * 0.9 * sq(eo.facing), L.eyeW * 0.6), p.radial(eo.X, eo.Y, L.eyeW * 0.85, [[0, "#3a1a18", 0.16 + L.old * 0.1], [1, "#3a1a18", 0]], sq(eo.facing), 0.62), 1, clip)
  }
  drawMarks(c)
  drawWrinkles(c)
}

function drawMarks(c: Ctx): void {
  const { p, hv, L, g, ph, skin, age } = c
  const r = seededRandom(hashText(g.seed + ":marks"))
  const moles = Math.round(g.skin.moles * smooth(2, 25, age))
  let md = ""
  for (let i = 0; i < moles; i++) {
    const x = L.cx + r.normal() * L.rx * 0.55, y = lerp(L.hairlineY + 10, L.chinY - 6, r.next())
    const w = hv.warp(x, y)
    if (w.facing > 0.15) md += ellipseD(w.X, w.Y, (0.6 + r.next() * 0.6) * sq(w.facing), 0.6 + r.next() * 0.6)
  }
  if (md) p.fill(md, hex(mul(skin, 0.5)), 0.6, c.headClip)
  const fN = Math.floor(ph.freckles * 160 * (1 - smooth(50, 80, age) * 0.5))
  let fd = ""
  for (let i = 0; i < fN; i++) {
    const s = r.chance(0.5) ? -1 : 1
    const x = L.cx + s * Math.abs(r.normal()) * L.rx * 0.42, y = L.eyeY + L.eyeW * 0.4 + r.normal() * L.eyeW * 0.7
    const w = hv.warp(x, y)
    if (w.facing > 0.15) fd += ellipseD(w.X, w.Y, 0.9 * sq(w.facing), 0.9)
  }
  if (fd) p.fill(fd, hex(mix(mul(skin, 0.72), [150, 80, 40], 0.2)), 0.45, c.headClip)
  const spN = Math.floor(smooth(55, 90, age) * 12 * (1 - ph.melanin * 0.7) * g.skin.agingRate)
  let sd = ""
  for (let i = 0; i < spN; i++) {
    const w = hv.warp(L.cx + r.normal() * L.rx * 0.6, lerp(L.hairlineY - 20, L.noseY, r.next()))
    const rr = 2 + r.next() * 3
    if (w.facing > 0.15) sd += ellipseD(w.X, w.Y, rr * sq(w.facing), rr)
  }
  if (sd) p.fill(sd, hex(mix(mul(skin, 0.75), [140, 90, 50], 0.2)), 0.25, c.headClip)
}

function strokeWarp(c: Ctx, pts: readonly Pt[], color: string, width: number, opacity: number, prot = 0): void {
  if (opacity < 0.02) return
  const w = pts.map(([x, y]) => c.hv.warp(x, y, prot))
  const vis = w.filter((q) => q.facing > 0.05)
  if (vis.length < 2) return
  c.p.stroke(smoothD(vis.map((q): Pt => [q.X, q.Y]), false), color, width, opacity, c.headClip)
}

function drawWrinkles(c: Ctx): void {
  const { L, age, g, skin } = c
  const line = hex(mul(skin, 0.62))
  const ag = smooth(30, 85, age) * g.skin.agingRate
  for (let i = 0; i < 3; i++) {
    const y = L.browY - (L.browY - L.hairlineY) * (0.3 + i * 0.17)
    strokeWarp(c, quadPts([L.cx - L.rx * 0.45, y], [L.cx, y - 3], [L.cx + L.rx * 0.45, y], 8), line, 1.1, 0.5 * ag * (1 - i * 0.2))
  }
  const nl = clamp(0.3 + smooth(25, 75, age) * 0.7 + L.fat * 0.2) * L.growth
  for (const s of [-1, 1]) {
    strokeWarp(c, quadPts([L.cx + s * L.noseW * 0.55, L.noseY - L.noseLen * 0.12], [L.cx + s * L.mouthW * 0.62, L.mouthY - 6], [L.cx + s * L.mouthW * 0.6, L.mouthY + 6 + L.old * 6], 8), line, 1.4, 0.3 + nl * 0.3)
    if (ag > 0.15) {
      for (let k = -1; k <= 1; k++) {
        const ox = L.cx + s * (L.eyeOff + L.eyeW * 0.62)
        strokeWarp(c, [[ox, L.eyeY + k * 3], [ox + s * L.eyeW * 0.35, L.eyeY + k * 5 - 2]], line, 1, 0.5 * ag)
      }
      strokeWarp(c, quadPts([L.cx + s * (L.eyeOff - L.eyeW * 0.4), L.eyeY + L.eyeW * 0.38], [L.cx + s * L.eyeOff, L.eyeY + L.eyeW * 0.66], [L.cx + s * (L.eyeOff + L.eyeW * 0.45), L.eyeY + L.eyeW * 0.46], 6), line, 1.1, 0.45 * smooth(38, 85, age))
    }
    if (L.old > 0.15) strokeWarp(c, [[L.cx + s * L.mouthW * 0.52, L.mouthY + 3], [L.cx + s * L.mouthW * 0.56, L.mouthY + 16 + L.old * 6]], line, 1.2, 0.5 * L.old)
  }
}

// ---------------- orelhas ----------------
const EAR_OUTLINE: readonly Pt[] = [[0, 0.06], [0.45, -0.03], [0.85, 0.08], [1, 0.3], [0.94, 0.55], [0.7, 0.84], [0.42, 1.02], [0.12, 0.98], [0, 0.88]]
const EAR_HELIX: readonly Pt[] = [[0.35, 0.14], [0.72, 0.2], [0.8, 0.45], [0.62, 0.72], [0.42, 0.82]]

export function earIsNear(c: Ctx, s: number): boolean {
  const q = c.hv.view.project(shellPoint(c.hv.head.shell, s * Math.PI / 2, c.L.browY + c.L.earH / 2))
  return q.Z > -c.L.rx * 0.18
}

export function drawEar(c: Ctx, s: number): void {
  const { p, hv, L, skin } = c
  const view = hv.view
  const top = L.browY + 2
  const alpha = clamp(0.3 + L.earOut * 1.4, 0.18, 1.1)
  const depth = L.earH * 0.56
  const dx = s * Math.sin(alpha), dz = -Math.cos(alpha)
  const uBase = s * (Math.PI / 2 + 0.08)
  const pt = (a: number, v: number): Pt => {
    const b = shellPoint(hv.head.shell, uBase, top + v * L.earH, -1)
    const q = view.project({ x: b.x + dx * a * depth, y: b.y, z: b.z + dz * a * depth, nx: 0, nz: 1 })
    return [q.X, q.Y]
  }
  const outline = EAR_OUTLINE.map(([a, v]) => pt(a, v))
  const d = smoothD(outline)
  const earSkin = mix(skin, [205, 110, 100], 0.12)
  p.fill(d, hex(earSkin))
  // face visível da orelha: normal (s·cos α, 0, sen α) girada
  const nz = -(s * Math.cos(alpha)) * view.s + Math.sin(alpha) * view.c
  const vis = clamp(Math.abs(nz))
  p.fill(d, hex(mul(earSkin, 0.75)), 0.25 + (1 - vis) * 0.2)
  p.stroke(smoothD(EAR_HELIX.map(([a, v]) => pt(a, v)), false), hex(mul(earSkin, 0.6)), 1.4, 0.35 + vis * 0.4)
  const cc = pt(0.32, 0.52)
  if (vis > 0.25) p.fill(ellipseD(cc[0], cc[1], L.earH * 0.1 * vis, L.earH * 0.16), hex(mul(earSkin, 0.62)), 0.55 * vis)
}

// ---------------- olhos ----------------
export function drawEyes(c: Ctx, iris: RGB): void {
  for (const s of [-1, 1]) drawEye(c, s, iris)
}

function drawEye(c: Ctx, s: number, iris: RGB): void {
  const { p, hv, L, g, ph, makeup } = c
  const w = L.eyeW
  const ex = L.cx + s * L.eyeOff
  const ey = L.eyeY + L.asymEye[s < 0 ? 0 : 1]
  const f = hv.facing(ex, ey)
  if (f < -0.05) return
  const h = w * L.open
  const tilt = L.tilt * w
  const X = (u: number): number => ex + s * u
  const hood = clamp(0.25 * g.face.hood + L.old * 0.9 + (g.face.lidFold < -0.6 ? 0.3 : 0), 0, 1.2)
  const monolid = g.face.lidFold < -0.6
  const inner: Pt = [X(-w / 2), ey + tilt * 0.5 + w * 0.04]
  const outer: Pt = [X(w / 2), ey - tilt * 0.5]
  const up1: Pt = [X(-w * 0.22), ey - h * 1.02 + tilt * 0.2]
  const up2: Pt = [X(w * 0.22), ey - h * (1 - hood * 0.22) - tilt * 0.25]
  const lo1: Pt = [X(w * 0.24), ey + h * 0.62 - tilt * 0.1]
  const lo2: Pt = [X(-w * 0.2), ey + h * 0.6 + tilt * 0.15]
  const upper = cubicPts(inner, up1, up2, outer, 12)
  const lower = cubicPts(outer, lo1, lo2, inner, 10, false)
  const openW = hv.pts([...upper, ...lower], -0.5)
  const openD = smoothD(openW)
  const clip = p.clip(openD)
  const center = hv.warp(ex, ey, 0)
  const fx = sq(center.facing)
  // esclera
  p.fill(openD, p.radial(center.X, center.Y, w * 0.6, [[0, "#e8e2da", 1], [0.65, "#d4c8c0", 1], [1, "#b2908a", 1]], fx, 0.7))
  // íris e pupila
  const ir = w * lerp(0.255, 0.205, L.growth) * (1 - L.old * 0.03)
  const ic = hv.warp(ex + s * w * 0.01, ey - h * 0.08, 0.6)
  const irisD = ellipseD(ic.X, ic.Y, ir * fx, ir)
  p.fill(irisD, p.radial(ic.X, ic.Y, ir, [[0, hex(mix(iris, [200, 170, 90], 0.25)), 1], [0.45, hex(iris), 1], [0.85, hex(mul(iris, 0.72)), 1], [1, hex(mul(iris, 0.35)), 1]], fx, 1), 1, clip)
  p.add({ d: irisD, stroke: "#1a1210", width: ir * 0.12, opacity: 0.5, clip })
  const pr = ir * lerp(0.46, 0.36, L.growth) * (1 - L.old * 0.12)
  p.fill(ellipseD(ic.X, ic.Y, pr * fx, pr), "#0b0909", 1, clip)
  // sombra da pálpebra superior sobre o olho
  p.fill(openD, p.linear(0, ey - h, 0, ey + h * 0.2, [[0, "#281410", 0.6], [0.45, "#281410", 0.15], [1, "#281410", 0]]), 1, clip)
  // reflexos
  p.fill(ellipseD(ic.X - ir * 0.38 * fx, ic.Y - ir * 0.38, ir * 0.17 * fx + 0.3, ir * 0.14), "#ffffff", 0.92, clip)
  p.fill(ellipseD(ic.X + ir * 0.35 * fx, ic.Y + ir * 0.35, ir * 0.07 * fx + 0.2, ir * 0.07), "#ffffff", 0.25, clip)
  // carúncula
  const car = hv.warp(inner[0] + s * w * 0.05, inner[1] - 0.5)
  p.fill(ellipseD(car.X, car.Y, w * 0.06 * fx, h * 0.25), "#cd7873", 0.7, clip)

  // cílios e pálpebras
  const lashCol = makeup > 0.3 ? "#080606" : hex([22 + (1 - ph.hairEumelanin) * 40, 16 + (1 - ph.hairEumelanin) * 25, 14 + (1 - ph.hairEumelanin) * 12])
  const lid = hv.pts(upper, 0.3)
  p.stroke(smoothD(lid, false), lashCol, w * (0.045 + makeup * 0.03) * 1.25, 0.95)
  if (makeup > 0.55) strokeWarp(c, [[outer[0] - s * w * 0.1, outer[1] - 0.5], [outer[0] + s * w * 0.18, outer[1] - w * 0.12]], "#080606", w * 0.05, 1, 0.3)
  const lashLen = w * (g.sex === "F" ? 0.12 : 0.08) * (1 + L.baby * 0.4 + makeup * 0.5) * (1 - L.old * 0.3)
  let lashes = ""
  for (let i = 3; i < 9; i++) {
    const t = i / 9
    const b = cubicPts(inner, up1, up2, outer, 9)[i]!
    const len = lashLen * (0.5 + t * 0.7)
    const pts = [b, [b[0] + s * len * (0.2 + t * 0.6), b[1] - len * 0.9] as Pt, [b[0] + s * len * (0.4 + t * 0.9), b[1] - len * 0.8] as Pt].map(([x, y]) => hv.warp(x, y, 0.5))
    if (pts[0]!.facing < 0.1) continue
    lashes += `M${pts[0]!.X.toFixed(1)} ${pts[0]!.Y.toFixed(1)}Q${pts[1]!.X.toFixed(1)} ${pts[1]!.Y.toFixed(1)} ${pts[2]!.X.toFixed(1)} ${pts[2]!.Y.toFixed(1)}`
  }
  if (lashes) p.stroke(lashes, lashCol, 1, 0.85)
  strokeWarp(c, [outer, ...cubicPts(outer, lo1, lo2, inner, 8, false)], "#5a322d", 0.9, 0.45)
  if (!monolid) {
    const cr = h * (0.55 + 0.25 * clamp(g.face.lidFold, -1, 1.5)) * (1 - hood * 0.6)
    strokeWarp(c, cubicPts([X(-w * 0.34), ey - h * 0.7 - cr * 0.4], [X(-w * 0.1), ey - h - cr], [X(w * 0.22), ey - h - cr * 0.95], [X(w * 0.52), ey - h * 0.45 - cr * 0.3 + hood * 3], 8), "#462319", 1, 0.3 + L.old * 0.15)
  } else {
    strokeWarp(c, quadPts([inner[0] - s, inner[1] + 1], [X(-w * 0.35), ey - h * 0.95], [X(-w * 0.05), ey - h * 1.05], 6), "#462319", 1, 0.25)
  }
  if (makeup > 0.4) {
    const lidArea = hv.pts([...cubicPts(inner, [X(-w * 0.2), ey - h * 1.8], [X(w * 0.25), ey - h * 1.75], outer, 10), ...cubicPts(outer, up2, up1, inner, 10, false)], 0.2)
    c.p.fill(smoothD(lidArea), "#5a3c46", (makeup - 0.4) * 0.3)
  }
}

// ---------------- sobrancelhas ----------------
export function drawBrows(c: Ctx, col: RGB): void {
  const { p, hv, L, g } = c
  const F = g.sex === "F"
  const acc = ["", "", ""]
  for (const s of [-1, 1]) {
    const w = L.eyeW
    const by = L.browY + L.asymBrow[s < 0 ? 0 : 1] - 1
    const thick = w * (F ? 0.1 : 0.14) * (1 + 0.3 * g.face.browThick) * lerp(0.45, 1, L.growth)
    const arch = w * (F ? 0.16 : 0.09) * (1 + 0.4 * g.face.browArch)
    const len = w * (1.15 + 0.1 * g.face.browLen)
    const gap = w * (0.5 + 0.12 * g.face.browGap)
    const x0 = L.cx + s * gap, x1 = x0 + s * len
    const peak = 0.65
    const yAt = (t: number): number =>
      by - arch * Math.sin(Math.PI * Math.min(t / peak, 1) * 0.5) * (t > peak ? 1 - ((t - peak) / (1 - peak)) * 0.9 : 1) + (t > peak ? (t - peak) * w * 0.25 : 0) + (1 - t) * w * 0.02
    const r = seededRandom(hashText(g.seed + "brow" + s))
    const n = Math.floor(60 * (1 + 0.3 * g.face.browThick) * lerp(0.4, 1, L.growth))
    const bushy = L.old * (F ? 0.2 : 1)
    for (let i = 0; i < n; i++) {
      const t = r.next()
      const x = lerp(x0, x1, t)
      const y = yAt(t) + (r.next() - 0.5) * thick * (1.2 - t * 0.7)
      const ang = t < 0.25 ? -Math.PI / 2 + s * 0.5 : s > 0 ? -0.35 + t * 0.5 : Math.PI + 0.35 - t * 0.5
      const l = (thick * 0.9 + r.next() * thick * 0.6) * (1 + bushy * r.next() * 1.2)
      const pts = [[x, y], [x + Math.cos(ang) * l * 0.5, y + Math.sin(ang) * l * 0.5 - 0.5], [x + Math.cos(ang) * l, y + Math.sin(ang) * l + 0.3]].map(([a, b]) => hv.warp(a!, b!, 0.6))
      if (pts[0]!.facing < 0.08) continue
      acc[i % 3] += `M${pts[0]!.X.toFixed(1)} ${pts[0]!.Y.toFixed(1)}Q${pts[1]!.X.toFixed(1)} ${pts[1]!.Y.toFixed(1)} ${pts[2]!.X.toFixed(1)} ${pts[2]!.Y.toFixed(1)}`
    }
  }
  const tones = [0.75, 1, 1.2]
  acc.forEach((d, k) => {
    if (d) p.add({ d, stroke: hex(mul(col, tones[k]! * (L.baby > 0.5 ? 1.3 : 1))), width: 1.25, opacity: 0.8 * lerp(0.4, 1, L.growth), cap: "round", clip: c.headClip })
  })
}

// ---------------- nariz ----------------
export function drawNose(c: Ctx): void {
  const { p, hv, L, skin } = c
  const P = hv.head.noseTipProt
  const tipX = L.cx + L.asymNose, tipY = L.noseY - L.noseLen * 0.1
  const w = (x: number, y: number, prot: number): Pt => {
    const q = hv.warp(x, y, prot)
    return [q.X, q.Y]
  }
  const bridgeTop = w(L.cx, L.browY + 6, P * 0.04)
  const bridgeMid = w(L.cx + L.asymNose * 0.5, lerp(L.browY, L.noseY, 0.5), P * 0.45)
  const tip = w(tipX, tipY, P)
  const colu = w(tipX, L.noseY + 1, P * 0.35)
  const wings = [-1, 1].map((s) => w(tipX + s * L.noseW * 0.48, L.noseY - 3, P * 0.1))
  const alar = [-1, 1].map((s) => w(tipX + s * L.noseW * 0.3, L.noseY - L.noseLen * 0.28, P * 0.3))
  const yawS = hv.view.s
  const turn = Math.abs(yawS)
  // volume do nariz: casco convexo dos pontos
  const hull = convexHull([bridgeTop, bridgeMid, tip, colu, ...wings, ...alar])
  const hd = smoothD(hull)
  let xl = Infinity, xr = -Infinity
  for (const [x] of hull) {
    if (x < xl) xl = x
    if (x > xr) xr = x
  }
  p.fill(hd, hex(skin), turn * 0.9 + 0.1)
  p.fill(hd, p.linear(xl, 0, xr, 0, [[0, "#fff4e6", 0.18], [0.45, "#000000", 0], [1, "#3a1a14", 0.35]]), 0.4 + turn * 0.6)
  // sombra projetada sob o nariz
  const sh = w(tipX + 2, L.noseY + 4, 0)
  p.fill(ellipseD(sh[0] + 2, sh[1], L.noseW * 0.45 * (1 - turn * 0.4), L.noseW * 0.16), p.radial(sh[0] + 2, sh[1], L.noseW * 0.5, [[0, "#3a1a14", 0.3], [1, "#3a1a14", 0]], 1, 0.4), 1, c.headClip)
  // brilho na ponta
  p.fill(ellipseD(tip[0] - 1.5, tip[1] - 2, L.noseW * 0.12, L.noseW * 0.09), "#fff6ec", 0.22)
  // narinas
  for (const s of [-1, 1]) {
    const q = hv.warp(tipX + s * L.noseW * 0.19, L.noseY - 1, P * 0.18)
    if (q.facing < 0.1) continue
    p.fill(ellipseD(q.X, q.Y, L.noseW * 0.1 * sq(q.facing), L.noseW * 0.05), hex(mul(skin, 0.38)), 0.75)
  }
  // asas do nariz (vistas de frente)
  const wingLine = hex(mul(skin, 0.6))
  for (const s of [-1, 1]) {
    const pts = quadPts([tipX + s * L.noseW * 0.5, L.noseY - L.noseLen * 0.1], [tipX + s * L.noseW * 0.55, L.noseY + 1], [tipX + s * L.noseW * 0.2, L.noseY + 1], 6).map(([x, y]) => w(x, y, P * 0.12))
    p.stroke(smoothD(pts, false), wingLine, 1.4, 0.8 - turn * 0.3)
  }
  // perfil do nariz quando a cabeça gira
  if (turn > 0.08) p.stroke(smoothD([bridgeTop, bridgeMid, tip, colu], false), hex(mul(skin, 0.55)), 1.3, clamp((turn - 0.08) * 1.5) * 0.7)
  else p.stroke(smoothD([w(tipX + 4, L.browY + 8, 0), w(tipX + 6, L.noseY - L.noseLen * 0.4, P * 0.3), w(tipX + L.noseW * 0.25, L.noseY - L.noseLen * 0.15, P * 0.6)], false), hex(mul(skin, 0.75)), 1.3, 0.5)
}

function convexHull(points: readonly Pt[]): Pt[] {
  const pts = [...points].sort((a, b) => a[0] - b[0] || a[1] - b[1])
  if (pts.length < 3) return pts
  const cross = (o: Pt, a: Pt, b: Pt): number => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
  const lower: Pt[] = []
  for (const p of pts) {
    while (lower.length >= 2 && cross(lower[lower.length - 2]!, lower[lower.length - 1]!, p) <= 0) lower.pop()
    lower.push(p)
  }
  const upper: Pt[] = []
  for (let i = pts.length - 1; i >= 0; i--) {
    const p = pts[i]!
    while (upper.length >= 2 && cross(upper[upper.length - 2]!, upper[upper.length - 1]!, p) <= 0) upper.pop()
    upper.push(p)
  }
  return [...lower.slice(0, -1), ...upper.slice(0, -1)]
}

// ---------------- boca ----------------
export function drawMouth(c: Ctx): void {
  const { p, hv, L, ph, skin, makeup } = c
  const { cx, mouthY, mouthW, lipU, lipL, asymMouth } = L
  const hw = mouthW / 2
  const droop = L.old * 3
  const lx = cx - hw + asymMouth * 0.3, rx = cx + hw + asymMouth * 0.3
  if (hv.facing(cx, mouthY) < -0.2) return
  const upperTop = [
    ...cubicPts([lx, mouthY + droop], [cx - hw * 0.6, mouthY - lipU * 0.7], [cx - hw * 0.35, mouthY - lipU * 1.15], [cx - hw * 0.14, mouthY - lipU * 1.05], 6),
    ...quadPts([cx - hw * 0.14, mouthY - lipU * 1.05], [cx, mouthY - lipU * 0.78], [cx + hw * 0.14, mouthY - lipU * 1.05], 4, false),
    ...cubicPts([cx + hw * 0.14, mouthY - lipU * 1.05], [cx + hw * 0.35, mouthY - lipU * 1.15], [cx + hw * 0.6, mouthY - lipU * 0.7], [rx, mouthY + droop], 6, false),
  ]
  const lowerBot = cubicPts([rx, mouthY + droop], [cx + hw * 0.6, mouthY + lipL * 1.2], [cx - hw * 0.6, mouthY + lipL * 1.2], [lx, mouthY + droop], 10, false)
  const lips = hv.pts([...upperTop, ...lowerBot], 0.5)
  let lipCol = mix(mul(skin, 0.8), [176, 84, 88], 0.5 * (1 - ph.melanin * 0.45))
  if (makeup > 0.5) lipCol = mix(lipCol, [150 + makeup * 40, 40, 60], (makeup - 0.4) * 0.8)
  const ld = smoothD(lips)
  p.fill(ld, hex(lipCol))
  // lábio superior mais escuro (luz vem de cima)
  const seam = [
    ...cubicPts([lx, mouthY + droop], [cx - hw * 0.5, mouthY + 0.8], [cx - hw * 0.1, mouthY + 1.4], [cx, mouthY + 0.6], 6),
    ...cubicPts([cx, mouthY + 0.6], [cx + hw * 0.1, mouthY + 1.4], [cx + hw * 0.5, mouthY + 0.8], [rx, mouthY + droop], 6, false),
  ]
  const upperLip = hv.pts([...upperTop, ...seam.slice().reverse()], 0.6)
  p.fill(smoothD(upperLip), hex(mul(lipCol, 0.8)), 0.6)
  const lineCol = hex(mix(mul(skin, 0.35), [60, 20, 20], 0.3))
  const sw = hv.pts(seam, 0.7)
  p.stroke(smoothD(sw, false), lineCol, 1.5, 0.85)
  // brilho do lábio inferior e sombra abaixo dele
  const hlp = hv.warp(cx - hw * 0.12, mouthY + lipL * 0.55, 0.8)
  if (hlp.facing > 0.1) p.fill(ellipseD(hlp.X, hlp.Y, hw * 0.35 * sq(hlp.facing), lipL * 0.32), "#fff0eb", 0.22)
  const under = hv.warp(cx, mouthY + lipL * 1.5, 0)
  if (under.facing > 0.05) p.fill(ellipseD(under.X + 1, under.Y + 1, hw * 0.6 * sq(under.facing), lipL * 0.45), p.radial(under.X + 1, under.Y + 1, hw * 0.6, [[0, "#3a1a14", 0.22], [1, "#3a1a14", 0]], sq(under.facing), 0.4), 1, c.headClip)
  // cantos
  for (const x of [lx, rx]) {
    const q = hv.warp(x, mouthY + droop, 0.4)
    if (q.facing > 0.1) p.fill(ellipseD(q.X, q.Y, 2.4, 2.4), lineCol, 0.35)
  }
}

// ---------------- óculos ----------------
export function drawGlasses(c: Ctx, kind: GlassesId): void {
  const { p, hv, L } = c
  const w = L.eyeW
  const r = seededRandom(hashText(kind + L.cx))
  const frame = kind === "aviador" ? "#beaa78" : kind === "grosso" ? "#0f0c0a" : r.next() < 0.5 ? "#281e19" : "#5a3c28"
  const lw = kind === "grosso" ? 3.6 : kind === "aviador" ? 1.3 : 2
  const prot = w * 0.55
  const outers: Pt[] = []
  for (const s of [-1, 1]) {
    const ex = L.cx + s * L.eyeOff, ey = L.eyeY + 2
    let shape: Pt[]
    if (kind === "redondo") {
      shape = []
      for (let i = 0; i < 24; i++) {
        const a = (i / 24) * Math.PI * 2
        shape.push([ex + Math.cos(a) * w * 0.62, ey + Math.sin(a) * w * 0.62])
      }
    } else if (kind === "aviador") {
      shape = [[ex - s * w * 0.62, ey - w * 0.42], [ex + s * w * 0.66, ey - w * 0.45], ...quadPts([ex + s * w * 0.66, ey - w * 0.45], [ex + s * w * 0.75, ey + w * 0.55], [ex + s * w * 0.1, ey + w * 0.62], 6, false), ...quadPts([ex + s * w * 0.1, ey + w * 0.62], [ex - s * w * 0.6, ey + w * 0.4], [ex - s * w * 0.62, ey - w * 0.42], 6, false)]
    } else if (kind === "gatinho") {
      shape = [...quadPts([ex - s * w * 0.62, ey - w * 0.3], [ex, ey - w * 0.55], [ex + s * w * 0.78, ey - w * 0.58], 6), ...quadPts([ex + s * w * 0.78, ey - w * 0.58], [ex + s * w * 0.6, ey + w * 0.5], [ex, ey + w * 0.45], 6, false), ...quadPts([ex, ey + w * 0.45], [ex - s * w * 0.66, ey + w * 0.4], [ex - s * w * 0.62, ey - w * 0.3], 6, false)]
    } else {
      const rw = w * 0.7, rh = w * (kind === "grosso" ? 0.5 : 0.44)
      shape = [[ex - rw, ey - rh], [ex + rw, ey - rh], [ex + rw, ey + rh], [ex - rw, ey + rh]]
    }
    const f = hv.facing(ex, ey)
    if (f < -0.2) continue
    const wpts = hv.pts(shape, prot)
    const d = kind === "retangular" || kind === "grosso" ? polyD(wpts) : smoothD(wpts)
    p.fill(d, kind === "aviador" ? "#3c463c" : "#c8dcf0", kind === "aviador" ? 0.3 : 0.08)
    p.stroke(d, frame, lw, 1)
    outers.push(hv.pts([[ex + s * w * 0.66, ey - w * 0.25]], prot)[0]!)
    // haste até a orelha, só do lado visível
    const ear = hv.view.project(shellPoint(hv.head.shell, s * (Math.PI / 2 + 0.1), L.browY + 6, 1))
    if (earIsNear(c, s)) p.stroke(polyD([outers[outers.length - 1]!, [ear.X, ear.Y]], false), frame, lw * 0.8, 0.9)
  }
  const bridge = hv.pts(quadPts([L.cx - L.eyeOff + w * 0.62, L.eyeY - 2], [L.cx, L.eyeY - 7], [L.cx + L.eyeOff - w * 0.62, L.eyeY - 2], 6), prot)
  p.stroke(smoothD(bridge, false), frame, lw, 1)
}

export type FaceCtx = Ctx
