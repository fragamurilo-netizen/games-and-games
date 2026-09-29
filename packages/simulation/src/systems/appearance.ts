import { firstNameSex } from "@paralelo/content"
import type { Person, WorldState, WorldStateV4 } from "../domain/world"
import { hashText } from "../rng"

/** Sexo de um personagem criado a partir das listas de nomes; nomes fora da lista usam a seed de aparência. */
export function sexForName(name: string, appearanceSeed: string): Person["sex"] {
  const first = name.trim().split(/\s+/)[0] ?? ""
  return firstNameSex[first] ?? (hashText(`${appearanceSeed}/sex`) % 2 ? "M" : "F")
}

// Migração aditiva v4 -> v5: só acrescenta o sexo; não consome RNG nem muda outros campos.
export function upgradeWorldV4(base: WorldStateV4): WorldState {
  const people = Object.fromEntries(Object.entries(base.people).map(([id, person]) => [id, { ...person, sex: sexForName(person.name, person.appearanceSeed) }]))
  return { ...base, schemaVersion: 5, people }
}
