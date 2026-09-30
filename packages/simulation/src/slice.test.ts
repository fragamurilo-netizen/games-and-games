import { describe, expect, it } from "vitest"
import { courses, jobRoles, validateStarterContent } from "@paralelo/content"
import type { CourseId } from "@paralelo/shared"
import { absoluteMinute, createWorld, executeCommand, queryDecision, validateWorld, worldHash, type Command, type WorldState } from "."
import { hireViaInterviews, settle, workShift } from "./test-support"

function apply(world: WorldState, command: Command): WorldState {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
function waitUntil(world: WorldState, minute: number): WorldState {
  while (absoluteMinute(world.clock) < minute) {
    world = queryDecision(world) || world.work.scene ? settle(world)
      : apply(world, { type: "wait", minutes: Math.min(10080, minute - absoluteMinute(world.clock)) })
  }
  return world
}
const hired = (seed = "work"): WorldState => hireViaInterviews(createWorld(seed))
describe("carreira, educação, dinheiro e autonomia", () => {
  it("valida conteúdo e cria entidades estáveis de uma cidade com 100 pessoas", () => {
    const world = createWorld("city")
    expect(validateStarterContent()).toEqual([])
    expect(Object.keys(world.people)).toHaveLength(100)
    expect(Object.keys(world.companies)).toHaveLength(10)
    expect(Object.keys(world.vacancies)).toHaveLength(12)
    expect(Object.keys(world.training)).toHaveLength(3)
    expect(validateWorld(world).ok).toBe(true)
    expect(worldHash(world)).toBe(worldHash(createWorld("city")))
  })
  it("gera seleção reproduzível, fecha a vaga e impede um segundo emprego", () => {
    const first = hired(), second = hired()
    expect(first).toEqual(second)
    expect(first.employment).not.toBeNull()
    const vacancy = Object.values(first.vacancies).find(v => !v.open)!
    expect(executeCommand(first, { type: "apply-job", vacancyId: vacancy.id }).ok).toBe(false)
    const other = Object.values(first.vacancies).find(v => v.open)!
    expect(executeCommand(first, { type: "apply-job", vacancyId: other.id }).ok).toBe(false)
  })
  it("registra turno uma só vez e conserva salário devido mesmo após faltas", () => {
    const start = hired()
    // descansa na véspera e chega às 6h do primeiro dia de trabalho
    const ready = apply(waitUntil(start, start.employment!.requiredFromDay * 1440 - 120), { type: "sleep" })
    const worked = workShift(ready)
    expect(worked.employment?.shiftsWorked).toBe(1)
    expect(executeCommand(worked, { type: "work" }).ok).toBe(false)
    const salary = Math.round(jobRoles.find(r => r.id === worked.employment!.roleId)!.salaryCents / 20)
    expect(worked.employment?.accruedCents).toBe(salary)
    const end = worked.scheduled.find(e => e.kind === "monthly-finance")!
    const paid = waitUntil(worked, absoluteMinute(end.at))
    expect(paid.finance.ledger.map(e => [e.category, e.amountCents])).toEqual([["salary", salary], ["rent", -75000]])
    expect(paid.employment).toBeNull()
    expect(paid.employmentHistory[0]?.settledCents).toBe(salary)
    expect(paid.finance.balanceCents).toBe(80000 + salary - 75000)
    expect(validateWorld(paid).ok).toBe(true)
  })
  it("deixa conta negativa explícita e bloqueia gastos sem saldo", () => {
    let world = createWorld("rent")
    const first = world.scheduled.find(e => e.kind === "monthly-finance")!
    world = waitUntil(world, absoluteMinute(first.at))
    const second = world.scheduled.find(e => e.kind === "monthly-finance")!
    world = waitUntil(world, absoluteMinute(second.at))
    expect(world.finance.balanceCents).toBe(-70000)
    expect(executeCommand(world, { type: "meal" })).toMatchObject({ ok: false, error: { code: "insufficient-money" } })
    expect(validateWorld(world).ok).toBe(true)
  })
  it("cobra aula, melhora habilidade e limita a prática diária", () => {
    const start = createWorld("study"), id = "course:office" as CourseId
    const first = apply(start, { type: "study", courseId: id })
    expect(first.finance.balanceCents).toBe(80000 - courses[0]!.priceCents)
    expect(first.skills[first.playerId]!.organization).toBeGreaterThan(start.skills[start.playerId]!.organization)
    expect(executeCommand(first, { type: "study", courseId: id }).ok).toBe(false)
    let completed = first
    for (let i = 1; i < courses[0]!.sessions; i++) {
      completed = waitUntil(completed, (completed.clock.day + 1) * 1440 + 480)
      completed = apply(completed, { type: "sleep" })
      completed = apply(completed, { type: "meal" })
      completed = apply(completed, { type: "study", courseId: id })
    }
    expect(completed.training[id]?.sessions).toBe(10)
    expect(executeCommand(completed, { type: "study", courseId: id }).ok).toBe(false)
    expect(completed.timeline.at(-1)?.text).toContain("concluiu")
    expect(validateWorld(completed).ok).toBe(true)
  })
  it("pessoas próximas agem sem comando social do jogador e guardam memória", () => {
    const world = waitUntil(createWorld("autonomy"), 60 * 1440)
    expect(world.rng.ai).toBeGreaterThan(0)
    expect(world.memories.length).toBeGreaterThan(0)
    expect(world.timeline.some(e => e.cause.startsWith("ai.contact:"))).toBe(true)
    expect(world.recentCommands.every(c => c.command.type !== "contact")).toBe(true)
    expect(worldHash(waitUntil(createWorld("autonomy"), 60 * 1440))).toBe(worldHash(world))
  })
  it("recusa saldo inconsistente, vaga órfã e curso com progresso impossível", () => {
    const world = createWorld("validator")
    expect(validateWorld({ ...world, finance: { ...world.finance, balanceCents: 79999 } }).ok).toBe(false)
    expect(validateWorld({ ...world, companies: {} }).ok).toBe(false)
    expect(validateWorld({ ...world, training: { ...world.training, "course:office": { sessions: 11, lastStudiedDay: null } } }).ok).toBe(false)
  })
})
