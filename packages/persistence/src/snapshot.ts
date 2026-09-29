import { err, ok, type Result } from "@paralelo/shared"
import { validateWorld, validateWorldV1, validateWorldV2, validateWorldV3, upgradeWorldV1, upgradeWorldV2, upgradeWorldV3, worldHash, type WorldState } from "@paralelo/simulation"

export type SaveError = Readonly<{ code: "invalid-save" | "unsupported-version" | "storage"; message: string }>
export function encodeSnapshot(world: WorldState): string {
  return JSON.stringify({ schemaVersion: 4, hash: worldHash(world), world })
}
export function decodeSnapshot(payload: string): Result<WorldState, SaveError> {
  let value: unknown
  try { value = JSON.parse(payload) } catch { return err({ code: "invalid-save", message: "O arquivo de save está incompleto." }) }
  if (!value || typeof value !== "object" || !("schemaVersion" in value)) return err({ code: "invalid-save", message: "Cabeçalho do save ausente." })
  if (value.schemaVersion !== 1 && value.schemaVersion !== 2 && value.schemaVersion !== 3 && value.schemaVersion !== 4) return err({ code: "unsupported-version", message: "Este save usa uma versão ainda não suportada." })
  if (!("world" in value) || !("hash" in value)) return err({ code: "invalid-save", message: "Conteúdo do save ausente." })
  const checked = value.schemaVersion === 1 ? validateWorldV1(value.world) : value.schemaVersion === 2 ? validateWorldV2(value.world) : value.schemaVersion === 3 ? validateWorldV3(value.world) : validateWorld(value.world)
  if (!checked.ok) return err({ code: "invalid-save", message: checked.error.join(" ") })
  if (value.hash !== worldHash(checked.value)) return err({ code: "invalid-save", message: "O save não passou na verificação de integridade." })
  if (checked.value.schemaVersion === 1) {
    const migrated = validateWorld(upgradeWorldV3(upgradeWorldV2(upgradeWorldV1(checked.value))))
    return migrated.ok ? ok(migrated.value) : err({ code: "invalid-save", message: migrated.error.join(" ") })
  }
  if (checked.value.schemaVersion === 2) {
    const migrated = validateWorld(upgradeWorldV3(upgradeWorldV2(checked.value)))
    return migrated.ok ? ok(migrated.value) : err({ code: "invalid-save", message: migrated.error.join(" ") })
  }
  if (checked.value.schemaVersion === 3) {
    const migrated = validateWorld(upgradeWorldV3(checked.value))
    return migrated.ok ? ok(migrated.value) : err({ code: "invalid-save", message: migrated.error.join(" ") })
  }
  return ok(checked.value)
}
