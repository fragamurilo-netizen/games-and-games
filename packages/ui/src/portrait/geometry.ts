// Geometria do rosto por idade e peso. Coordenadas num quadro de 400 x 500.

import { seededRandom, type AppearanceGenome } from "@paralelo/simulation"
import { catmull, clamp, lerp, smooth, type Pt } from "./math"

export const FRAME_W = 400
export const FRAME_H = 500

export type FaceLayout = {
  age: number
  female: boolean
  /** 0 bebê ... 1 adulto */
  growth: number
  baby: number
  old: number
  fat: number
  thin: number
  jowl: number
  cx: number
  rx: number
  Ht: number
  y0: number
  chinY: number
  eyeY: number
  browY: number
  noseY: number
  mouthY: number
  eyeW: number
  eyeOff: number
  open: number
  hairlineY: number
  skullRy: number
  jawW: number
  jawY: number
  chinW: number
  outline: Pt[]
  neckW: number
  shoulderY: number
  shoulderW: number
  earH: number
  earW: number
  earOut: number
  mouthW: number
  lipU: number
  lipL: number
  noseW: number
  noseLen: number
  asymEye: readonly [number, number]
  asymBrow: readonly [number, number]
  asymMouth: number
  asymNose: number
  tilt: number
}

export function layoutFace(g: AppearanceGenome, age: number, fat: number): FaceLayout {
  const z = g.face
  const F = g.sex === "F"
  const gr = smooth(0, 17, age)
  const baby = 1 - smooth(0, 7, age)
  const old = smooth(45, 100, age) * g.skin.agingRate
  const thin = clamp(0.3 - fat) / 0.3
  const ar = seededRandom(g.asymmetrySeed)
  const asym = (): number => ar.normal() * g.asymmetry * 1.8

  const scale = lerp(0.8, 1, smooth(0, 16, age))
  const cx = 200 + asym() * 1.2
  const rx = 90 * (1 + 0.045 * z.faceW) * (F ? 0.955 : 1) * scale * lerp(1.07, 1, gr)
  const Ht = rx * lerp(2.18, 2.66, gr) * (1 + 0.045 * z.faceL) * (1 + 0.02 * z.skullH)
  const chinY = lerp(340, 352, gr) + fat * 14
  const y0 = chinY - Ht
  const eyeY = y0 + Ht * (lerp(0.6, 0.495, gr) + 0.012 * z.eyeY + old * 0.006)
  const browY = eyeY - Ht * lerp(0.068, 0.078, gr) * (1 + 0.08 * z.browY) + old * 3
  const noseY = eyeY + Ht * lerp(0.15, 0.195, gr) * (1 + 0.09 * z.noseL) + old * Ht * 0.018
  const mouthY = noseY + Ht * lerp(0.07, 0.08, gr) * (1 + 0.06 * z.mouthY) + old * 2
  const eyeW = rx * 2 * lerp(0.225, 0.2, gr) * (1 + 0.06 * z.eyeSize) * (1 - old * 0.05)
  const eyeOff = eyeW * (1 + 0.1 * z.eyeSpace) * lerp(0.98, 1, gr)
  const open = clamp(lerp(0.54, 0.4, gr) * (1 + 0.11 * z.eyeOpen) - old * 0.07 - fat * 0.05, 0.18, 0.6)
  const hairlineY = browY - (chinY - browY) * lerp(0.66, 0.45, gr) * (1 + 0.1 * z.forehead)

  const jowl = old * (0.4 + fat * 0.8)
  const cheekbone = rx * (0.975 + 0.03 * z.cheekB) + fat * rx * 0.1
  const cheek = rx * (0.87 + fat * 0.34 + baby * 0.1 - thin * 0.1 + 0.02 * z.faceW) - old * 2
  const jawW = rx * lerp(0.93, F ? 0.72 : 0.77, gr) * (1 + 0.06 * z.jawW) + fat * rx * 0.34 - thin * rx * 0.05 + jowl * 7
  const jawY = mouthY + (chinY - mouthY) * lerp(0.2, 0.33 + 0.05 * z.jawSq, gr) + jowl * 6
  const chinW = rx * lerp(0.46, F ? 0.28 : 0.34, gr) * (1 + 0.1 * z.chinW) + fat * rx * 0.2
  const chinFlat = F ? 0.4 : 0.55 + 0.1 * z.jawSq

  const skullRy = browY - y0
  const pR: Pt[] = []
  for (let i = 0; i < 6; i++) {
    const t = (i / 6) * (Math.PI / 2)
    pR.push([Math.sin(t) * rx, browY - Math.cos(t) * skullRy])
  }
  pR.push([rx * 0.99, browY])
  pR.push([cheekbone, eyeY + eyeW * 0.4])
  pR.push([cheek, mouthY - Ht * 0.03])
  pR.push([jawW, jawY])
  if (jowl > 0.05) pR.push([jawW * 0.86 + jowl * 3, jawY + (chinY - jawY) * 0.55 + jowl * 5])
  pR.push([chinW, chinY - Ht * 0.03 * (1 - chinFlat * 0.4)])
  pR.push([chinW * chinFlat * 0.8, chinY - Ht * 0.004])

  const right: Pt[] = pR.map(([x, y], i) => [cx + x + (i > 5 ? asym() * 0.8 : 0), y])
  const left: Pt[] = pR.map(([x, y], i): Pt => [cx - x + (i > 5 ? asym() * 0.8 : 0), y]).reverse()
  const ring: Pt[] = [...right, [cx, chinY + 0.5], ...left.slice(0, -1)]
  const outline = catmull(ring, true, 6)

  const neckW = rx * lerp(0.62, F ? 0.6 : 0.7, gr) * (1 + 0.06 * z.neck) * (1 + fat * 0.8 - thin * 0.12) + old * 2
  const shoulderY = chinY + Ht * lerp(0.14, 0.24, gr) - fat * 6
  const shoulderW = rx * lerp(1.55, F ? 2.05 : 2.35, gr) * (1 + fat * 0.28)

  const earH = (noseY - browY) * (1 + 0.08 * z.earSize) * (1 + old * 0.14) * lerp(1.08, 1, gr)
  const mouthW = eyeW * 2 * 0.74 * (1 + 0.07 * z.mouthW) * lerp(0.72, 1, gr) + fat * 2

  return {
    age, female: F, growth: gr, baby, old, fat, thin, jowl, cx, rx, Ht, y0, chinY, eyeY, browY, noseY, mouthY, eyeW, eyeOff, open,
    hairlineY, skullRy, jawW, jawY, chinW, outline, neckW, shoulderY, shoulderW,
    earH, earW: earH * 0.5, earOut: 0.15 + 0.12 * z.earOut,
    mouthW,
    lipU: mouthW * 0.13 * (1 + 0.22 * z.lipU) * (1 - old * 0.4) * (F ? 1.1 : 1),
    lipL: mouthW * 0.17 * (1 + 0.22 * z.lipL) * (1 - old * 0.35) * (F ? 1.1 : 1),
    noseW: eyeW * (0.98 + 0.14 * z.noseW) * lerp(0.72, 1, gr) + old * 2 + fat * 2,
    noseLen: noseY - browY,
    asymEye: [asym() * 1.2, asym() * 1.2],
    asymBrow: [asym() * 1.6, asym() * 1.6],
    asymMouth: asym() * 1.4,
    asymNose: asym() * 1.3,
    tilt: (0.06 * z.eyeTilt + (F ? 0.03 : 0.015)) * (1 - old * 0.6),
  }
}

/** Meia largura do rosto (lado direito) numa altura y, a partir do contorno. */
export function faceHalfWidth(L: FaceLayout, y: number): number {
  let best = 0
  const o = L.outline
  const n = o.length
  for (let i = 0; i < n; i++) {
    const p = o[i] as Pt, q = o[(i + 1) % n] as Pt
    if (p[0] < L.cx && q[0] < L.cx) continue
    if ((p[1] - y) * (q[1] - y) <= 0 && p[1] !== q[1]) {
      const t = (y - p[1]) / (q[1] - p[1])
      const x = p[0] + (q[0] - p[0]) * t - L.cx
      if (x > best) best = x
    }
  }
  return best
}
