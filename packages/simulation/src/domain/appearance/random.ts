// Gerador com seed local para a aparência. A aparência nasce de uma seed de pessoa
// e não consome as streams do mundo (rng/index.ts), então não altera saves nem sorteios.
import { hashText } from "../../rng"

export type SeededRandom = {
  next(): number
  normal(): number
  /** normal limitada a ±limit desvios */
  z(sd?: number, limit?: number): number
  chance(p: number): boolean
  pick<T>(items: readonly T[]): T
}

export function seededRandom(seed: number | string): SeededRandom {
  let a = (typeof seed === "number" ? seed : hashText(seed)) >>> 0
  const next = (): number => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
  const normal = (): number => {
    let u = 0
    while (u === 0) u = next()
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * next())
  }
  return {
    next,
    normal,
    z: (sd = 1, limit = 2.6) => Math.max(-limit, Math.min(limit, normal() * sd)),
    chance: (p) => next() < p,
    pick: <T>(items: readonly T[]): T => {
      if (items.length === 0) throw new Error("pick() em lista vazia")
      return items[Math.floor(next() * items.length)] as T
    },
  }
}
