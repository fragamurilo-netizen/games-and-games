import { describe, expect, it } from "vitest"
import { lifeEvents } from "@paralelo/content"
import { addMinutes, ageAt, calendarDate, createRng, createWorld, dayFromCalendar, draw, executeCommand, queryLife, validateWorld, worldHash, type Command, type WorldState } from "."

const apply = (world: WorldState, command: Command): WorldState => {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
describe("fundação determinística", () => {
  it("reproduz mundo e sequência de comandos sem mutar o estado anterior", () => {
    const start = createWorld("flores")
    const snapshot = JSON.stringify(start)
    const commands: Command[] = [{ type: "rest" }, { type: "contact", personId: start.people["person:mother"]!.id }, { type: "wait", minutes: 1440 }]
    const first = commands.reduce(apply, start)
    const second = commands.reduce(apply, createWorld("flores"))
    expect(first).toEqual(second)
    expect(worldHash(first)).toBe(worldHash(second))
    expect(JSON.stringify(start)).toBe(snapshot)
    expect(validateWorld(first).ok).toBe(true)
    expect(createWorld("outra-seed")).not.toEqual(start)
  })
  it("isola streams e conserva cursores serializáveis", () => {
    const rng = createRng()
    const health = draw("s", rng, "health")
    expect(draw("s", health.state, "relationship").value).toBe(draw("s", rng, "relationship").value)
    expect(draw("s", rng, "health").value).toBe(health.value)
    expect(draw("s", health.state, "health").state.health).toBe(2)
    expect(rng.health).toBe(0)
  })
  it("pausa skip na mensagem e a processa uma só vez", () => {
    const generated = createWorld("s")
    const start = { ...generated, events: { ...generated.events, seen: lifeEvents.map(event => event.id) } }
    const paused = apply(start, { type: "wait", minutes: 10080 })
    expect(paused.clock).toEqual({ day: 0, minute: 1080 })
    expect(paused.timeline.filter(e => e.kind === "message")).toHaveLength(1)
    const resumed = apply(paused, { type: "wait", minutes: 10080 })
    expect(resumed.clock).toEqual({ day: 7, minute: 1080 })
    expect(resumed.timeline.filter(e => e.kind === "message")).toHaveLength(1)
  })
  it("não pula eventos durante descanso e mantém a duração da ação", () => {
    const start = apply(createWorld("s"), { type: "wait", minutes: 570 })
    const rested = apply(start, { type: "rest" })
    expect(rested.clock).toEqual({ day: 0, minute: 1170 })
    expect(rested.timeline.at(-2)?.at.minute).toBe(1080)
    expect(rested.timeline.at(-1)?.kind).toBe("action")
  })
  it("recusa duração inválida, pessoa ausente e grind social sem consumir RNG", () => {
    const start = createWorld("s")
    for (const minutes of [NaN, Infinity, -1, 0, 1.5, 10081]) expect(executeCommand(start, { type: "wait", minutes }).ok).toBe(false)
    expect(executeCommand(start, { type: "contact", personId: start.playerId }).ok).toBe(false)
    const called = apply(start, { type: "contact", personId: start.people["person:mother"]!.id })
    const hash = worldHash(called)
    expect(executeCommand(called, { type: "contact", personId: start.people["person:mother"]!.id })).toMatchObject({ ok: false, error: { code: "cooldown" } })
    expect(worldHash(called)).toBe(hash)
    expect(queryLife(called).people.find(p => p.id === "person:mother")?.canContact).toBe(false)
    const result = apply(called, { type: "wait", minutes: 480 })
    expect(queryLife(result).people.find(p => p.id === "person:mother")?.canContact).toBe(true)
  })
  it("calcula viradas de dia, aniversário e anos bissextos sem Date", () => {
    expect(addMinutes({ day: 0, minute: 1439 }, 2)).toEqual({ day: 1, minute: 1 })
    for (const [year, month, day] of [[2024, 2, 29], [2000, 2, 29], [2100, 3, 1], [2026, 1, 5]])
      expect(calendarDate(dayFromCalendar(year!, month!, day!))).toEqual({ year, month, day })
    const birth = { day: dayFromCalendar(2003, 4, 7), minute: 0 }
    expect(ageAt(birth, { day: dayFromCalendar(2026, 4, 6), minute: 0 })).toBe(22)
    expect(ageAt(birth, { day: dayFromCalendar(2026, 4, 7), minute: 0 })).toBe(23)
  })
  it("retorna read models que não editam o domínio", () => {
    const world = createWorld("s"), hash = worldHash(world)
    const view = queryLife(world)
    view.timeline[0]!.text = "editado"
    view.people[0]!.name = "editado"
    expect(worldHash(world)).toBe(hash)
  })
  it("detecta save com referências quebradas e limites inválidos", () => {
    const base = createWorld("s")
    expect(validateWorld({ ...base, people: {} }).ok).toBe(false)
    expect(validateWorld({ ...base, nextId: 1 }).ok).toBe(false)
    expect(validateWorld({ ...base, clock: { day: -1, minute: 1440 } }).ok).toBe(false)
    expect(validateWorld({ ...base, rng: { ...base.rng, event: NaN } }).ok).toBe(false)
    expect(validateWorld({ ...base, relationships: {} }).ok).toBe(false)
  })
})
