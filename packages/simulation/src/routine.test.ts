import { describe, expect, it } from "vitest"
import { lifeEvents } from "@paralelo/content"
import { decodeSnapshot, encodeSnapshot } from "@paralelo/persistence"
import type { VacancyId } from "@paralelo/shared"
import { absoluteMinute, createWorld, executeCommand, nextWeekday, hirePlayer, queryCareer, queryDecision, queryLife, queryRoutine, validateWorld, worldHash, type Command, type WorldState } from "."
import { applyElapsed } from "./systems/needs"
import { hireViaInterviews, settle, workShift } from "./test-support"

function apply(world: WorldState, command: Command): WorldState {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
function quiet(seed = "routine"): WorldState {
  const world = createWorld(seed)
  return { ...world, events: { ...world.events, seen: lifeEvents.map(item => item.id) } }
}
function until(world: WorldState, day: number, minute: number): WorldState {
  const target = day * 1440 + minute
  while (absoluteMinute(world.clock) < target) world = apply(world, { type: "wait", minutes: Math.min(10080, target - absoluteMinute(world.clock)) })
  return world
}
// Presença e faltas: contrato fechado no dia 0 (como no começo "com emprego simples").
function hired(): WorldState {
  const world = quiet("attendance")
  const vacancy = Object.values(world.vacancies).find(v => v.open && v.roleId === "stock") ?? Object.values(world.vacancies).find(v => v.open)!
  return hirePlayer(world, vacancy.companyId, vacancy.roleId, vacancy.id, false)
}
const needs = (world: WorldState) => world.people[world.playerId]!.needs

describe("rotina física e alimentação", () => {
  it("distingue descansar de dormir e integra intervalos sem saltos nos limiares", () => {
    const base = quiet(), start = { ...base, people: { ...base.people, [base.playerId]: { ...base.people[base.playerId]!, needs: { energy: 75, stress: 30, hunger: 60, sleepPressure: 70 } } } }
    const rested = applyElapsed(start, 240, "rest"), slept = applyElapsed(start, 240, "sleep")
    expect(needs(rested).sleepPressure).toBeGreaterThan(needs(start).sleepPressure)
    expect(needs(slept).sleepPressure).toBeLessThan(needs(start).sleepPressure)
    expect(needs(slept).hunger).toBeLessThan(needs(rested).hunger)
    for (const activity of ["awake", "rest", "sleep"] as const) {
      const whole = needs(applyElapsed(start, 480, activity))
      const split = needs(applyElapsed(applyElapsed(start, 173, activity), 307, activity))
      for (const key of ["energy", "stress", "hunger", "sleepPressure"] as const) expect(split[key]).toBeCloseTo(whole[key], 9)
    }
    expect(needs(start)).toEqual({ energy: 75, stress: 30, hunger: 60, sleepPressure: 70 })
  })
  it("compra ingredientes com ledger, consome porção e recusa estoque excessivo", () => {
    const start = quiet(), groceries = apply(start, { type: "buy-groceries" })
    expect(groceries.routine.pantryMeals).toBe(10)
    expect(groceries.finance.balanceCents).toBe(start.finance.balanceCents - 4800)
    expect(absoluteMinute(groceries.clock) - absoluteMinute(start.clock)).toBe(60)
    const ate = apply(groceries, { type: "meal", source: "home" })
    expect(ate.routine.pantryMeals).toBe(9)
    expect(needs(ate).hunger).toBe(0)
    expect(ate.finance.balanceCents).toBe(groceries.finance.balanceCents)
    expect(executeCommand(ate, { type: "meal", source: "home" }).ok).toBe(false)
    const full = { ...ate, routine: { ...ate.routine, pantryMeals: 30 } }, hash = worldHash(full)
    expect(executeCommand(full, { type: "buy-groceries" }).ok).toBe(false)
    expect(worldHash(full)).toBe(hash)
    expect(validateWorld(ate).ok).toBe(true)
  })
  it("mantém refeição gratuita acessível sem dinheiro, com horário e limite diário", () => {
    const base = until(quiet(), 0, 660)
    const poor = { ...base, finance: { ...base.finance, balanceCents: 0, openingBalanceCents: 0 }, routine: { ...base.routine, pantryMeals: 0 } }
    expect(executeCommand(poor, { type: "meal" }).ok).toBe(false)
    expect(executeCommand(poor, { type: "meal", source: "home" }).ok).toBe(false)
    const ate = apply(poor, { type: "meal", source: "community" })
    expect(needs(ate).hunger).toBe(0)
    expect(ate.finance.balanceCents).toBe(0)
    expect(ate.routine.lastCommunityMealDay).toBe(0)
    expect(executeCommand(ate, { type: "meal", source: "community" }).ok).toBe(false)
    const tomorrow = until(ate, 1, 660)
    expect(executeCommand(tomorrow, { type: "meal", source: "community" }).ok).toBe(true)
    expect(queryRoutine(ate).communityWait).toBe(23 * 60)
    expect(validateWorld(ate).ok).toBe(true)
  })
  it("recusa necessidades/estoque corrompidos e roundtrip conserva a rotina", () => {
    const world = apply(quiet(), { type: "meal", source: "home" })
    expect(decodeSnapshot(encodeSnapshot(world))).toEqual({ ok: true, value: world })
    expect(validateWorld({ ...world, routine: { ...world.routine, pantryMeals: -1 } }).ok).toBe(false)
    expect(validateWorld({ ...world, people: { ...world.people, [world.playerId]: { ...world.people[world.playerId], needs: { ...needs(world), hunger: NaN } } } }).ok).toBe(false)
  })
})

describe("agenda e consequências profissionais", () => {
  it("mostra compromisso real, pausa no lembrete e não revela agenda interna dos NPCs", () => {
    const world = hired(), first = world.employment!.requiredFromDay
    const waiting = until(world, first, 479)
    const paused = apply(waiting, { type: "wait", minutes: 240 })
    expect(paused.clock).toEqual({ day: first, minute: 480 })
    expect(paused.timeline.at(-1)?.cause).toContain("career.reminder:")
    expect(queryLife(paused).agenda.map(item => item.label).some(label => label.includes("Expediente"))).toBe(true)
    expect(queryLife(paused).agenda.some(item => item.id.includes("social") || item.id.includes("daily-events"))).toBe(false)
    expect(validateWorld(paused).ok).toBe(true)
  })
  it("iniciar às 14h conta presença mesmo com cobrança durante as oito horas", () => {
    let world = hired(), day = world.employment!.requiredFromDay
    world = until(world, day, 360)
    world = apply(world, { type: "sleep" }) // 06h -> 14h, energia suficiente.
    const worked = workShift(world)
    expect(worked.clock).toEqual({ day, minute: 1320 })
    expect(worked.employment?.lastAssessedDay).toBe(day)
    expect(worked.employment?.consecutiveAbsences).toBe(0)
    expect(worked.employment?.shiftsWorked).toBe(1)
    expect(worked.timeline.some(item => item.cause.startsWith("career.absence:"))).toBe(false)
    expect(validateWorld(worked).ok).toBe(true)
  })
  it("emite avisos, interrompe sequência ao comparecer e ignora fins de semana", () => {
    let world = hired(), day = world.employment!.requiredFromDay
    world = until(world, day, 841)
    expect(world.employment?.consecutiveAbsences).toBe(1)
    day = nextWeekday(day + 1)
    world = until(world, day, 841)
    expect(world.employment?.consecutiveAbsences).toBe(2)
    expect(queryCareer(world).employment?.presence).toContain("Outra falta")
    day = nextWeekday(day + 1)
    world = until(world, day, 0)
    world = apply(world, { type: "sleep" })
    world = workShift(world)
    expect(world.employment?.consecutiveAbsences).toBe(0)
    expect(nextWeekday(5)).toBe(7)
    expect(world.scheduled.filter(item => item.kind.startsWith("work-")).every(item => item.at.day % 7 < 5)).toBe(true)
    world = until(world, 4, 841) // Sexta: uma falta após a presença de quinta.
    expect(world.employment?.consecutiveAbsences).toBe(1)
    world = until(world, 6, 720) // Domingo não cria outra falta.
    expect(world.employment?.consecutiveAbsences).toBe(1)
    expect(validateWorld(world).ok).toBe(true)
  })
  it("não interrompe skip por uma conferência de presença já cumprida", () => {
    let world = hired()
    const first = world.employment!.requiredFromDay
    world = until(world, first - 1, 1320)
    world = apply(world, { type: "sleep" })
    world = workShift(world) // 06h -> 14h.
    const followed = apply(world, { type: "wait", minutes: 30 })
    expect(followed.clock).toEqual({ day: first, minute: 870 })
    expect(followed.employment?.consecutiveAbsences).toBe(0)
    expect(followed.timeline).toEqual(world.timeline)
  })
  it("demite após três faltas, paga saldo devido uma vez, reabre vaga e permite buscar outra", () => {
    const worked = workShift(hired()), employment = worked.employment!
    let dismissed = worked
    for (let i = 0; i < 3; i++) dismissed = until(dismissed, nextWeekday(employment.requiredFromDay + i), 841)
    expect(dismissed.employment).toBeNull()
    expect(dismissed.employmentHistory).toHaveLength(1)
    expect(dismissed.finance.balanceCents).toBe(worked.finance.balanceCents + employment.accruedCents)
    const reopened = Object.values(dismissed.vacancies).find(v => v.companyId === employment.companyId && v.roleId === employment.roleId)!
    expect(reopened.open).toBe(true)
    expect(dismissed.scheduled.some(item => item.employmentId === employment.id)).toBe(false)
    expect(executeCommand(dismissed, { type: "apply-job", vacancyId: reopened.id }).ok).toBe(false)
    // outra empresa continua aberta a você (o mercado pode estar sem vaga agora; criamos uma)
    const other = Object.values(dismissed.companies).find(c => c.id !== employment.companyId)!
    const opening = { id: "vacancy:teste" as VacancyId, companyId: other.id, roleId: "stock", open: true }
    expect(queryCareer({ ...dismissed, vacancies: { ...dismissed.vacancies, [opening.id]: opening } }).vacancies.find(v => v.id === opening.id)?.canApply).toBe(true)
    const paid = until(dismissed, 30, 480)
    expect(paid.finance.ledger.filter(item => item.category === "salary")).toHaveLength(1)
    expect(validateWorld(paid).ok).toBe(true)
    expect(decodeSnapshot(encodeSnapshot(paid))).toEqual({ ok: true, value: paid })
  })
  it("recusa agenda quebrada e acerto adulterado", () => {
    const world = hired()
    expect(validateWorld({ ...world, scheduled: world.scheduled.filter(item => item.kind !== "work-attendance") }).ok).toBe(false)
    expect(validateWorld({ ...world, employment: null }).ok).toBe(false)
    const dismissed = until(world, world.employment!.requiredFromDay + 2, 841)
    expect(dismissed.employmentHistory).toHaveLength(1)
    expect(validateWorld({ ...dismissed, employmentHistory: [{ ...dismissed.employmentHistory[0], settledCents: 1 }] }).ok).toBe(false)
  })
  it("sustenta três meses de trabalho, alimentação, sono, decisões e save", () => {
    let world = hireViaInterviews(createWorld("working-life"))
    expect(world.employment).not.toBeNull()
    for (let steps = 0; world.clock.day < 90 && steps < 2000; steps++) {
      // uma pessoa pontual: dorme cedo, chega no horário combinado, come entre uma coisa e outra
      const canWork = queryCareer(world).canWork
      if (queryDecision(world) || world.work.scene) world = settle(world)
      else if (canWork && world.clock.minute <= 480 && needs(world).hunger < 75) world = workShift(world)
      else if (needs(world).hunger >= 45) world = apply(world, world.routine.pantryMeals ? { type: "meal", source: "home" } : { type: "buy-groceries" })
      else if (world.clock.minute >= 1320 || world.clock.minute < 300 || needs(world).energy < 25) world = apply(world, { type: "sleep" })
      else if (canWork) world = workShift(world)
      else world = apply(world, { type: "wait", minutes: 60 })
      expect(validateWorld(world)).toMatchObject({ ok: true })
      if (steps % 100 === 0) {
        const loaded = decodeSnapshot(encodeSnapshot(world))
        expect(loaded).toEqual({ ok: true, value: world })
        if (loaded.ok) world = loaded.value
      }
    }
    expect(world.clock.day).toBeGreaterThanOrEqual(90)
    expect(world.employment).not.toBeNull()
    expect(world.employmentHistory).toHaveLength(0)
    expect(world.finance.ledger.filter(item => item.category === "salary")).toHaveLength(3)
    expect(world.finance.balanceCents).toBeGreaterThan(0)
  })
})
