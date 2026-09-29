// Utilidades numéricas e geométricas do retrato. Puro, sem DOM.

export type Pt = readonly [number, number]
export type Poly = readonly Pt[]
export type RGB = readonly [number, number, number]

export const clamp = (x: number, lo = 0, hi = 1): number => (x < lo ? lo : x > hi ? hi : x)
export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t
export const smooth = (a: number, b: number, x: number): number => {
  const t = clamp((x - a) / (b - a))
  return t * t * (3 - 2 * t)
}

export const mix = (a: RGB, b: RGB, t: number): RGB => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]
export const mul = (a: RGB, k: number): RGB => [a[0] * k, a[1] * k, a[2] * k]
const hex2 = (v: number): string => Math.round(clamp(v, 0, 255)).toString(16).padStart(2, "0")
export const hex = (c: RGB): string => `#${hex2(c[0])}${hex2(c[1])}${hex2(c[2])}`

export function hsl(h: number, s: number, l: number): RGB {
  const f = (n: number): number => {
    const k = (n + h * 12) % 12
    const a = s * Math.min(l, 1 - l)
    return 255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))
  }
  return [f(0), f(8), f(4)]
}

/** Ruído de valor 2D determinístico. */
function hashXY(x: number, y: number, s: number): number {
  let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}
export function valueNoise(x: number, y: number, s: number): number {
  const xi = Math.floor(x), yi = Math.floor(y)
  const xf = x - xi, yf = y - yi
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
  const a = hashXY(xi, yi, s), b = hashXY(xi + 1, yi, s), c = hashXY(xi, yi + 1, s), d = hashXY(xi + 1, yi + 1, s)
  return lerp(lerp(a, b, u), lerp(c, d, u), v)
}

/** Spline Catmull-Rom amostrada. */
export function catmull(pts: Poly, closed: boolean, seg = 8): Pt[] {
  const out: Pt[] = []
  const n = pts.length
  const get = (i: number): Pt => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]) as Pt
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
  if (!closed && n > 0) out.push(pts[n - 1] as Pt)
  return out
}

export function ellipsePoly(cx: number, cy: number, rx: number, ry: number, n = 24, rot = 0): Pt[] {
  const out: Pt[] = []
  const c = Math.cos(rot), s = Math.sin(rot)
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2
    const x = Math.cos(a) * rx, y = Math.sin(a) * ry
    out.push([cx + x * c - y * s, cy + x * s + y * c])
  }
  return out
}

export function cubicPts(p0: Pt, p1: Pt, p2: Pt, p3: Pt, n = 10, includeStart = true): Pt[] {
  const out: Pt[] = []
  for (let i = includeStart ? 0 : 1; i <= n; i++) {
    const t = i / n, u = 1 - t
    out.push([
      u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
      u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
    ])
  }
  return out
}

export function quadPts(p0: Pt, p1: Pt, p2: Pt, n = 8, includeStart = true): Pt[] {
  const out: Pt[] = []
  for (let i = includeStart ? 0 : 1; i <= n; i++) {
    const t = i / n, u = 1 - t
    out.push([u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]])
  }
  return out
}

/** Número de voltas (regra nonzero), para testar se um ponto está dentro de um polígono qualquer. */
export function winding(x: number, y: number, poly: Poly): number {
  let w = 0
  const n = poly.length
  for (let i = 0; i < n; i++) {
    const a = poly[i] as Pt, b = poly[(i + 1) % n] as Pt
    if (a[1] <= y) {
      if (b[1] > y && (b[0] - a[0]) * (y - a[1]) - (x - a[0]) * (b[1] - a[1]) > 0) w++
    } else if (b[1] <= y && (b[0] - a[0]) * (y - a[1]) - (x - a[0]) * (b[1] - a[1]) < 0) w--
  }
  return w
}

export type Mask = { polys: readonly Poly[]; minX: number; minY: number; maxX: number; maxY: number }

export function makeMask(polys: readonly Poly[]): Mask {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (const p of polys) for (const [x, y] of p) {
    if (x < minX) minX = x
    if (y < minY) minY = y
    if (x > maxX) maxX = x
    if (y > maxY) maxY = y
  }
  return { polys, minX, minY, maxX, maxY }
}

export function inMask(m: Mask, x: number, y: number): boolean {
  if (x < m.minX || x > m.maxX || y < m.minY || y > m.maxY) return false
  for (const p of m.polys) if (winding(x, y, p) !== 0) return true
  return false
}

/** Recorta um polígono mantendo a parte com y >= yMin (Sutherland–Hodgman). */
export function clipBelow(poly: Poly, yMin: number): Pt[] {
  const out: Pt[] = []
  const n = poly.length
  for (let i = 0; i < n; i++) {
    const a = poly[i] as Pt, b = poly[(i + 1) % n] as Pt
    const ain = a[1] >= yMin, bin = b[1] >= yMin
    if (ain) out.push(a)
    if (ain !== bin) {
      const t = (yMin - a[1]) / (b[1] - a[1])
      out.push([a[0] + (b[0] - a[0]) * t, yMin])
    }
  }
  return out
}
