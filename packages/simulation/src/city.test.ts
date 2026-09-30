import { describe, expect, it } from "vitest"
import { validateCityContent } from "@paralelo/content"
import type { EmploymentId, MessageId } from "@paralelo/shared"
import { absoluteMinute, createWorld, dismissPlayer, executeCommand, queryCareer, queryDecision, queryInbox, queryWorld, relationshipBetween, validateWorld, worldHash, type Command, type WorldState } from "."

const apply = (world: WorldState, command: Command): WorldState => {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
/** Avança o relógio respondendo decisões pela última escolha, como o teste de vida longa. */
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
/** Avança de hora em hora até a condição valer. */
const until = (start: WorldState, done: (world: WorldState) => boolean, maxDays = 60): WorldState => {
  let world = start
  const end = absoluteMinute(world.clock) + maxDays * 1440
  while (!done(world)) {
    if (absoluteMinute(world.clock) >= end) throw new Error("condição não aconteceu a tempo")
    const pending = queryDecision(world), choice = pending?.choices.at(-1)
    world = apply(world, pending && choice ? { type: "decide", decisionId: pending.id, choiceId: choice.id } : { type: "wait", minutes: 60 })
  }
  return world
}

describe("mundo vivo", () => {
  it("tem textos da cidade válidos", () => {
    expect(validateCityContent()).toEqual([])
  })

  it("é determinístico: mesma seed e mesmos comandos dão o mesmo mundo", () => {
    const a = run(createWorld("cidade"), 45), b = run(createWorld("cidade"), 45)
    expect(worldHash(a)).toBe(worldHash(b))
    expect(validateWorld(a).ok).toBe(true)
  })

  it("segue sem o jogador: moradores decidem, empresas contratam e o jornal registra", () => {
    const world = run(createWorld("sem-jogador"), 60)
    const decided = Object.values(world.residents).filter(r => r.lastDecision)
    expect(decided.length).toBeGreaterThan(5)
    for (const r of decided) {
      const d = r.lastDecision!
      expect(d.options.length).toBeGreaterThan(0)
      expect(d.options.map(o => o.action)).toContain(d.chosen)
      // a escolhida é a de maior nota (explicável, bíblia §13.3)
      expect(Math.max(...d.options.map(o => o.score))).toBe(d.options.find(o => o.action === d.chosen)!.score)
    }
    expect(world.news.length).toBeGreaterThan(0)
    expect(world.timeline.some(e => e.kind === "message")).toBe(true)
  })

  it("duas seeds divergem em três meses (bíblia §48)", () => {
    const a = run(createWorld("seed-a"), 90), b = run(createWorld("seed-b"), 90)
    expect(a.news.map(n => n.headline)).not.toEqual(b.news.map(n => n.headline))
    const jobs = (w: WorldState) => Object.values(w.residents).filter(r => r.job).length
    expect([jobs(a), a.news.length, a.inbox.length]).not.toEqual([jobs(b), b.news.length, b.inbox.length])
  })

  it("empresa em crise corta gente e isso chega às pessoas", () => {
    const start = createWorld("crise")
    const economy = Object.fromEntries(Object.keys(start.economy).map(id => [id, { health: 0.1, trend: -0.1, weakWeeks: 1 }]))
    const world = run({ ...start, economy }, 8)
    const layoffs = world.news.filter(n => n.cause.startsWith("economy.layoff:"))
    expect(layoffs.length).toBeGreaterThan(0)
    // quem foi cortado não trabalha mais ali (pode já ter achado outra vaga)
    for (const n of layoffs) for (const id of n.personIds) if (id !== world.playerId) expect(world.residents[id]!.job?.companyId).not.toBe(n.companyId)
    expect(validateWorld(world).ok).toBe(true)
  })

  it("corte do jogador paga os turnos e fica no histórico como reestruturação", () => {
    const start = createWorld("corte")
    const company = Object.values(start.companies)[0]!
    const employed: WorldState = { ...start, employment: { id: "employment:99" as EmploymentId, personId: start.playerId, companyId: company.id, roleId: "counter",
      startedAt: start.clock, lastWorkedDay: null, accruedCents: 12000, shiftsWorked: 2, performance: 60, requiredFromDay: start.clock.day + 1, consecutiveAbsences: 0, lastAssessedDay: null } }
    const world = dismissPlayer(employed)
    expect(world.employment).toBeNull()
    expect(world.employmentHistory.at(-1)?.reason).toBe("restructure")
    expect(world.finance.balanceCents).toBe(start.finance.balanceCents + 12000)
    expect(queryCareer(world).history[0]?.reason).toContain("semanas fracas")
    expect(queryWorld(world).news[0]?.headline).toContain(company.name)
    expect(world.timeline.at(-1)?.text).toContain("não teve relação com faltas")
  })

  it("mensagem sem resposta esfria a relação e vira memória", () => {
    const start = until(createWorld("silencio"), w => w.inbox.some(m => m.status === "unread"))
    const m = start.inbox.find(x => x.status === "unread")!
    const before = relationshipBetween(start, start.playerId, m.fromId)!
    const world = until(start, w => w.inbox.find(x => x.id === m.id)!.status !== "unread", 4)
    expect(world.inbox.find(x => x.id === m.id)!.status).toBe("ignored")
    const after = relationshipBetween(world, world.playerId, m.fromId)!
    expect(after.affection).toBeLessThan(before.affection + 0.0001)
    expect(world.memories.some(mem => mem.cause === m.id && mem.personId === m.fromId)).toBe(true)
    expect(queryInbox(world).some(x => x.id === m.id)).toBe(false)
  })

  it("responder gasta tempo, aproxima e não pode ser repetido", () => {
    const start = until(createWorld("resposta"), w => queryInbox(w).length > 0)
    const item = queryInbox(start)[0]!
    const answer = item.replies.find(r => r.reply === "answer")!
    expect(answer.canReply).toBe(true)
    const before = relationshipBetween(start, start.playerId, item.from.id)!
    const world = apply(start, { type: "reply", messageId: item.id as MessageId, reply: "answer" })
    expect(absoluteMinute(world.clock) - absoluteMinute(start.clock)).toBe(15)
    expect(world.inbox.find(x => x.id === item.id)!.status).toBe("answered")
    expect(relationshipBetween(world, world.playerId, item.from.id)!.affection).toBeGreaterThan(before.affection)
    expect(executeCommand(world, { type: "reply", messageId: item.id as MessageId, reply: "answer" }).ok).toBe(false)
  })

  it("deixar para depois só vale uma vez", () => {
    const start = until(createWorld("depois"), w => queryInbox(w).length > 0)
    const id = queryInbox(start)[0]!.id as MessageId
    const later = apply(start, { type: "reply", messageId: id, reply: "later" })
    expect(later.inbox.find(x => x.id === id)!.postponed).toBe(true)
    expect(executeCommand(later, { type: "reply", messageId: id, reply: "later" })).toMatchObject({ ok: false })
  })
})
