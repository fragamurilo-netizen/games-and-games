// Cabeça 2,5D construída a partir do layout frontal.
// O desenho frontal (olhos, boca, barba...) é "embrulhado" na superfície da cabeça por warp().

import { faceHalfWidth, type FaceLayout } from "./geometry"
import { clamp, lerp, smooth, type Pt } from "./math"
import { bandAt, shellPoint, View, wrap, type Section, type Shell } from "./shell"

export type Head = {
  L: FaceLayout
  shell: Shell
  /** superfície para a barba (continua abaixo do queixo) */
  beardShell: Shell
  F0: number
  B0: number
  noseTipProt: number
  /** protrusão da linha média (lábios, queixo, arcada) numa altura */
  protMid(y: number): number
}

export function buildHead(L: FaceLayout, noseZ: number, bridgeZ: number): Head {
  const { rx, y0, browY, noseY, mouthY, chinY, jawY, skullRy, growth } = L
  const F0 = rx * lerp(1.08, 1.26, growth)
  const B0 = rx * lerp(1.22, 1.14, growth)
  const table = new Map<number, Section>()
  const compute = (y: number): Section => {
    const w = Math.max(0.6, faceHalfWidth(L, y))
    let zF: number, zB: number, nF: number
    if (y < browY) {
      const t = clamp((browY - y) / skullRy)
      zF = F0 * Math.pow(Math.max(0, 1 - t * t), 0.55) * lerp(0.97, 1, 1 - t)
      const tb = clamp((browY + skullRy * 0.1 - y) / (skullRy * 1.1))
      zB = -B0 * Math.sqrt(Math.max(0, 1 - tb * tb))
      nF = 2.2
    } else if (y < noseY) {
      const s = (y - browY) / (noseY - browY)
      zF = F0 * (1 - 0.02 * s)
      zB = -B0 * lerp(1, 0.78, s)
      nF = lerp(2.3, 2.7, s)
    } else if (y < jawY) {
      const s = (y - noseY) / Math.max(1, jawY - noseY)
      zF = F0 * lerp(0.98, 0.95, s)
      zB = lerp(-B0 * 0.78, -rx * 0.18, smooth(0, 1, s))
      nF = 2.7
    } else {
      const s = clamp((y - jawY) / Math.max(1, chinY - jawY))
      zF = F0 * lerp(0.95, 0.9, s)
      zB = lerp(-rx * 0.18, F0 * 0.5, s * s)
      nF = 2.4
    }
    return { w, zF, zB, nF }
  }
  const section = (y: number): Section => {
    const k = Math.round(clamp(y, y0, chinY))
    let s = table.get(k)
    if (!s) {
      s = compute(k)
      table.set(k, s)
    }
    return s
  }
  const shell: Shell = { xc: 0, zc: 0, yTop: y0, yBot: chinY, section }

  const beardShell: Shell = {
    xc: 0,
    zc: 0,
    yTop: y0,
    yBot: 560,
    section: (y) => {
      if (y <= jawY) return section(y)
      const s = section(Math.min(y, chinY))
      const k = clamp((y - jawY) / Math.max(1, chinY - jawY))
      return { w: Math.max(s.w, lerp(L.jawW, L.jawW * 0.9, k)), zF: section(chinY).zF + 2, zB: -rx * 0.3, nF: 2.6 }
    },
  }

  const protMid = (y: number): number => {
    const g = (c: number, s: number, a: number): number => a * Math.exp(-((y - c) * (y - c)) / (2 * s * s))
    return (
      g(browY - 4, 8, rx * 0.03 * growth) +
      g(mouthY - L.lipU * 0.5, L.lipU * 0.9 + 1, rx * 0.1) +
      g(mouthY + L.lipL * 0.55, L.lipL * 0.9 + 1, rx * 0.09) +
      g(chinY - (chinY - mouthY) * 0.3, (chinY - mouthY) * 0.25, rx * 0.06) -
      g(mouthY + L.lipL * 1.4, 3, rx * 0.02)
    )
  }

  void bridgeZ
  return { L, shell, beardShell, F0, B0, noseTipProt: noseZ, protMid }
}

