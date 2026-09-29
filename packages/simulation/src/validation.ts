import { err, ok, type Result } from "@paralelo/shared"
import type { WorldState } from "./domain/world"
import { RNG_STREAMS } from "./rng"
import { absoluteMinute } from "./time"

const object = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value)
const text = (value: unknown): value is string => typeof value === "string" && value.length > 0 && value.length <= 2000
const number = (value: unknown, min = 0, max = 100): value is number => typeof value === "number" && Number.isFinite(value) && value >= min && value <= max
const integer = (value: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): value is number => number(value, min, max) && Number.isSafeInteger(value)
const id = (value: unknown): value is string => text(value) && /^[a-z][a-z0-9:.-]{0,199}$/.test(value)
const date = (value: unknown): value is { day: number; minute: number } => object(value) && integer(value.day, -366000, 366000) && integer(value.minute, 0, 1439)
const stringArray = (value: unknown): value is string[] => Array.isArray(value) && value.every(id) && new Set(value).size === value.length
const command = (value: unknown): boolean => object(value) &&
  (value.type === "rest" || (value.type === "wait" && integer(value.minutes, 1, 10080)) || (value.type === "contact" && id(value.personId)))

// Valida forma e referências antes de converter dados externos em domínio.
export function validateWorld(input: unknown): Result<WorldState, readonly string[]> {
  const errors: string[] = []
  if (!object(input)) return err(["Save não é um objeto."])
  if (input.schemaVersion !== 1) return err(["Versão de save não suportada; é necessário um migrador explícito."])
  if (!text(input.seed) || input.seed.length > 200 || !input.seed.trim()) errors.push("Seed inválida.")
  if (!date(input.clock) || input.clock.day < 0) errors.push("Relógio inválido.")
  if (!integer(input.revision) || !integer(input.nextId, 1) || !id(input.playerId) || !text(input.city)) errors.push("Metadados inválidos.")
  const rng = object(input.rng) ? input.rng : {}
  if (!object(input.rng) || RNG_STREAMS.some(stream => !integer(rng[stream]))) errors.push("Streams RNG inválidas.")
  const people = object(input.people) ? input.people : {}
  const relationships = object(input.relationships) ? input.relationships : {}
  const households = object(input.households) ? input.households : {}
  const residences = object(input.residences) ? input.residences : {}
  if (!object(input.people) || !object(input.relationships) || !object(input.households) || !object(input.residences)) errors.push("Coleções de entidades inválidas.")
  if (!id(input.playerId) || !Object.hasOwn(people, input.playerId)) errors.push("Jogador ausente.")
  for (const [key, person] of Object.entries(people)) {
    if (!id(key) || !object(person) || person.id !== key || !text(person.name) || !text(person.appearanceSeed) || !date(person.birthDate) ||
      !id(person.householdId) || !Object.hasOwn(households, person.householdId) || !id(person.residenceId) || !Object.hasOwn(residences, person.residenceId) ||
      !object(person.needs) || !number(person.needs.energy) || !number(person.needs.stress) ||
      !object(person.personality) || ![person.personality.sociability, person.personality.discipline, person.personality.sensitivity].every(v => number(v, 0, 1)) ||
      !stringArray(person.relationshipIds)) { errors.push(`Pessoa inválida: ${key}.`); continue }
    if (date(input.clock) && absoluteMinute(person.birthDate) > absoluteMinute(input.clock)) errors.push(`Nascimento futuro: ${key}.`)
    for (const relId of person.relationshipIds) {
      const rel = relationships[relId]
      if (!object(rel) || (rel.a !== key && rel.b !== key)) errors.push(`Relação sem referência recíproca: ${key}/${relId}.`)
    }
    const household = households[person.householdId]
    if (!object(household) || !Array.isArray(household.memberIds) || !household.memberIds.includes(key)) errors.push(`Família sem pessoa: ${key}.`)
  }
  for (const [key, residence] of Object.entries(residences))
    if (!id(key) || !object(residence) || residence.id !== key || !text(residence.district)) errors.push(`Residência inválida: ${key}.`)
  for (const [key, household] of Object.entries(households)) {
    if (!id(key) || !object(household) || household.id !== key || !stringArray(household.memberIds) || household.memberIds.length === 0) { errors.push(`Família inválida: ${key}.`); continue }
    for (const memberId of household.memberIds) {
      const member = people[memberId]
      if (!object(member) || member.householdId !== key) errors.push(`Morador inválido: ${key}/${memberId}.`)
    }
  }
  for (const [key, rel] of Object.entries(relationships)) {
    if (!id(key) || !object(rel) || rel.id !== key || !id(rel.a) || !id(rel.b) || rel.a === rel.b || !Object.hasOwn(people, rel.a) || !Object.hasOwn(people, rel.b) ||
      ![rel.familiarity, rel.affection, rel.trust, rel.respect, rel.attraction, rel.resentment].every(v => number(v)) ||
      !Array.isArray(rel.tags) || !rel.tags.every(tag => tag === "family" || tag === "friend") ||
      (rel.lastInteractionAt !== undefined && (!date(rel.lastInteractionAt) || (date(input.clock) && absoluteMinute(rel.lastInteractionAt) > absoluteMinute(input.clock))))) {
      errors.push(`Relação inválida: ${key}.`); continue
    }
    for (const personId of [rel.a, rel.b]) {
      const person = people[personId]
      if (!object(person) || !Array.isArray(person.relationshipIds) || !person.relationshipIds.includes(key)) errors.push(`Índice de relação ausente: ${key}/${personId}.`)
    }
  }
  const seen = new Set<string>()
  if (!Array.isArray(input.timeline) || input.timeline.length === 0) errors.push("Histórico inválido.")
  else for (const entry of input.timeline) {
    if (!object(entry) || !id(entry.id) || seen.has(entry.id) || !date(entry.at) || !text(entry.text) || !text(entry.cause) ||
      !["chapter", "action", "relationship", "message"].includes(String(entry.kind)) || !stringArray(entry.personIds) || entry.personIds.some(p => !Object.hasOwn(people, p)) ||
      (date(input.clock) && absoluteMinute(entry.at) > absoluteMinute(input.clock))) { errors.push("Entrada de timeline inválida."); continue }
    seen.add(entry.id)
    const sequence = /^timeline:(\d+)$/.exec(entry.id)
    if (!sequence || !integer(input.nextId) || Number(sequence[1]) >= input.nextId) errors.push("Sequência de ID da timeline inválida.")
  }
  const schedules = new Set<string>()
  if (!Array.isArray(input.scheduled)) errors.push("Agenda inválida.")
  else for (const item of input.scheduled) {
    if (!object(item) || !id(item.id) || schedules.has(item.id) || !date(item.at) || item.kind !== "mother-message" || !id(item.personId) || !Object.hasOwn(people, item.personId) ||
      typeof item.interrupts !== "boolean" || (date(input.clock) && absoluteMinute(item.at) < absoluteMinute(input.clock))) errors.push("Evento agendado inválido.")
    else schedules.add(item.id)
  }
  let lastRevision = 0
  if (!Array.isArray(input.recentCommands) || input.recentCommands.length > 256) errors.push("Log de comandos inválido.")
  else for (const item of input.recentCommands) {
    if (!object(item) || !integer(item.revision, lastRevision + 1) || !integer(input.revision) || item.revision > input.revision || !date(item.at) || !command(item.command) ||
      (date(input.clock) && absoluteMinute(item.at) > absoluteMinute(input.clock))) errors.push("Comando histórico inválido.")
    else lastRevision = item.revision
  }
  return errors.length ? err(errors) : ok(input as unknown as WorldState)
}
