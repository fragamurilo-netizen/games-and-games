// Busto humano: pescoço, trapézio, ombros (deltoides), braços, peito e roupa.

import type { ShirtKind } from "@paralelo/simulation"
import { polyD, smoothD, type Painter } from "./display"
import type { FaceLayout } from "./geometry"
import { clamp, hex, hsl, lerp, mix, mul, smooth, type Pt, type RGB } from "./math"
import { bandAt, regionPolygons, shellPoint, silhouette, View, type Shell } from "./shell"

export type Body = {
  neck: Shell
  torso: Shell
  arms: [Shell, Shell]
  neckBaseY: number
  armR: number
  shirt: ShirtKind
  shirtColor: RGB
  bust: number
}

export function buildBody(L: FaceLayout, female: boolean, age: number, shirt: ShirtKind, hue: number, tone: number): Body {
  const { rx, neckW, shoulderY, shoulderW, chinY, jawY, fat, growth } = L
  const neckR = neckW / 2
  const neckZ = -rx * 0.26
  const neckBaseY = shoulderY - (shoulderY - chinY) * 0.34
  const neck: Shell = {
    xc: 0,
    zc: neckZ,
    yTop: L.noseY - 4,
    yBot: shoulderY + 24,
    section: (y) => {
      const flare = smooth(neckBaseY - 10, shoulderY + 20, y)
      const w = neckR * (1 + flare * 0.35)
      return { w, zF: w * 1.05, zB: -w * 1.15, nF: 2 }
    },
  }
  const armR = shoulderW * lerp(0.11, 0.125, growth) * (1 + fat * 0.45) * (female ? 0.92 : 1)
  const torsoZ = -rx * 0.36
  const chestW = shoulderW * 0.56 - armR * 0.95
  const bust = female && age > 12 ? smooth(11, 17, age) * (0.6 + fat * 0.6) : 0
  const torso: Shell = {
    xc: 0,
    zc: torsoZ,
    yTop: neckBaseY,
    yBot: 540,
    section: (y) => {
      const t = clamp((y - neckBaseY) / Math.max(1, shoulderY + 4 - neckBaseY))
      const w = y < shoulderY + 4 ? lerp(neckR * 1.05, chestW, Math.pow(smooth(0, 1, t), 0.8)) : chestW * (1 + fat * 0.05)
      const depthK = lerp(0.72, 0.64, growth) + fat * 0.24
      let zF = w * depthK
      const zB = -w * (depthK - 0.04)
      if (bust > 0) zF += bust * rx * 0.2 * Math.exp(-Math.pow((y - (shoulderY + 70)) / 24, 2))
      if (y < shoulderY) zF = lerp(neckR * 0.95, zF, smooth(0, 1, t))
      return { w, zF, zB, nF: 2.3 }
    },
  }
  const armTop = shoulderY - armR * 0.45
  const armShell = (s: number): Shell => ({
    xc: s * (shoulderW * 0.56 - armR * 1.02),
    zc: torsoZ - rx * 0.04,
    yTop: armTop,
    yBot: 540,
    section: (y) => {
      const k = clamp((y - armTop) / armR)
      const w = armR * (y < armTop + armR ? Math.sqrt(Math.max(0.02, 1 - (1 - k) * (1 - k))) : 1 - clamp((y - armTop - armR) / 400) * 0.1)
      return { w, zF: w * 0.96, zB: -w * 0.96, nF: 2 }
    },
  })
  const shirtColor: RGB = age < 3 ? hsl(hue, 0.22, 0.7) : hsl(hue, 0.06 + tone * 0.16, 0.2 + tone * 0.34)
  return { neck, torso, arms: [armShell(-1), armShell(1)], neckBaseY, armR, shirt: age < 3 ? "gola-redonda" : shirt, shirtColor, bust }
}

/** sombreamento de volume: luz vinda da esquerda e de cima, fixa na câmera */
export function shadeAcross(p: Painter, d: string, xl: number, xr: number, base: RGB, clip?: string, strength = 1): void {
  const hi = mix(base, [255, 244, 230], 0.16)
  const sh = mix(mul(base, 0.62), [60, 20, 30], 0.12)
  const g = p.linear(xl, 0, xr, 0, [
    [0, hex(hi), 0.55 * strength],
    [0.3, hex(base), 0],
    [0.62, hex(sh), 0.28 * strength],
    [0.9, hex(sh), 0.62 * strength],
    [1, hex(mix(sh, base, 0.5)), 0.45 * strength],
  ])
  p.fill(d, g, 1, clip)
}

