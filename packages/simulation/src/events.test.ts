import { describe, expect, it } from "vitest"
import { lifeEvents, validateLifeEvents } from "@paralelo/content"
import type { DecisionId } from "@paralelo/shared"
import { decodeSnapshot, encodeSnapshot } from "@paralelo/persistence"
import { absoluteMinute, createWorld, executeCommand, queryDecision, validateWorld, worldHash, type Command, type WorldState } from "."

const apply = (world: WorldState, command: Command) => {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
function pendingWorld(definitionId: string): WorldState {
  const world = createWorld("events")
  const definition = lifeEvents.find(event => event.id === definitionId)!
  const actorId = definition.actor === "mother" ? world.people["person:mother"]!.id : definition.actor ? world.people["person:friend-a"]!.id : null
  return { ...world, nextId: world.nextId + 1, events: { ...world.events, seen: [definition.id], lastOfferedDay: world.clock.day,
    pending: { id: `decision:${world.nextId}` as DecisionId, definitionId, actorId, at: world.clock } } }
}
describe("eventos declarativos e decisões", () => {
  it("valida 30 eventos, dez cadeias acíclicas e rejeita conteúdo quebrado", () => {
    expect(lifeEvents).toHaveLength(30)
    expect(lifeEvents.filter(event => event.root)).toHaveLength(10)
    expect(validateLifeEvents()).toEqual([])
    const broken = { ...lifeEvents[0]!, choices: [{ ...lifeEvents[0]!.choices[0]!, followUp: "ausente" }, lifeEvents[0]!.choices[1]!] }
    expect(validateLifeEvents([broken]).length).toBeGreaterThan(0)
    const cyclic = { ...lifeEvents[0]!, choices: [{ ...lifeEvents[0]!.choices[0]!, followUp: lifeEvents[0]!.id }, lifeEvents[0]!.choices[1]!] }
    expect(validateLifeEvents([cyclic]).some(error => error.includes("Ciclo"))).toBe(true)
    const inaccessible = { ...lifeEvents[0]!, conditions: [{ type: "energy" as const, min: 80, max: 10 }], choices: lifeEvents[0]!.choices.map(option => ({ ...option, followUp: undefined, effect: { ...option.effect, moneyCents: -500 } })) }
    expect(validateLifeEvents([inaccessible]).some(error => error.includes("Condição inválida"))).toBe(true)
    expect(validateLifeEvents([inaccessible]).some(error => error.includes("alternativa gratuita"))).toBe(true)
  })
  it("executa todas as escolhas com efeitos, ledger consistente e estado imutável", () => {
    for (const definition of lifeEvents) for (const option of definition.choices) {
      const before = pendingWorld(definition.id), hash = worldHash(before)
      const after = apply(before, { type: "decide", decisionId: before.events.pending!.id, choiceId: option.id })
      expect(worldHash(before)).toBe(hash)
      expect(after.finance.balanceCents - before.finance.balanceCents).toBe(option.effect.moneyCents ?? 0)
      expect(absoluteMinute(after.clock) - absoluteMinute(before.clock)).toBe(option.effect.minutes)
      expect(after.events.pending).toBeNull()
      expect(after.timeline.at(-1)?.kind).toBe("decision")
      expect(after.timeline.at(-1)?.text.includes("{person}")).toBe(false)
      expect(validateWorld(after)).toMatchObject({ ok: true })
    }
  })
  it("não escolhe pelo jogador, conserva decisão no save e rejeita replay", () => {
    let world = apply(createWorld("night"), { type: "wait", minutes: 10080 })
    expect(world.clock.minute).toBe(1080) // Mensagem da mãe antes da primeira decisão.
    world = apply(world, { type: "wait", minutes: 10080 })
    expect(world.events.pending).not.toBeNull()
    expect(executeCommand(world, { type: "rest" })).toMatchObject({ ok: false, error: { code: "pending-decision" } })
    const saved = decodeSnapshot(encodeSnapshot(world))
    expect(saved).toEqual({ ok: true, value: world })
    const decision = queryDecision(world)!, option = decision.choices.at(-1)!
    const after = apply(world, { type: "decide", decisionId: decision.id, choiceId: option.id })
    expect(executeCommand(after, { type: "decide", decisionId: decision.id, choiceId: option.id }).ok).toBe(false)
    expect(after.revision).toBe(world.revision + 1)
  })
  it("bloqueia opção paga sem saldo e mantém alternativa gratuita", () => {
    const base = pendingWorld("cafe"), world = { ...base, finance: { ...base.finance, openingBalanceCents: 0, balanceCents: 0 } }
    const decision = queryDecision(world)!
    expect(decision.choices[0]?.canChoose).toBe(false)
    expect(decision.choices[1]?.canChoose).toBe(true)
    expect(executeCommand(world, { type: "decide", decisionId: decision.id, choiceId: "go" })).toMatchObject({ ok: false, error: { code: "insufficient-money" } })
    expect(apply(world, { type: "decide", decisionId: decision.id, choiceId: "stay" }).events.pending).toBeNull()
  })
  it("continua a cadeia com a mesma pessoa e orçamento de atenção diário", () => {
    let world = pendingWorld("cafe")
    const actorId = world.events.pending!.actorId
    world = { ...world, events: { ...world.events, seen: lifeEvents.filter(event => event.root).map(event => event.id) } }
    world = apply(world, { type: "decide", decisionId: world.events.pending!.id, choiceId: "go" })
    for (const expected of ["planos", "companhia"]) {
      while (!world.events.pending) world = apply(world, { type: "wait", minutes: 1440 })
      expect(world.events.pending.definitionId).toBe(expected)
      expect(world.events.pending.actorId).toBe(actorId)
      const pending = queryDecision(world)!
      world = apply(world, { type: "decide", decisionId: pending.id, choiceId: pending.choices[0]!.id })
    }
    expect(world.events.seen).toContain("companhia")
    expect(world.scheduled.filter(event => event.kind === "event-followup")).toHaveLength(0)
    expect(validateWorld(world).ok).toBe(true)
  })
})
