// Barba e bigode: regiões desenhadas de frente e projetadas na superfície (com espessura).

import { seededRandom, hashText } from "@paralelo/simulation"
import { polyD, smoothD, type Painter } from "./display"
import { faceHalfWidth, type FaceLayout } from "./geometry"
import type { HeadView } from "./head"
import { catmull, clamp, hex, lerp, makeMask, inMask, mix, mul, smooth, valueNoise, type Poly, type Pt, type RGB } from "./math"
import type { BeardParams } from "./styles"
import { GREY_HAIR } from "./color"

export function beardRegions(L: FaceLayout, st: BeardParams, len: number): Pt[][] {
  const out: Pt[][] = []
  const { cx, mouthY, noseY, chinY, eyeY, mouthW, lipU, lipL, noseW, jawY } = L
  const hw = mouthW / 2
  const fw = (y: number): number => faceHalfWidth(L, y)
  const ext = len * L.Ht * 0.55
  const cheekTop = eyeY + (noseY - eyeY) * 0.85
  const add = (pts: Pt[], seg = 6): void => {
    out.push(catmull(pts, true, seg))
  }
  const lowPts = (width: number): Pt[] => {
    const point = st.point ?? 0, round = st.round ?? 0
    const pts: Pt[] = []
    for (let i = 0; i <= 8; i++) {
      const u = (i / 8) * 2 - 1
      const x = cx + u * width * (1 + round * 0.25 * (1 - Math.abs(u)))
      const base = chinY + 3 - (1 - Math.cos((u * Math.PI) / 2)) * (chinY - jawY) * 0.8
      const drop = ext * (st.boxed ? 1 - Math.pow(Math.abs(u), 4) * 0.6 : Math.cos((u * Math.PI) / 2) * (1 - point) + point * Math.max(0, 1 - Math.abs(u) * 1.3))
      pts.push([x, base + drop])
    }
    return pts.reverse()
  }
  for (const part of st.parts) {
    if (part === "mus") {
      const m = st.mus ?? "standard"
      const topY = noseY + 2
      const botY = mouthY - lipU * 0.55
      const wide = m === "pencil" ? 0.9 : m === "handlebar" ? 1.15 : m === "walrus" ? 1.2 : m === "english" ? 1.35 : m === "pencilWide" ? 1.05 : 1.02
      const t = m === "pencil" || m === "pencilWide" || m === "english" ? 0.35 : m === "walrus" ? 1.3 : 1
      const yy = lerp(botY, topY, t)
      const pts: Pt[] = [
        [cx, yy - 1], [cx + noseW * 0.4, topY + (yy - topY) * 0.3], [cx + hw * wide, botY + (m === "walrus" ? lipU * 1.1 : 1)],
        [cx + hw * wide * 0.8, botY + 1.5], [cx, botY - 1], [cx - hw * wide * 0.8, botY + 1.5],
        [cx - hw * wide, botY + (m === "walrus" ? lipU * 1.1 : 1)], [cx - noseW * 0.4, topY + (yy - topY) * 0.3],
      ]
      if (st.musGap) {
        add([...pts.slice(0, 5), [cx + 1, botY - 2]])
        add([[cx - 1, botY - 2], ...pts.slice(4)])
      } else add(pts)
      if (m === "handlebar") for (const s of [-1, 1]) add([[cx + s * hw * 1.05, botY - 1], [cx + s * hw * 1.5, botY - 6], [cx + s * hw * 1.62, botY - 13], [cx + s * hw * 1.45, botY - 5], [cx + s * hw * 1.1, botY + 2]])
      if (m === "chevron") add([[cx - hw * 1.05, botY + 3], [cx, topY - 1], [cx + hw * 1.05, botY + 3], [cx, botY + 1]])
    } else if (part === "goatee" || part === "goateeFree" || part === "goateeWide" || part === "goateeRound" || part === "anchor") {
      const gw = part === "goateeWide" ? hw * 1.15 : part === "goateeRound" ? hw * 1.12 : hw * 0.72
      const topY = mouthY + lipL * (part === "goateeRound" || part === "goatee" ? 0.3 : 1.1)
      add([[cx - gw, topY], [cx - gw * 0.4, mouthY + lipL * 1.25], [cx + gw * 0.4, mouthY + lipL * 1.25], [cx + gw, topY], ...lowPts(gw * 0.95)])
      if (part === "goateeRound" || part === "goatee") for (const s of [-1, 1]) add([[cx + s * hw * 0.95, mouthY - lipU * 0.5], [cx + s * hw * 1.12, mouthY], [cx + s * hw * 1.02, mouthY + lipL * 1.5], [cx + s * hw * 0.8, mouthY + lipL * 1.2]])
      if (part === "anchor") add([[cx - hw * 0.3, mouthY + lipL * 1.2], [cx, mouthY + lipL * 1.1], [cx + hw * 0.3, mouthY + lipL * 1.2], [cx, mouthY + lipL * 2.1]])
      if (part === "goateeWide") add([[cx - 5, mouthY + lipL * 1.1], [cx + 5, mouthY + lipL * 1.1], [cx + 4, mouthY + lipL * 2.2], [cx - 4, mouthY + lipL * 2.2]])
    } else if (part === "soul") {
      add([[cx - 5, mouthY + lipL * 1.15], [cx + 5, mouthY + lipL * 1.15], [cx + 3.5, mouthY + lipL * 1.15 + 10], [cx - 3.5, mouthY + lipL * 1.15 + 10]])
    } else if (part === "strap") {
      const outer: Pt[] = []
      for (let i = 0; i <= 12; i++) {
        const y = lerp(cheekTop + 16, chinY, i / 12)
        outer.push([cx + fw(y) - 1, y])
      }
      const inner = outer.map(([x, y]): Pt => [cx + (x - cx) * 0.9 - 3, y - 5]).reverse()
      const mirror = (p: Pt[]): Pt[] => p.map(([x, y]): Pt => [2 * cx - x, y]).reverse()
      out.push([...outer, [cx, chinY + 3], ...mirror(outer), ...mirror(inner), [cx, chinY - 7], ...inner])
    } else if (part === "burns" || part === "chops") {
      for (const s of [-1, 1]) {
        const y0 = L.browY + 6
        const y1 = part === "burns" ? noseY + 6 : mouthY + 8
        const pts: Pt[] = []
        for (let i = 0; i <= 6; i++) {
          const y = lerp(y0, y1, i / 6)
          pts.push([cx + s * (fw(y) + 1), y])
        }
        const w2 = part === "burns" ? 11 : 28
        const inner = pts.map(([x, y], i): Pt => [x - s * (w2 * (i / 6) + 7), y]).reverse()
        if (part === "chops") inner[0] = [cx + s * hw * 1.25, mouthY + 4]
        add([...pts, ...inner], 3)
      }
    } else if (part === "horseshoe") {
      for (const s of [-1, 1]) add([[cx + s * hw * 0.85, mouthY - 2], [cx + s * hw * 1.12, mouthY - 3], [cx + s * hw * 1.15, chinY - 2], [cx + s * hw * 0.92, chinY - 2]], 2)
    } else if (part === "fumanchu") {
      for (const s of [-1, 1]) add([[cx + s * hw * 0.9, mouthY - 2], [cx + s * hw * 1.05, mouthY - 3], [cx + s * hw * 1.05, chinY + 35], [cx + s * hw * 0.95, chinY + 36]], 2)
    }
  }
  const hasChin = st.parts.includes("chin")
  const hasCheek = st.parts.includes("cheek") || st.parts.includes("cheekLow")
  if (hasChin || hasCheek) {
    const low = st.parts.includes("cheekLow")
    const topY = low ? mouthY : cheekTop
    const right: Pt[] = []
    for (let i = 0; i <= 10; i++) {
      const y = lerp(topY - 22, chinY, i / 10)
      right.push([cx + fw(y) + 1.5, y])
    }
    const cheekLine: Pt[] = hasCheek
      ? [[cx + fw(topY - 20) - 2, topY - 22], [cx + fw(topY) * 0.72, topY + 3], [cx + hw * 1.25, mouthY - lipU * 1.2], [cx + noseW * 0.55, noseY + 3]]
      : [[cx + hw * 1.1, mouthY - 2]]
    const pts: Pt[] = []
    if (hasCheek) pts.push(...right)
    else pts.push([cx + hw * 1.1, mouthY - 2])
    pts.push(...lowPts(hasCheek ? Math.max(fw(chinY - 6), L.chinW * 1.3) : hw * 1.05))
    if (hasCheek) pts.push(...right.slice().reverse().map(([x, y]): Pt => [2 * cx - x, y]))
    else pts.push([cx - hw * 1.1, mouthY - 2])
    pts.push(...cheekLine.slice().reverse().map(([x, y]): Pt => [2 * cx - x, y]))
    pts.push([cx, mouthY + lipL * 1.3])
    pts.push(...cheekLine)
    add(pts, 3)
  }
  if (st.parts.includes("neck")) add([[cx - L.jawW * 0.7, L.jawY + 6], [cx + L.jawW * 0.7, L.jawY + 6], [cx + L.neckW * 0.42, chinY + 22], [cx, chinY + 30], [cx - L.neckW * 0.42, chinY + 22]])
  return out
}

