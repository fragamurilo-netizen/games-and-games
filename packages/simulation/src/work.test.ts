import { describe, expect, it } from "vitest"
import { jobRoles, lifeEvents, validateWorkContent, workRules, workSituations } from "@paralelo/content"
import { decodeSnapshot, encodeSnapshot } from "@paralelo/persistence"
import type { InterviewId } from "@paralelo/shared"
import { absoluteMinute, createWorld, executeCommand, hirePlayer, queryCareer, validateWorld, worldHash, type Workplace, type WorldState } from "."
import { apply, hireViaInterviews, safeChoice, settle, workShift } from "./test-support"

const quiet = (seed: string): WorldState => { const w = createWorld(seed); return { ...w, events: { ...w.events, seen: lifeEvents.map(e => e.id) } } }
function employed(seed = "trabalho", roleId = "stock"): WorldState {
  const world = quiet(seed)
  const vacancy = Object.values(world.vacancies).find(v => v.open && v.roleId === roleId) ?? Object.values(world.vacancies).find(v => v.open)!
  return hirePlayer(world, vacancy.companyId, roleId, vacancy.id, false)
}
/** Leva ao início do próximo dia útil exigido, descansado. */
function morningOf(world: WorldState, day: number, minute = 420): WorldState {
  let w = world
  while (absoluteMinute(w.clock) < day * 1440 + minute) w = settle(apply(w, { type: "wait", minutes: Math.min(10080, day * 1440 + minute - absoluteMinute(w.clock)) }))
  const player = w.people[w.playerId]!
  return { ...w, people: { ...w.people, [w.playerId]: { ...player, needs: { energy: 85, stress: 20, hunger: 10, sleepPressure: 10 } } } }
}
const patchWorkplace = (world: WorldState, patch: Partial<Workplace>): WorldState =>
  ({ ...world, employment: { ...world.employment!, workplace: { ...world.employment!.workplace, ...patch } } })