/** Projeção dos traços frontais na superfície da cabeça para um ângulo. */
export class HeadView {
  readonly view: View
  private readonly bands = new Map<number, { uL: number; uR: number }>()
  private readonly bandsBeard = new Map<number, { uL: number; uR: number }>()
  constructor(readonly head: Head, yaw: number) {
    this.view = new View(yaw, head.L.cx)
  }
  private band(sh: Shell, y: number, beard: boolean): { uL: number; uR: number } {
    const cache = beard ? this.bandsBeard : this.bands
    const k = Math.round(y)
    let b = cache.get(k)
    if (!b) {
      b = bandAt(sh, this.view, clamp(k, sh.yTop, sh.yBot), 24)
      cache.set(k, b)
    }
    return b
  }

  /** ângulo u na superfície correspondente ao x frontal */
  uOf(x: number, y: number, beard = false): number {
    const sh = beard ? this.head.beardShell : this.head.shell
    const s = sh.section(y)
    const xr = x - this.head.L.cx
    const ratio = Math.min(Math.abs(xr) / s.w, 1)
    const base = Math.asin(Math.pow(ratio, s.nF / 2))
    // além da borda frontal: continua para trás
    const extra = Math.abs(xr) > s.w ? Math.min((Math.abs(xr) - s.w) / s.w, 0.9) : 0
    return Math.sign(xr) * (base + extra)
  }

  /** x, y frontais (+ protrusão) -> ponto na tela; pontos escondidos grudam na silhueta. */
  warp(x: number, y: number, prot = 0, beard = false): { X: number; Y: number; facing: number; Z: number } {
    const sh = beard ? this.head.beardShell : this.head.shell
    const yy = clamp(y, sh.yTop, sh.yBot)
    const xr = x - this.head.L.cx
    let u = this.uOf(x, yy, beard)
    const mid = this.head.protMid(yy) * Math.exp(-(xr * xr) / (2 * Math.pow(this.head.L.mouthW * 0.45, 2)))
    const p = this.view.project(shellPoint(sh, u, yy, prot + mid))
    if (p.facing > 0.02) return { X: p.X, Y: y, facing: p.facing, Z: p.Z }
    const b = this.band(sh, yy, beard)
    const dl = Math.abs(wrap(u - b.uL)), dr = Math.abs(wrap(u - b.uR))
    u = dl < dr ? b.uL : b.uR
    const q = this.view.project(shellPoint(sh, wrap(u), yy, prot + mid))
    return { X: q.X, Y: y, facing: p.facing, Z: q.Z }
  }

  pts(points: readonly Pt[], prot = 0, beard = false): Pt[] {
    return points.map(([x, y]) => {
      const w = this.warp(x, y, prot, beard)
      return [w.X, w.Y] as Pt
    })
  }

  /** visibilidade (0..1) de um ponto frontal */
  facing(x: number, y: number): number {
    const sh = this.head.shell
    const u = this.uOf(x, y)
    return this.view.project(shellPoint(sh, u, clamp(y, sh.yTop, sh.yBot))).facing
  }

  /** Silhueta da cabeça, incluindo lábios e queixo em perfil. */
  silhouette(step = 3): Pt[] {
    const sh = this.head.shell
    const L = this.head.L
    const left: Pt[] = [], right: Pt[] = []
    for (let y = sh.yTop; y <= sh.yBot + 0.01; y += step) {
      const b = this.band(sh, y, false)
      let XL = this.view.project(shellPoint(sh, wrap(b.uL), y)).X
      let XR = this.view.project(shellPoint(sh, wrap(b.uR), y)).X
      const m = this.view.project(shellPoint(sh, 0, y, this.head.protMid(y)))
      if (m.X < XL) XL = m.X
      if (m.X > XR) XR = m.X
      left.push([XL, y])
      right.push([XR, y])
    }
    const bottom = this.view.project(shellPoint(sh, 0, L.chinY, this.head.protMid(L.chinY)))
    return [...right, [bottom.X, L.chinY + 0.6], ...left.reverse()]
  }
}
