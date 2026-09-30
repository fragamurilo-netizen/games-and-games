import { err, ok, type Result } from "@paralelo/shared"
import {
  validateWorld, validateWorldV1, validateWorldV2, validateWorldV3, validateWorldV4, validateWorldV5, validateWorldV6,
  upgradeWorldV1, upgradeWorldV2, upgradeWorldV3, upgradeWorldV4, upgradeWorldV5, upgradeWorldV6, worldHash, type WorldState,
  type WorldStateV1, type WorldStateV2, type WorldStateV3, type WorldStateV4, type WorldStateV5, type WorldStateV6,
} from "@paralelo/simulation"

export type SaveError = Readonly<{ code: "invalid-save" | "unsupported-version" | "storage"; message: string }>
export const SAVE_VERSION = 7
export function encodeSnapshot(world: WorldState): string {
  return JSON.stringify({ schemaVersion: SAVE_VERSION, hash: worldHash(world), world })
}

type AnyWorld = WorldStateV1 | WorldStateV2 | WorldStateV3 | WorldStateV4 | WorldStateV5 | WorldStateV6 | WorldState
const validators: Readonly<Record<number, (input: unknown) => Result<AnyWorld, readonly string[]>>> = {
  1: validateWorldV1, 2: validateWorldV2, 3: validateWorldV3, 4: validateWorldV4, 5: validateWorldV5, 6: validateWorldV6, 7: validateWorld,
}
// Cadeia de migrações registradas: cada versão sobe um degrau até a atual.
function upgrade(world: AnyWorld): WorldState {
  switch (world.schemaVersion) {
    case 1: return upgrade(upgradeWorldV1(world))
    case 2: return upgrade(upgradeWorldV2(world))
    case 3: return upgrade(upgradeWorldV3(world))
    case 4: return upgrade(upgradeWorldV4(world))
    case 5: return upgrade(upgradeWorldV5(world))
    case 6: return upgradeWorldV6(world)
    case 7: return world
  }
}

export function decodeSnapshot(payload: string): Result<WorldState, SaveError> {
  let value: unknown
  try { value = JSON.parse(payload) } catch { return err({ code: "invalid-save", message: "O arquivo de save está incompleto." }) }
  if (!value || typeof value !== "object" || !("schemaVersion" in value)) return err({ code: "invalid-save", message: "Cabeçalho do save ausente." })
  const validate = typeof value.schemaVersion === "number" ? validators[value.schemaVersion] : undefined
  if (!validate) return err({ code: "unsupported-version", message: "Este save usa uma versão ainda não suportada." })
  if (!("world" in value) || !("hash" in value)) return err({ code: "invalid-save", message: "Conteúdo do save ausente." })
  const checked = validate(value.world)
  if (!checked.ok) return err({ code: "invalid-save", message: checked.error.join(" ") })
  if (value.hash !== worldHash(checked.value)) return err({ code: "invalid-save", message: "O save não passou na verificação de integridade." })
  if (checked.value.schemaVersion === SAVE_VERSION) return ok(checked.value as WorldState)
  const migrated = validateWorld(upgrade(checked.value))
  return migrated.ok ? ok(migrated.value) : err({ code: "invalid-save", message: migrated.error.join(" ") })
}
