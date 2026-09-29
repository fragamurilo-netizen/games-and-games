import { err, ok, type Result } from "@paralelo/shared"
import { validateWorld, worldHash, type WorldState } from "@paralelo/simulation"

export type SaveError = Readonly<{ code: "invalid-save" | "unsupported-version" | "storage"; message: string }>
export function encodeSnapshot(world: WorldState): string {
  return JSON.stringify({ schemaVersion: 1, hash: worldHash(world), world })
}
export function decodeSnapshot(payload: string): Result<WorldState, SaveError> {
  let value: unknown
  try { value = JSON.parse(payload) } catch { return err({ code: "invalid-save", message: "O arquivo de save está incompleto." }) }
  if (!value || typeof value !== "object" || !("schemaVersion" in value)) return err({ code: "invalid-save", message: "Cabeçalho do save ausente." })
  if (value.schemaVersion !== 1) return err({ code: "unsupported-version", message: "Este save usa uma versão ainda não suportada." })
  if (!("world" in value) || !("hash" in value)) return err({ code: "invalid-save", message: "Conteúdo do save ausente." })
  const checked = validateWorld(value.world)
  if (!checked.ok) return err({ code: "invalid-save", message: checked.error.join(" ") })
  if (value.hash !== worldHash(checked.value)) return err({ code: "invalid-save", message: "O save não passou na verificação de integridade." })
  return ok(checked.value)
}