export type BeardModel = {
  regions: Pt[][]
  color: RGB
  grey: number
  stubble: number
  len: number
  density: number
  dots: Pt[]
  strands: Pt[][]
}

export function buildBeard(L: FaceLayout, st: BeardParams, color: RGB, grey: number, density: number, texture: number, age: number, seed: string): BeardModel | null {
  if (st.parts.length === 0 || age < 13) return null
  const young = smooth(13, 24, age)
  const len = st.len * (0.3 + young * 0.7)
  let dens = density * lerp(0.25, 1, young)
  if (st.fuzz || age < 17) dens *= 0.5
  const stubble = st.stubble ?? (age < 18 ? 0.6 : 0)
  const regions = beardRegions(L, st, stubble ? 0 : len)
  const mask = makeMask(regions)
  const r = seededRandom(hashText(seed + ":beard"))
  const patchSeed = hashText(seed + "patch") % 1000
  const patchy = (st.patchy ?? 0) + (1 - density) * 0.8 + (1 - young) * 0.5
  const dots: Pt[] = []
  const strands: Pt[][] = []
  const x0 = mask.minX, x1 = mask.maxX, y0 = mask.minY, y1 = mask.maxY
  if (stubble || len < 0.06) {
    const n = Math.floor(2600 * dens * (stubble || 0.5))
    for (let i = 0; i < n; i++) {
      const x = lerp(x0, x1, r.next()), y = lerp(y0, y1, r.next())
      if (!inMask(mask, x, y)) continue
      if (patchy > 0.3 && valueNoise(x * 0.08, y * 0.08, patchSeed) < patchy * 0.5) continue
      dots.push([x, y])
    }
  } else {
    const curl = clamp(texture / 3) * 2.5 + (st.wild ? 2 : 0)
    const n = Math.floor(900 * dens * (0.6 + len))
    for (let i = 0; i < n; i++) {
      const x = lerp(x0, x1, r.next()), y = lerp(y0, y1, r.next())
      if (!inMask(mask, x, y)) continue
      if (patchy > 0.3 && valueNoise(x * 0.08, y * 0.08, patchSeed) < patchy * 0.45) continue
      const dx = x - L.cx
      const [fx, fy] = y < L.mouthY && Math.abs(dx) < L.mouthW * 0.8 ? [Math.sign(dx || 1) * 0.9, 0.7] : [dx / (L.rx * 2.2), 1]
      const fl = Math.hypot(fx, fy)
      const l = (4 + r.next() * 8) * (0.5 + len * 1.4)
      const ex = x + (fx / fl) * l, ey = y + (fy / fl) * l
      strands.push([[x, y], [(x + ex) / 2 + (r.next() - 0.5) * curl * 3, (y + ey) / 2 + (r.next() - 0.5) * curl * 2], [ex + (r.next() - 0.5) * curl, ey]])
    }
  }
  return { regions, color, grey, stubble, len, density: dens, dots, strands }
}

