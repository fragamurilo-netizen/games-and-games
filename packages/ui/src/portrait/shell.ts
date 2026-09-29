// "Cascas" 2,5D: superfícies de revolução com seção horizontal variável.
// Cabeça, cabelo, pescoço, tronco e braços são cascas. Cada ponto é descrito por
// (u, y): u é o ângulo em torno do eixo vertical (0 = frente, ±π = costas, u > 0 = lado direito
// da imagem quando a pessoa está de frente) e y a altura no quadro.
// Giro (yaw) em torno do eixo vertical que passa por (cx, z = 0). Luz fixa na câmera.

import { clamp, type Pt } from "./math"

export type Section = {
  /** meia largura */
  w: number
  /** profundidade da frente (z máximo) */
  zF: number
  /** profundidade de trás (z mínimo, normalmente negativo) */
  zB: number
  /** expoente da superelipse da metade da frente (2 = elipse, maior = mais achatada) */
  nF: number
}

export type Shell = {
  /** centro do eixo da casca (x relativo ao eixo de giro) e z */
  xc: number
  zc: number
  yTop: number
  yBot: number
  section(y: number): Section
}

export type P3 = { x: number; y: number; z: number; nx: number; nz: number }
export type Proj = { X: number; Y: number; Z: number; facing: number }

export class View {
  readonly c: number
  readonly s: number
  constructor(readonly yaw: number, readonly cx: number) {
    this.c = Math.cos(yaw)
    this.s = Math.sin(yaw)
  }
  /** ângulo u que aponta para a câmera */
  get uFace(): number {
    return -this.yaw
  }
  project(p: P3): Proj {
    const X = this.cx + p.x * this.c + p.z * this.s
    const Z = -p.x * this.s + p.z * this.c
    const nz = -p.nx * this.s + p.nz * this.c
    return { X, Y: p.y, Z, facing: nz }
  }
  /** normal na tela: componente x (para sombreamento) */
  screenNx(p: P3): number {
    return p.nx * this.c + p.nz * this.s
  }
}

const zMidOf = (s: Section, rx: number): number => Math.min((s.zF + s.zB) / 2, Math.max(0, s.zB + 0.25 * rx))

function baseXZ(s: Section, zm: number, u: number): [number, number] {
  const su = Math.sin(u), cu = Math.cos(u)
  if (Math.abs(u) <= Math.PI / 2) {
    const e = 2 / s.nF
    return [s.w * Math.sign(su) * Math.pow(Math.abs(su), e), zm + (s.zF - zm) * Math.pow(Math.abs(cu), e)]
  }
  return [s.w * su, zm + (zm - s.zB) * cu]
}

/** Ponto na superfície. prot empurra para fora ao longo da normal. */
export function shellPoint(sh: Shell, u: number, y: number, prot = 0, refR = 90): P3 {
  const s = sh.section(y)
  const zm = zMidOf(s, refR)
  const [x, z] = baseXZ(s, zm, u)
  const eps = 0.01
  const a = baseXZ(s, zm, wrap(u - eps)), b = baseXZ(s, zm, wrap(u + eps))
  const tx = b[0] - a[0], tz = b[1] - a[1]
  // normal para fora: tangente girada -90° no plano xz
  let nx = -tz, nz = tx
  const len = Math.hypot(nx, nz)
  if (len < 1e-9) {
    nx = Math.sin(u)
    nz = Math.cos(u)
  } else {
    nx /= len
    nz /= len
  }
  return { x: sh.xc + x + nx * prot, y, z: sh.zc + z + nz * prot, nx, nz }
}

/** Extremos (silhueta) de uma casca numa altura: [uEsquerda, uDireita] na tela. */
export function bandAt(sh: Shell, view: View, y: number, samples = 40): { uL: number; uR: number; XL: number; XR: number } {
  let XL = Infinity, XR = -Infinity, uL = 0, uR = 0
  const u0 = view.uFace
  for (let i = 0; i <= samples; i++) {
    const u = u0 - Math.PI + (i / samples) * Math.PI * 2
    const p = view.project(shellPoint(sh, wrap(u), y))
    if (p.X < XL) { XL = p.X; uL = u }
    if (p.X > XR) { XR = p.X; uR = u }
  }
  // refino local
  for (const side of [0, 1]) {
    let u = side ? uR : uL
    let step = (Math.PI * 2) / samples / 2
    for (let k = 0; k < 6; k++) {
      const a = view.project(shellPoint(sh, wrap(u - step), y)).X
      const b = view.project(shellPoint(sh, wrap(u + step), y)).X
      const m = view.project(shellPoint(sh, wrap(u), y)).X
      const better = side ? Math.max(a, b, m) : Math.min(a, b, m)
      if (better === a) u -= step
      else if (better === b) u += step
      step /= 2
    }
    if (side) { uR = u; XR = view.project(shellPoint(sh, wrap(u), y)).X } else { uL = u; XL = view.project(shellPoint(sh, wrap(u), y)).X }
  }
  // garante uL < uR ao redor de uFace
  while (uL > u0) uL -= Math.PI * 2
  while (uR < u0) uR += Math.PI * 2
  return { uL, uR, XL, XR }
}

export const wrap = (u: number): number => {
  let v = u
  while (v > Math.PI) v -= Math.PI * 2
  while (v < -Math.PI) v += Math.PI * 2
  return v
}

/** Silhueta projetada da casca inteira entre y0 e y1. */
export function silhouette(sh: Shell, view: View, y0 = sh.yTop, y1 = sh.yBot, step = 4): Pt[] {
  const left: Pt[] = [], right: Pt[] = []
  const n = Math.max(2, Math.ceil((y1 - y0) / step))
  for (let i = 0; i <= n; i++) {
    const y = y0 + ((y1 - y0) * i) / n
    const b = bandAt(sh, view, y, 28)
    left.push([b.XL, y])
    right.push([b.XR, y])
  }
  return [...right, ...left.reverse()]
}