function extentsX(poly: readonly Pt[]): [number, number] {
  let a = Infinity, b = -Infinity
  for (const [x] of poly) {
    if (x < a) a = x
    if (x > b) b = x
  }
  return [a, b]
}

function sleeveEnd(kind: ShirtKind, L: FaceLayout): number {
  if (kind === "sueter") return 560
  if (kind === "regata") return -1
  return L.shoulderY + (kind === "gola-polo" ? 62 : 72)
}

function neckline(kind: ShirtKind, base: number, u: number, female: boolean): number {
  const front = Math.abs(u) < Math.PI / 2 ? Math.pow(Math.cos(u), 2) : 0
  switch (kind) {
    case "decote-v": {
      const v = Math.max(0, 1 - Math.abs(u) / 0.75)
      return base + 4 + (female ? 40 : 32) * v + 6 * front
    }
    case "regata":
      return base + 6 + 26 * front + (Math.abs(u) > 0.9 && Math.abs(u) < 2.2 ? 26 : 0)
    case "gola-polo":
      return base + 2 + 8 * front
    case "sueter":
      return base + 1 + 7 * front
    default:
      return base + 3 + 12 * front
  }
}

export function drawBody(p: Painter, B: Body, L: FaceLayout, view: View, skin: RGB, female: boolean): void {
  const skinD = mix(skin, mul(skin, 0.9), 0.5)
  const shirt = B.shirtColor
  const end = sleeveEnd(B.shirt, L)
  const armZ = B.arms.map((a) => -a.xc * view.s + a.zc * view.c)
  const order = armZ[0]! < armZ[1]! ? [0, 1] : [1, 0]

  const drawArm = (i: number): void => {
    const a = B.arms[i]!
    const sil = silhouette(a, view, a.yTop, 520, 6)
    const d = smoothD(sil)
    const [xl, xr] = extentsX(sil)
    p.fill(d, hex(skinD))
    shadeAcross(p, d, xl, xr, skinD)
    if (end > 0) {
      const sleeves = regionPolygons(a, view, () => a.yTop, () => end, 0.8, 6, 24).filter((q) => q.length > 2)
      if (sleeves.length) {
        const sd = sleeves.map((q) => smoothD(q)).join("")
        p.fill(sd, hex(shirt))
        shadeAcross(p, sd, xl, xr, shirt)
        // barra da manga
        if (end < 530) {
          const hem: Pt[] = []
          for (let k = 0; k <= 16; k++) {
            const u = view.uFace - Math.PI / 2 + (k / 16) * Math.PI
            const q = view.project(shellPoint(a, u, end, 1))
            if (q.facing > 0) hem.push([q.X, q.Y])
          }
          p.stroke(smoothD(hem, false), hex(mul(shirt, 0.6)), 1.4, 0.7)
        }
      }
    }
    // separação entre braço e tronco
    const b = bandAt(a, view, L.shoulderY + 60, 24)
    const innerSide = a.xc * view.c < 0 ? 1 : -1
    const edge: Pt[] = []
    for (let y = L.shoulderY + 10; y < 520; y += 8) {
      const bb = bandAt(a, view, y, 20)
      const u = innerSide > 0 ? bb.uR : bb.uL
      const q = view.project(shellPoint(a, u, y))
      edge.push([q.X, q.Y])
    }
    void b
    p.stroke(smoothD(edge, false), hex(mul(end > 0 ? shirt : skinD, 0.55)), 1.3, 0.55)
  }

  // braço de trás, tronco, braço da frente
  drawArm(order[0]!)
  const tsil = silhouette(B.torso, view, B.torso.yTop, 520, 5)
  const td = smoothD(tsil)
  const [txl, txr] = extentsX(tsil)
  p.fill(td, hex(skinD))
  shadeAcross(p, td, txl, txr, skinD)
  // clavículas (aparecem com decote)
  if (B.shirt === "decote-v" || B.shirt === "regata") {
    for (const s of [-1, 1]) {
      const pts: Pt[] = []
      for (let k = 0; k <= 8; k++) {
        const t = k / 8
        const x = s * lerp(L.neckW * 0.3, L.shoulderW * 0.36, t)
        const y = B.neckBaseY + 10 + Math.sin(t * Math.PI) * -3 + t * 4
        const u = Math.sign(x) * Math.asin(Math.min(1, Math.abs(x) / Math.max(1, B.torso.section(y).w)))
        const q = view.project(shellPoint(B.torso, u, y, 0.5))
        if (q.facing > 0.1) pts.push([q.X, q.Y])
      }
      p.stroke(smoothD(pts, false), hex(mul(skin, 0.7)), 1.2, 0.45 * (1 - L.fat))
    }
  }
  const shirtPolys = regionPolygons(B.torso, view, (u) => neckline(B.shirt, B.neckBaseY, u, female), () => 540, 0.8, 5, 40).filter((q) => q.length > 2)
  if (shirtPolys.length) {
    const sd = shirtPolys.map((q) => smoothD(q)).join("")
    p.fill(sd, hex(shirt))
    shadeAcross(p, sd, txl, txr, shirt)
    // sombra do pescoço na gola
    const nc = view.project(shellPoint(B.torso, 0, B.neckBaseY + 8))
    const g = p.radial(nc.X + 3, nc.Y, L.neckW * 0.9, [[0, "#000000", 0.35], [1, "#000000", 0]], 1.2, 0.6)
    p.fill(sd, g)
    // gola
    const hemPts: Pt[] = []
    for (let k = 0; k <= 30; k++) {
      const u = view.uFace - Math.PI / 2 + (k / 30) * Math.PI
      const y = neckline(B.shirt, B.neckBaseY, u, female)
      const q = view.project(shellPoint(B.torso, u, y, 1))
      if (q.facing > 0) hemPts.push([q.X, q.Y])
    }
    const ribbed = B.shirt === "sueter" ? 3.2 : 1.8
    p.stroke(smoothD(hemPts, false), hex(mul(shirt, B.shirt === "sueter" ? 0.8 : 0.62)), ribbed, 0.85)
    if (B.shirt === "gola-polo") drawCollar(p, B, L, view, shirt)
    // dobras suaves no peito
    for (const s of [-1, 1]) {
      const fold: Pt[] = []
      for (let y = L.shoulderY + 28; y < 520; y += 10) {
        const x = s * (L.shoulderW * 0.2 + (y - L.shoulderY) * 0.08)
        const w = B.torso.section(y).w
        const u = Math.sign(x) * Math.asin(Math.min(0.98, Math.abs(x) / w))
        const q = view.project(shellPoint(B.torso, u, y, 1))
        if (q.facing > 0.15) fold.push([q.X, q.Y])
      }
      p.stroke(smoothD(fold, false), "#000000", 7, 0.06)
    }
  }
  drawArm(order[1]!)
}