export function drawBeard(p: Painter, B: BeardModel, hv: HeadView, headClip: string): void {
  const thick = B.stubble ? 0.3 : 1 + B.len * 6
  const warped: Pt[][] = []
  for (const poly of B.regions) {
    const w = poly.map(([x, y]) => hv.warp(x, y, thick, true))
    const f = w.reduce((a, q) => a + q.facing, 0) / Math.max(1, w.length)
    if (f > 0.05) warped.push(w.map((q): Pt => [q.X, q.Y]))
  }
  if (warped.length === 0) return
  const d = warped.map((w) => smoothD(w)).join("")
  const grey = B.grey
  const col = mix(B.color, GREY_HAIR, grey * 0.8)
  const clip = p.clip(d)
  if (B.stubble || B.len < 0.06) {
    p.fill(d, hex(mix(mul(col, 0.8), [70, 72, 80], 0.3)), clamp(0.28 * B.density * (B.stubble || 0.5) + B.len * 2, 0, 0.9), headClip)
    let dd = ""
    for (const [x, y] of B.dots) {
      const w = hv.warp(x, y, 0.3, true)
      if (w.facing <= 0.05) continue
      dd += `M${w.X.toFixed(1)} ${w.Y.toFixed(1)}h0.7v1.5h-0.7Z`
    }
    if (dd) p.fill(dd, hex(mul(col, 0.75)), 0.5, clip)
    return
  }
  p.fill(d, hex(mul(col, 0.62)), 0.95)
  const acc = ["", "", ""]
  let i = 0
  for (const s of B.strands) {
    const w = s.map(([x, y]) => hv.warp(x, y, thick + 0.5, true))
    if (w[0]!.facing <= 0.03) continue
    acc[i++ % 3] += `M${w[0]!.X.toFixed(1)} ${w[0]!.Y.toFixed(1)}Q${w[1]!.X.toFixed(1)} ${w[1]!.Y.toFixed(1)} ${w[2]!.X.toFixed(1)} ${w[2]!.Y.toFixed(1)}`
  }
  const tones = [0.72, 1, 1.28]
  acc.forEach((path, k) => {
    if (path) p.add({ d: path, stroke: hex(mul(col, tones[k]!)), width: 1.3, opacity: 0.75, clip, cap: "round" })
  })
  // volume da barba
  let xl = Infinity, xr = -Infinity
  for (const w of warped) for (const [x] of w) {
    if (x < xl) xl = x
    if (x > xr) xr = x
  }
  const g = p.linear(xl, 0, xr, 0, [[0, "#fff4e6", 0.1], [0.4, "#000000", 0], [1, "#000000", 0.35]])
  p.fill(d, g, 1, clip)
  void polyD
}

export type { Poly }
