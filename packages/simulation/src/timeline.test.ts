import { describe, expect, it } from "vitest"
import type { PersonId, TimelineId } from "@paralelo/shared"
import { absoluteMinute, createWorld, entryWeight, executeCommand, queryDecision, queryLife, queryPeriod, summarizeRoutine, type Command, type TimelineEntry, type WorldState } from "."

const apply = (world: WorldState, command: Command): WorldState => {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
const run = (start: WorldState, days: number): WorldState => {
  let world = start
  const end = absoluteMinute(world.clock) + days * 1440
  while (absoluteMinute(world.clock) < end) {
    const pending = queryDecision(world), choice = pending?.choices.at(-1)
    world = apply(world, pending && choice ? { type: "decide", decisionId: pending.id, choiceId: choice.id }
      : { type: "wait", minutes: Math.min(10080, end - absoluteMinute(world.clock)) })
  }
  return world
}
const entry = (kind: TimelineEntry["kind"], cause: string, text = "x", personIds: PersonId[] = []): TimelineEntry =>
  ({ id: "timeline:1" as TimelineId, at: { day: 0, minute: 600 }, kind, cause, text, personIds })

describe("timeline editorial (bíblia §6.2–6.4)", () => {
  it("dá peso conforme o que o fato muda na vida", () => {
    expect(entryWeight(entry("chapter", "world.created"))).toBe("marco")
    expect(entryWeight(entry("action", "command.rest"))).toBe("ruido")
    expect(entryWeight(entry("career", "career.shift:e"))).toBe("cotidiano")
    expect(entryWeight(entry("career", "career.restructure:e"))).toBe("importante")
    expect(entryWeight(entry("career", "career.application:v", "Padaria aceitou seu currículo"))).toBe("importante")
    expect(entryWeight(entry("message", "message:3"))).toBe("relevante")
    expect(entryWeight(entry("relationship", "message.ignored:m"))).toBe("relevante")
    expect(entryWeight(entry("finance", "schedule:x", "A conta ficou negativa."))).toBe("importante")
  })

  it("resume a rotina a partir de fatos reais", () => {
    const world = createWorld("resumo")
    const friend = "person:friend-a" as PersonId
    const text = summarizeRoutine(world, [
      entry("career", "career.shift:e"), entry("career", "career.shift:e"), entry("action", "command.meal:home"),
      entry("action", "command.sleep"), entry("relationship", "command.contact:r", "x", [world.playerId, friend]),
    ])
    expect(text).toBe(`Você trabalhou dois turnos, fez uma refeição, dormiu uma noite inteira e falou com ${world.people[friend]!.name.split(" ")[0]}.`)
    expect(summarizeRoutine(world, [entry("message", "message:1")])).toBeNull()
  })

  it("dias anteriores mostram só o que pesa, com a rotina em uma frase", () => {
    let world = createWorld("dias")
    world = apply(world, { type: "rest" })
    world = apply(world, { type: "meal", source: "home" })
    world = run(world, 2)
    const life = queryLife(world)
    const past = life.days.filter(d => d.day !== "Hoje")
    expect(past.length).toBeGreaterThan(0)
    for (const day of past) for (const e of day.entries) expect(["relevante", "importante", "marco"]).toContain(e.weight)
    expect(past.some(d => d.summary?.includes("descansar"))).toBe(true)
  })

  it("resume um salto de tempo com o fato mais importante", () => {
    const start = createWorld("salto")
    const from = absoluteMinute(start.clock)
    const world = run(start, 3)
    const period = queryPeriod(world, from + 1)
    expect(period.span).toBe("Três dias depois.")
    expect(period.count).toBeGreaterThan(0)
  })

  it("apaga ruído antigo e guarda marcos por anos", () => {
    const world = run(createWorld("historico"), 400)
    const now = absoluteMinute(world.clock)
    for (const e of world.timeline) {
      const age = now - absoluteMinute(e.at), weight = entryWeight(e)
      if (weight === "ruido") expect(age).toBeLessThanOrEqual(37 * 1440)
      if (weight === "cotidiano") expect(age).toBeLessThanOrEqual(372 * 1440)
    }
    expect(world.timeline.some(e => e.cause === "world.created")).toBe(true)
  })
})
