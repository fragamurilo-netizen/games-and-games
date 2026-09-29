// Lista de desenho neutra: vira string SVG (web, testes) ou elementos react-native-svg (app).

import type { Pt } from "./math"

export type Stop = readonly [offset: number, color: string, opacity: number]

export type Gradient =
  | { id: string; type: "linear"; x1: number; y1: number; x2: number; y2: number; stops: readonly Stop[] }
  | { id: string; type: "radial"; cx: number; cy: number; r: number; stops: readonly Stop[]; transform?: string }

export type Item = {
  d: string
  fill?: string
  stroke?: string
  width?: number
  opacity?: number
  clip?: string
  cap?: "round" | "butt"
  join?: "round" | "miter"
  evenOdd?: boolean
}

export type ClipDef = { id: string; d: string }

export type DisplayList = {
  width: number
  height: number
  gradients: Gradient[]
  clips: ClipDef[]
  items: Item[]
}

const f = (n: number): string => (Math.round(n * 10) / 10).toString()

export function polyD(pts: readonly Pt[], closed = true): string {
  if (pts.length === 0) return ""
  let d = `M${f(pts[0]![0])} ${f(pts[0]![1])}`
  for (let i = 1; i < pts.length; i++) d += `L${f(pts[i]![0])} ${f(pts[i]![1])}`
  return closed ? d + "Z" : d
}

/** Curva suave passando pelos pontos médios (menos pontos, contorno orgânico). */
export function smoothD(pts: readonly Pt[], closed = true): string {
  const n = pts.length
  if (n < 3) return polyD(pts, closed)
  const mid = (a: Pt, b: Pt): Pt => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]
  if (closed) {
    const m0 = mid(pts[n - 1]!, pts[0]!)
    let d = `M${f(m0[0])} ${f(m0[1])}`
    for (let i = 0; i < n; i++) {
      const p = pts[i]!, m = mid(p, pts[(i + 1) % n]!)
      d += `Q${f(p[0])} ${f(p[1])} ${f(m[0])} ${f(m[1])}`
    }
    return d + "Z"
  }
  let d = `M${f(pts[0]![0])} ${f(pts[0]![1])}`
  for (let i = 1; i < n - 1; i++) {
    const p = pts[i]!, m = mid(p, pts[i + 1]!)
    d += `Q${f(p[0])} ${f(p[1])} ${f(m[0])} ${f(m[1])}`
  }
  const last = pts[n - 1]!
  return d + `L${f(last[0])} ${f(last[1])}`
}

export function ellipseD(cx: number, cy: number, rx: number, ry: number): string {
  return `M${f(cx - rx)} ${f(cy)}a${f(rx)} ${f(ry)} 0 1 0 ${f(rx * 2)} 0a${f(rx)} ${f(ry)} 0 1 0 ${f(-rx * 2)} 0Z`
}

export class Painter {
  readonly list: DisplayList
  private n = 0
  constructor(width: number, height: number, private readonly prefix = "p") {
    this.list = { width, height, gradients: [], clips: [], items: [] }
  }
  add(item: Item): void {
    if (item.d) this.list.items.push(item)
  }
  fill(d: string, fill: string, opacity?: number, clip?: string): void {
    const it: Item = { d, fill }
    if (opacity !== undefined && opacity < 1) it.opacity = opacity
    if (clip) it.clip = clip
    this.add(it)
  }
  stroke(d: string, stroke: string, width: number, opacity?: number, clip?: string): void {
    const it: Item = { d, stroke, width, cap: "round", join: "round" }
    if (opacity !== undefined && opacity < 1) it.opacity = opacity
    if (clip) it.clip = clip
    this.add(it)
  }
  linear(x1: number, y1: number, x2: number, y2: number, stops: readonly Stop[]): string {
    const id = `${this.prefix}g${this.n++}`
    this.list.gradients.push({ id, type: "linear", x1, y1, x2, y2, stops })
    return `url(#${id})`
  }
  radial(cx: number, cy: number, r: number, stops: readonly Stop[], sx = 1, sy = 1, rot = 0): string {
    const id = `${this.prefix}g${this.n++}`
    const g: Gradient = { id, type: "radial", cx: 0, cy: 0, r: 1, stops, transform: `translate(${f(cx)} ${f(cy)}) rotate(${f((rot * 180) / Math.PI)}) scale(${f(r * sx)} ${f(r * sy)})` }
    this.list.gradients.push(g)
    return `url(#${id})`
  }
  clip(d: string): string {
    const id = `${this.prefix}c${this.n++}`
    this.list.clips.push({ id, d })
    return id
  }
}

const esc = (s: string): string => s.replace(/"/g, "&quot;")

export function toSvg(list: DisplayList, opts: { background?: string } = {}): string {
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${list.width} ${list.height}" width="${list.width}" height="${list.height}">`)
  out.push("<defs>")
  for (const g of list.gradients) {
    const stops = g.stops.map(([o, c, a]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join("")
    if (g.type === "linear") out.push(`<linearGradient id="${g.id}" gradientUnits="userSpaceOnUse" x1="${f(g.x1)}" y1="${f(g.y1)}" x2="${f(g.x2)}" y2="${f(g.y2)}">${stops}</linearGradient>`)
    else out.push(`<radialGradient id="${g.id}" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="1"${g.transform ? ` gradientTransform="${g.transform}"` : ""}>${stops}</radialGradient>`)
  }
  for (const c of list.clips) out.push(`<clipPath id="${c.id}"><path d="${esc(c.d)}"/></clipPath>`)
  out.push("</defs>")
  if (opts.background) out.push(`<rect width="${list.width}" height="${list.height}" fill="${opts.background}"/>`)
  for (const it of list.items) {
    const a: string[] = [`d="${esc(it.d)}"`]
    a.push(`fill="${it.fill ?? "none"}"`)
    if (it.stroke) a.push(`stroke="${it.stroke}" stroke-width="${f(it.width ?? 1)}"`)
    if (it.cap) a.push(`stroke-linecap="${it.cap}"`)
    if (it.join) a.push(`stroke-linejoin="${it.join}"`)
    if (it.opacity !== undefined) a.push(`opacity="${Math.round(it.opacity * 1000) / 1000}"`)
    if (it.clip) a.push(`clip-path="url(#${it.clip})"`)
    if (it.evenOdd) a.push(`fill-rule="evenodd"`)
    out.push(`<path ${a.join(" ")}/>`)
  }
  out.push("</svg>")
  return out.join("")
}