describe("trabalho vivido (bíblia §15)", () => {
  it("tem conteúdo válido: situações por função, tarefas, conversa e entrevistas", () => {
    expect(validateWorkContent(jobRoles.map(r => r.id))).toEqual([])
    expect(workSituations.length).toBeGreaterThanOrEqual(28)
  })

  it("toda empresa tem alguém que responde pela equipe, e essa pessoa vira seu gestor", () => {
    const world = employed()
    for (const id of Object.keys(world.companies)) expect(world.residents[world.leaders[id]!]?.job?.companyId).toBe(id)
    const manager = world.employment!.workplace.managerId
    expect(manager).toBe(world.leaders[world.employment!.companyId])
    expect(Object.values(world.relationships).some(r => (r.a === manager || r.b === manager) && r.tags.includes("coworker"))).toBe(true)
    expect(validateWorld(world).ok).toBe(true)
  })

  it("o turno para no meio para você decidir, e nada mais anda até você responder", () => {
    let world = employed()
    world = morningOf(world, world.employment!.requiredFromDay)
    const started = apply(world, { type: "work" })
    const scene = started.work.scene!
    expect(scene.kind).toBe("shift")
    expect(absoluteMinute(started.clock) - absoluteMinute(world.clock)).toBe(workRules.momentAfterMinutes)
    expect(executeCommand(started, { type: "rest" })).toMatchObject({ ok: false, error: { code: "pending-decision" } })
    expect(validateWorld(started).ok).toBe(true)
    expect(decodeSnapshot(encodeSnapshot(started))).toEqual({ ok: true, value: started })
    const done = apply(started, { type: "work-choice", sceneId: scene.id, choiceId: safeChoice(started) })
    expect(done.work.scene).toBeNull()
    expect(done.employment!.shiftsWorked).toBe(1)
    expect(done.employment!.accruedCents).toBe(Math.round(done.employment!.workplace.salaryCents / 20))
    expect(done.timeline.some(e => e.cause.startsWith(`work.moment:${scene.situationId}`))).toBe(true)
    expect(executeCommand(done, { type: "work-choice", sceneId: scene.id, choiceId: "x" }).ok).toBe(false)
    expect(validateWorld(done).ok).toBe(true)
  })

  it("escolhas arriscadas dependem do preparo; tempo extra alonga o turno", () => {
    const base = morningOf(employed("risco"), employed("risco").employment!.requiredFromDay)
    const started = apply(base, { type: "work" })
    const situation = workSituations.find(s => s.id === started.work.scene!.situationId)!
    const long = situation.choices.find(c => c.minutes) ?? situation.choices[0]!
    const ended = apply(started, { type: "work-choice", sceneId: started.work.scene!.id, choiceId: long.id })
    expect(absoluteMinute(ended.clock) - absoluteMinute(base.clock)).toBeGreaterThanOrEqual(480 + (long.minutes ?? 0))
  })

  it("chegar depois do combinado conta atraso e pesa na confiança", () => {
    let world = employed()
    world = morningOf(world, world.employment!.requiredFromDay, 600)
    const trust = world.employment!.workplace.trust
    const worked = workShift(world)
    expect(worked.employment!.workplace.lateThisMonth).toBe(1)
    expect(worked.employment!.workplace.trust).toBeLessThanOrEqual(trust)
  })

  it("dá a tarefa da semana e cobra o prazo", () => {
    let world = employed("tarefa")
    world = workShift(morningOf(world, world.employment!.requiredFromDay))
    const a = world.employment!.workplace.assignment!
    expect(a.needed).toBeGreaterThan(0)
    expect(world.timeline.some(e => e.cause.startsWith("work.assignment:"))).toBe(true)
    // tarefa grande demais para o prazo: sem entregar, o prazo passa e a cobrança vem
    const due = nextDay(world)
    world = patchWorkplace(world, { assignment: { ...a, needed: 10, dueDay: due } })
    const late = morningOf(world, nextDayAfter(due), 900)
    expect(late.employment).not.toBeNull()
    expect(late.employment?.workplace.missed ?? 0).toBeGreaterThanOrEqual(1)
    expect(late.timeline.some(e => e.cause.startsWith("work.assignment-missed:"))).toBe(true)
  })

  it("conversa do mês: advertência, depois demissão por desempenho com sinal claro", () => {
    let world = employed("avaliacao")
    const day = world.employment!.requiredFromDay
    world = patchWorkplace(morningOf(world, day), { nextReviewDay: day, lateThisMonth: 5 })
    world = apply(world, { type: "work" })
    world = settle(world)
    expect(world.employment!.workplace.warnings).toBe(1)
    expect(world.timeline.some(e => e.cause.startsWith("work.review:") && e.text.includes("advertência"))).toBe(true)
    const next = nextDay(world)
    world = patchWorkplace(morningOf(world, next), { nextReviewDay: next, lateThisMonth: 5 })
    world = settle(apply(world, { type: "work" }))
    expect(world.employment).toBeNull()
    expect(world.employmentHistory.at(-1)?.reason).toBe("performance")
    expect(queryCareer(world).history[0]?.reason).toContain("conversas difíceis")
    expect(validateWorld(world).ok).toBe(true)
  })

  it("pedir aumento funciona quando o mês foi bom e a confiança é alta", () => {
    let world = employed("aumento")
    const day = world.employment!.requiredFromDay
    world = { ...world, employment: { ...world.employment!, startedAt: { day: day - 70, minute: 480 }, performance: 90 } }
    world = patchWorkplace(morningOf(world, day), { nextReviewDay: day, trust: 90, prepared: true })
    const salary = world.employment!.workplace.salaryCents
    const raised = settle(apply(world, { type: "work" }), w => (w.work.scene?.kind === "review" ? "raise" : safeChoice(w)))
    expect(raised.employment!.workplace.salaryCents).toBeGreaterThan(salary)
    expect(raised.employment!.workplace.nextReviewDay).toBeGreaterThan(day)
  })

  it("promoção: pedir responsabilidade abre processo interno, entrevista e troca de função", () => {
    let world = employed("promocao", "stock")
    const day = world.employment!.requiredFromDay
    const skills = world.skills[world.playerId]!
    world = { ...world, skills: { ...world.skills, [world.playerId]: { ...skills, organization: .6 } },
      employment: { ...world.employment!, startedAt: { day: day - 90, minute: 480 }, performance: 85 } }
    world = patchWorkplace(morningOf(world, day), { nextReviewDay: day, trust: 80 })
    world = settle(apply(world, { type: "work" }), w => (w.work.scene?.kind === "review" ? "responsibility" : safeChoice(w)))
    expect(world.employment!.workplace.promotion?.roleId).toBe("inventory")
    expect(queryCareer(world).promotion?.canApply).toBe(true)
    world = apply(world, { type: "apply-internal" })
    const interview = world.work.interviews.at(-1)!
    expect(interview.internal).toBe(true)
    world = apply(world, { type: "prepare", target: "interview", interviewId: interview.id })
    // espera até a entrevista e responde
    for (let i = 0; i < 10 && world.work.interviews.find(x => x.id === interview.id)!.status !== "passed" && world.work.interviews.find(x => x.id === interview.id)!.status !== "failed"; i++)
      world = settle(apply(world, { type: "wait", minutes: 720 }))
    const result = world.work.interviews.find(x => x.id === interview.id)!
    expect(["passed", "failed"]).toContain(result.status)
    if (result.status === "passed") {
      expect(world.employment!.roleId).toBe("inventory")
      expect(Object.values(world.vacancies).some(v => v.open && v.roleId === "stock" && v.companyId === world.employment!.companyId)).toBe(true)
    } else expect(world.employment!.workplace.promotion).toBeNull()
    expect(validateWorld(world).ok).toBe(true)
  })

  it("candidatura marca entrevista; o compromisso bloqueia o que o atravessaria", () => {
    let world = quiet("entrevista")
    const vacancy = queryCareer(world).vacancies.find(v => v.canApply)!
    world = apply(world, { type: "apply-job", vacancyId: vacancy.id })
    expect(world.employment).toBeNull()
    const interview = world.work.interviews[0]!
    expect(interview.status).toBe("scheduled")
    expect(queryCareer(world).vacancies.find(v => v.id === vacancy.id)?.reason).toContain("entrevista já está marcada")
    // dormir oito horas por cima da entrevista não é permitido
    const nearby = { ...world, clock: { day: interview.at.day, minute: interview.at.minute - 120 } }
    expect(executeCommand(nearby, { type: "sleep" })).toMatchObject({ ok: false })
    world = apply(world, { type: "prepare", target: "interview", interviewId: interview.id as InterviewId })
    expect(world.work.interviews[0]!.prepared).toBe(true)
    // a espera para na hora marcada
    while (!world.work.scene) world = apply(world, { type: "wait", minutes: 10080 })
    expect(world.clock).toEqual(interview.at)
    expect(world.work.scene.kind).toBe("interview")
    world = apply(world, { type: "work-choice", sceneId: world.work.scene.id, choiceId: safeChoice(world) })
    expect(world.work.interviews[0]!.status).toBe("awaiting")
    expect(world.vacancies[vacancy.id]!.open).toBe(true)
    world = settle(apply(world, { type: "wait", minutes: 2880 }))
    const status = world.work.interviews[0]!.status
    expect(["passed", "failed"]).toContain(status)
    if (status === "passed") expect(world.employment?.companyId).toBe(world.vacancies[vacancy.id]!.companyId)
    expect(validateWorld(world).ok).toBe(true)
  })

  it("quem chega pelas entrevistas começa com gestor, colegas e agenda", () => {
    const world = hireViaInterviews(quiet("contratacao"))
    expect(world.employment!.workplace.managerId).toBe(world.leaders[world.employment!.companyId])
    expect(world.scheduled.filter(s => s.employmentId === world.employment!.id)).toHaveLength(2)
    expect(world.work.interviews.every(i => i.status !== "scheduled")).toBe(true)
    expect(validateWorld(world).ok).toBe(true)
  })

  it("é determinístico com cenas no meio", () => {
    const run = () => { let w = employed("det"); for (let i = 0; i < 6; i++) w = workShift(morningOf(w, nextDay(w))); return w }
    expect(worldHash(run())).toBe(worldHash(run()))
  })

  it("rejeita local de trabalho adulterado", () => {
    const world = employed()
    expect(validateWorld(patchWorkplace(world, { trust: 140 })).ok).toBe(false)
    expect(validateWorld(patchWorkplace(world, { recentSituations: ["inventada"] })).ok).toBe(false)
    expect(validateWorld({ ...world, work: { ...world.work, interviews: [{ id: "interview:1" as InterviewId, vacancyId: null, companyId: world.employment!.companyId, roleId: "stock", internal: false, at: world.clock, prepared: false, status: "scheduled", score: null }] } }).ok).toBe(false)
  })
})

function nextDay(world: WorldState): number {
  let d = world.clock.day + 1
  while (d % 7 >= 5) d++
  return d
}

function nextDayAfter(day: number): number {
  let d = day + 1
  while (d % 7 >= 5) d++
  return d
}
