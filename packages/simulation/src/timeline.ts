import type { TimelineId } from "@paralelo/shared"
import type { TimelineEntry, WorldState } from "./domain/world"

export function appendEntry(world: WorldState, entry: Omit<TimelineEntry, "id">): WorldState {
  return { ...world, nextId: world.nextId + 1, timeline: [...world.timeline, { ...entry, id: `timeline:${world.nextId}` as TimelineId }] }
}

// Peso editorial (bíblia §6.2): derivado do tipo e da causa, sem guardar nada a mais no save.
export type EntryWeight = "ruido" | "cotidiano" | "relevante" | "importante" | "marco"
const RANK: Record<EntryWeight, number> = { ruido: 0, cotidiano: 1, relevante: 2, importante: 3, marco: 4 }
export const weightRank = (weight: EntryWeight): number => RANK[weight]

export function entryWeight(entry: Pick<TimelineEntry, "kind" | "cause" | "text">): EntryWeight {
  const cause = entry.cause
  switch (entry.kind) {
    case "chapter": return "marco"
    case "action": return "ruido"
    case "message": return "relevante"
    case "decision": return cause.startsWith("event.choice") ? "importante" : "relevante"
    case "finance": return entry.text.includes("negativa") ? "importante" : "relevante"
    case "education": return entry.text.startsWith("Você concluiu") ? "importante" : "cotidiano"
    case "career":
      if (cause.startsWith("career.dismissed") || cause.startsWith("career.restructure")) return "importante"
      if (cause.startsWith("career.application")) return entry.text.includes("aceitou") ? "importante" : "relevante"
      if (cause.startsWith("career.absence")) return "relevante"
      return "cotidiano"
    case "relationship":
      if (cause.startsWith("message.ignored")) return "relevante"
      if (cause.startsWith("message.later")) return "ruido"
      return "cotidiano"
  }
}

const NUMBERS = ["nenhuma", "uma", "duas", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez"]
const MALE = ["nenhum", "um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez"]
const count = (n: number, one: string, many: string, male = false): string => `${(male ? MALE : NUMBERS)[n] ?? String(n)} ${n === 1 ? one : many}`
const list = (items: readonly string[]): string => items.length <= 1 ? items.join("") : `${items.slice(0, -1).join(", ")} e ${items.at(-1)}`

/**
 * Resumo de um período a partir de fatos reais (bíblia §6.3): conta o que se repetiu e nomeia
 * com quem você falou. Devolve null quando não há rotina para resumir.
 */
export function summarizeRoutine(world: Pick<WorldState, "people" | "playerId">, entries: readonly TimelineEntry[]): string | null {
  const has = (prefix: string) => entries.filter(e => e.cause.startsWith(prefix)).length
  const shifts = has("career.shift"), meals = has("command.meal"), sleeps = has("command.sleep"), rests = has("command.rest")
  const groceries = has("command.buy-groceries"), classes = entries.filter(e => e.kind === "education" && entryWeight(e) === "cotidiano").length
  const talked = [...new Set(entries.filter(e => e.kind === "relationship" && entryWeight(e) === "cotidiano")
    .flatMap(e => e.personIds).filter(id => id !== world.playerId))].map(id => world.people[id]?.name.split(" ")[0]).filter((n): n is string => !!n)
  const parts: string[] = []
  if (shifts) parts.push(shifts === 1 ? "trabalhou um turno" : `trabalhou ${count(shifts, "turno", "turnos", true)}`)
  if (classes) parts.push(`assistiu a ${count(classes, "aula", "aulas")}`)
  if (meals) parts.push(`fez ${count(meals, "refeição", "refeições")}`)
  if (groceries) parts.push("foi ao mercado")
  if (sleeps) parts.push(sleeps === 1 ? "dormiu uma noite inteira" : `dormiu ${count(sleeps, "noite", "noites")} inteiras`)
  if (rests) parts.push(rests === 1 ? "parou para descansar" : `parou ${count(rests, "vez", "vezes", false)} para descansar`)
  if (talked.length) parts.push(`falou com ${list(talked.slice(0, 3))}${talked.length > 3 ? ` e mais ${count(talked.length - 3, "pessoa", "pessoas")}` : ""}`)
  if (!parts.length) return null
  return `Você ${list(parts)}.`
}