/**
 * Região da superfície {(u, y): top(u) <= y <= bot(u)} vista pela câmera, como polígonos na tela.
 * Cada trecho contínuo em u vira um polígono: borda esquerda, borda de baixo, borda direita, borda de cima.
 * Onde o trecho chega à silhueta, a borda lateral segue a silhueta.
 */
export function regionPolygons(
  sh: Shell,
  view: View,
  top: (u: number) => number,
  bot: (u: number) => number,
  prot = 0,
  yStep = 5,
  uSamples = 36,
): Pt[][] {
  const yMin = sh.yTop, yMax = sh.yBot
  const proj = (u: number, y: number): Proj => view.project(shellPoint(sh, wrap(u), clamp(y, yMin, yMax), prot))
  const bands = new Map<number, { uL: number; uR: number }>()
  const band = (y: number): { uL: number; uR: number } => {
    const k = Math.round(clamp(y, yMin, yMax))
    let b = bands.get(k)
    if (!b) {
      b = bandAt(sh, view, k, 24)
      bands.set(k, b)
    }
    return b
  }
  const u0 = view.uFace
  const uA = u0 - Math.PI / 2 - 0.4, uB = u0 + Math.PI / 2 + 0.4
  // amostras em u que têm algum pedaço visível
  const us: number[] = []
  for (let i = 0; i <= uSamples; i++) us.push(uA + ((uB - uA) * i) / uSamples)
  const visibleSpan = (u: number): [number, number] | null => {
    const t = top(wrap(u)), b = bot(wrap(u))
    if (!(b > t)) return null
    // parte do intervalo [t, b] em que u está dentro da faixa visível
    let lo = Infinity, hi = -Infinity
    const n = Math.max(2, Math.ceil((Math.min(b, yMax) - Math.max(t, yMin)) / 8))
    for (let k = 0; k <= n; k++) {
      const y = lerpN(Math.max(t, yMin), Math.min(b, yMax), k / n)
      const bd = band(y)
      if (u >= bd.uL && u <= bd.uR) {
        if (y < lo) lo = y
        if (y > hi) hi = y
      }
    }
    return lo <= hi ? [lo, hi] : null
  }
  const out: Pt[][] = []
  let run: { u: number; t: number; b: number }[] = []
  const flush = (): void => {
    if (run.length < 2) {
      run = []
      return
    }
    const first = run[0]!, last = run[run.length - 1]!
    const poly: Pt[] = []
    // borda esquerda: silhueta ou linha vertical em u = first.u
    for (let y = first.t; y <= first.b; y += yStep) {
      const bd = band(y)
      const u = Math.max(first.u, bd.uL)
      const p = proj(u, y)
      poly.push([p.X, p.Y])
    }
    for (const r of run) {
      const p = proj(r.u, r.b)
      poly.push([p.X, p.Y])
    }
    for (let y = last.b; y >= last.t; y -= yStep) {
      const bd = band(y)
      const u = Math.min(last.u, bd.uR)
      const p = proj(u, y)
      poly.push([p.X, p.Y])
    }
    for (let i = run.length - 1; i >= 0; i--) {
      const r = run[i]!
      const p = proj(r.u, r.t)
      poly.push([p.X, p.Y])
    }
    out.push(poly)
    run = []
  }
  for (const u of us) {
    const span = visibleSpan(u)
    if (span) run.push({ u, t: span[0], b: span[1] })
    else flush()
  }
  flush()
  return out
}

const lerpN = (a: number, b: number, t: number): number => a + (b - a) * t

/** ângulo u da metade da frente correspondente a um x relativo ao eixo */
export function frontU(sh: Shell, xRel: number, y: number): number {
  const s = sh.section(y)
  const d = xRel - sh.xc
  const r = Math.min(Math.abs(d) / Math.max(s.w, 0.01), 1)
  return Math.sign(d) * Math.asin(Math.pow(r, s.nF / 2))
}

/** projeta pontos (u, y) de uma casca; devolve trechos contínuos visíveis */
export function projectRuns(sh: Shell, view: View, pts: readonly Pt[], prot = 0, minFacing = 0): Pt[][] {
  const runs: Pt[][] = []
  let cur: Pt[] = []
  for (const [u, y] of pts) {
    const p = view.project(shellPoint(sh, wrap(u), clamp(y, sh.yTop, sh.yBot), prot))
    if (p.facing > minFacing) cur.push([p.X, p.Y])
    else if (cur.length) {
      runs.push(cur)
      cur = []
    }
  }
  if (cur.length) runs.push(cur)
  return runs
}

/** contorno por altura de tudo que a região cobre (inclusive o lado de trás) */
export function coverageHull(sh: Shell, view: View, top: (u: number) => number, bot: (u: number) => number, prot = 0, yStep = 6, uSamples = 48): Pt[] {
  const left: Pt[] = [], right: Pt[] = []
  for (let y = sh.yTop; y <= sh.yBot; y += yStep) {
    let XL = Infinity, XR = -Infinity
    for (let i = 0; i < uSamples; i++) {
      const u = -Math.PI + (i / uSamples) * Math.PI * 2
      if (y < top(u) || y > bot(u)) continue
      const X = view.project(shellPoint(sh, u, y, prot)).X
      if (X < XL) XL = X
      if (X > XR) XR = X
    }
    if (XL <= XR) {
      left.push([XL, y])
      right.push([XR, y])
    }
  }
  return [...right, ...left.reverse()]
}
