import type { WorldState } from "./domain/world"
import { hashText } from "./rng"

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>
    return `{${Object.keys(obj).filter(key => obj[key] !== undefined).sort().map(key => `${JSON.stringify(key)}:${canonical(obj[key])}`).join(",")}}`
  }
  return JSON.stringify(value) ?? "null"
}
// Hash de diagnóstico, não criptográfico. Inclui relógio, RNG e comandos.
export const worldHash = (world: WorldState): string => hashText(canonical(world)).toString(16).padStart(8, "0")
