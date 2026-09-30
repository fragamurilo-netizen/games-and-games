import type { WorldState, WorldStateV1, WorldStateV2, WorldStateV3, WorldStateV4, WorldStateV5, WorldStateV6, WorldStateV7 } from "./domain/world"
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
export const worldHash = (world: WorldState | WorldStateV1 | WorldStateV2 | WorldStateV3 | WorldStateV4 | WorldStateV5 | WorldStateV6 | WorldStateV7): string => hashText(canonical(world)).toString(16).padStart(8, "0")
