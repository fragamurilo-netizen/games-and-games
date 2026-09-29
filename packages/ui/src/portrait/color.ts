// Cores derivadas do fenótipo.

import { clamp, lerp, type RGB } from "./math"

// Rampa baseada em tons reais de pele (claro -> muito escuro).
const SKIN_RAMP: readonly (readonly [number, RGB])[] = [
  [0, [247, 222, 204]],
  [0.12, [236, 198, 172]],
  [0.25, [222, 176, 142]],
  [0.4, [196, 146, 108]],
  [0.55, [164, 114, 80]],
  [0.7, [126, 84, 58]],
  [0.84, [92, 60, 42]],
  [1, [60, 40, 30]],
]

export function skinColor(melanin: number, undertone: number): RGB {
  let c: RGB = SKIN_RAMP[0]![1]
  for (let i = 1; i < SKIN_RAMP.length; i++) {
    const [t1, c1] = SKIN_RAMP[i]!
    if (melanin <= t1) {
      const [t0, c0] = SKIN_RAMP[i - 1]!
      const t = (melanin - t0) / (t1 - t0)
      c = [lerp(c0[0], c1[0], t), lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t)]
      break
    }
  }
  const u = undertone * 6 * (1 - melanin * 0.6)
  return [c[0] + u * 0.4, c[1] - Math.abs(u) * 0.15, c[2] - u * 0.7 + (u < 0 ? u * 0.4 : 0)]
}

/** Eumelanina escurece; feomelanina avermelha. */
export function hairColor(eumelanin: number, pheomelanin: number): RGB {
  const blonde: RGB = [228, 196, 140]
  const black: RGB = [22, 18, 16]
  const e = Math.pow(eumelanin, 0.8)
  const c: RGB = [lerp(blonde[0], black[0], e), lerp(blonde[1], black[1], e), lerp(blonde[2], black[2], e)]
  const red = pheomelanin > 0.6 ? (pheomelanin - 0.2) * (1 - eumelanin * 0.7) : pheomelanin * 0.3 * (1 - eumelanin)
  return [clamp(c[0] + red * 80, 0, 255), clamp(c[1] - red * 5, 0, 255), clamp(c[2] - red * 55, 0, 255)]
}

export function irisColor(darkness: number, green: number): RGB {
  if (darkness > 0.72) {
    const t = (darkness - 0.72) / 0.28
    return [lerp(110, 45, t), lerp(70, 30, t), lerp(40, 22, t)]
  }
  if (darkness > 0.45) {
    const t = (darkness - 0.45) / 0.27
    return [lerp(120, 110, t), lerp(110 + green * 20, 70, t), lerp(60, 40, t)]
  }
  if (darkness > 0.25) return green > 0.5 ? [95, 128, 80] : [118, 124, 110]
  return green > 0.6 ? [110, 140, 150] : [92, 132, 176]
}

export const GREY_HAIR: RGB = [206, 204, 200]
export const WHITE_HAIR: RGB = [236, 234, 230]