function drawCollar(p: Painter, B: Body, L: FaceLayout, view: View, shirt: RGB): void {
  const col = hex(mix(shirt, [240, 240, 235], 0.1))
  for (const s of [-1, 1]) {
    const pts: Pt[] = []
    const add = (xf: number, y: number): void => {
      const w = B.torso.section(y).w
      const u = Math.sign(xf) * Math.asin(Math.min(0.99, Math.abs(xf) / w))
      const q = view.project(shellPoint(B.torso, u, y, 2.5))
      pts.push([q.X, q.Y])
    }
    add(s * (L.neckW / 2 + 2), B.neckBaseY - 4)
    add(s * 3, B.neckBaseY + 20)
    add(s * (L.neckW / 2 + 22), B.neckBaseY + 14)
    const f = view.project(shellPoint(B.torso, s * 0.5, B.neckBaseY + 10)).facing
    if (f < 0.1) continue
    const d = polyD(pts)
    p.fill(d, col)
    p.stroke(d, "#000000", 1, 0.25)
  }
}

export function drawNeck(p: Painter, B: Body, L: FaceLayout, view: View, skin: RGB): { d: string } {
  const sil = silhouette(B.neck, view, B.neck.yTop, B.neck.yBot, 5)
  const d = smoothD(sil)
  const [xl, xr] = extentsX(sil)
  const base = mix(skin, mul(skin, 0.93), 0.6)
  p.fill(d, hex(base))
  shadeAcross(p, d, xl, xr, base)
  // sombra do queixo/cabeça no pescoço
  const chin = view.project(shellPoint(B.neck, 0, L.chinY))
  const g = p.linear(0, L.jawY, 0, L.chinY + (L.shoulderY - L.chinY) * 0.55, [
    [0, "#2a1210", 0.55],
    [0.55, "#2a1210", 0.3],
    [1, "#2a1210", 0],
  ])
  const clip = p.clip(d)
  p.fill(polyD([[xl - 5, L.jawY - 20], [xr + 5, L.jawY - 20], [xr + 5, L.shoulderY + 30], [xl - 5, L.shoulderY + 30]]), g, 1, clip)
  void chin
  return { d }
}
