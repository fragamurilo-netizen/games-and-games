import { inPlace, jobRoles, routineRules } from "@paralelo/content"
import type { EmploymentId, ScheduleId, VacancyId } from "@paralelo/shared"
import type { Employment, ScheduledEvent, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, formatDate } from "../time"
import { appendEntry } from "../timeline"
import { formatMoney, postLedger } from "./finance"
import { changeNeeds } from "./needs"
import { interviewReason, scheduleInterview, workDailyCheck } from "./work"

export function nextWeekday(day: number): number {
  while (day % 7 >= 5) day++
  return day
}
export function scheduleWorkDay<W extends Readonly<{ employment: Employment | null; playerId: WorldState["playerId"]; scheduled: WorldState["scheduled"] }>>(world: W, day: number): W {
  const employment = world.employment!
  const make = (kind: "work-reminder" | "work-attendance", minute: number): ScheduledEvent => ({ id: `schedule:${employment.id}:${kind}` as ScheduleId, kind, at: { day, minute }, personId: world.playerId, employmentId: employment.id, interrupts: true })
  return { ...world, scheduled: [...world.scheduled, make("work-reminder", routineRules.work.reminderMinute), make("work-attendance", routineRules.work.lastStartMinute + 1)] }
}

export function applicationReason(world: WorldState, vacancyId: VacancyId): string | null {
  const vacancy = world.vacancies[vacancyId], role = jobRoles.find(item => item.id === vacancy?.roleId)
  if (!vacancy?.open || !role) return "Esta vaga não está mais disponível."
  if (world.employment) return "Você já tem um contrato de trabalho ativo."
  const dismissed = [...world.employmentHistory].reverse().find(item => item.companyId === vacancy.companyId)
  if (dismissed && world.clock.day - dismissed.endedAt.day < routineRules.work.reapplyDays) return "Depois da saída, esta empresa só recebe outra candidatura sua após sete dias."
  if (world.skills[world.playerId]![role.skill] < role.required) return "Ainda falta preparo para esta função. Um curso pode ajudar."
  const interview = interviewReason(world, vacancyId)
  if (interview) return interview
  const last = [...world.applications].reverse().find(item => item.vacancyId === vacancyId)
  if (last && absoluteMinute(world.clock) - absoluteMinute(last.at) < 2880) return "A empresa já recebeu seu currículo. Aguarde dois dias antes de tentar de novo."
  return null
}
/** Enviar currículo marca uma entrevista; a resposta depende dela (bíblia §15.3). */
export function applyForJob(world: WorldState, vacancyId: VacancyId): WorldState {
  const vacancy = world.vacancies[vacancyId]!
  return scheduleInterview(world, vacancy.companyId, vacancy.roleId, vacancyId, false)
}
export function workReason(world: WorldState): string | null {
  if (!world.employment) return "Você ainda não tem um emprego."
  if (world.employment.lastWorkedDay === world.clock.day) return "Você já cumpriu o turno de hoje."
  if (world.clock.day % 7 >= 5) return "Hoje não é dia de expediente. Seu trabalho é de segunda a sexta."
  if (world.clock.minute < routineRules.work.startMinute || world.clock.minute > routineRules.work.lastStartMinute) return "O turno deve começar entre 6h e 14h."
  if (world.people[world.playerId]!.needs.energy < 20) return "Você precisa descansar antes de cumprir oito horas de trabalho."
  return null
}
export function nextWorkTime(world: WorldState) {
  let day = world.clock.day
  if (world.clock.minute > routineRules.work.lastStartMinute || world.employment?.lastWorkedDay === day) day++
  day = nextWeekday(day)
  return { day, minute: day === world.clock.day && world.clock.minute >= routineRules.work.startMinute ? world.clock.minute : routineRules.work.reminderMinute }
}

export function processWorkEvent(world: WorldState, event: ScheduledEvent): WorldState {
  const employment = world.employment
  if (!employment || employment.id !== event.employmentId) return world
  const company = world.companies[employment.companyId]!
  if (event.kind === "work-reminder") return employment.lastWorkedDay === world.clock.day ? world
    : appendEntry(world, { at: world.clock, kind: "career", text: `Hoje tem expediente ${inPlace(company.name)}. O combinado é chegar até as 8h30; depois das 14h, conta como falta.`, personIds: [world.playerId], cause: `career.reminder:${employment.id}` })
  if (employment.lastAssessedDay === world.clock.day) return world
  const absences = employment.lastWorkedDay === world.clock.day ? 0 : employment.consecutiveAbsences + 1
  let next: WorldState = { ...world, employment: { ...employment, lastAssessedDay: world.clock.day, consecutiveAbsences: absences, performance: Math.max(0, employment.performance - (absences ? 12 : 0)) } }
  next = workDailyCheck(next, absences > 0)
  if (!next.employment) return next
  if (absences >= routineRules.work.dismissalAbsences) {
    if (employment.accruedCents > 0) next = postLedger(next, { amountCents: employment.accruedCents, category: "salary", text: `Acerto dos turnos · ${company.name}`, cause: `career.settlement:${employment.id}` })
    next = { ...next, employment: null,
      employmentHistory: [...next.employmentHistory, { id: employment.id, companyId: employment.companyId, roleId: employment.roleId, startedAt: employment.startedAt, endedAt: world.clock, reason: "absence", settledCents: employment.accruedCents }],
      vacancies: Object.fromEntries(Object.entries(next.vacancies).map(([id, vacancy]) => [id, vacancy.companyId === employment.companyId && vacancy.roleId === employment.roleId ? { ...vacancy, open: true } : vacancy])),
      scheduled: next.scheduled.filter(item => item.employmentId !== employment.id) }
    next = changeNeeds(next, { stress: 15 })
    return appendEntry(next, { at: next.clock, kind: "career", text: `${company.name} encerrou seu contrato após três faltas seguidas, depois dos avisos anteriores.${employment.accruedCents > 0 ? ` Os turnos já cumpridos foram pagos: ${formatMoney(employment.accruedCents)}.` : " Não havia turnos aguardando pagamento."} Você pode procurar outra vaga.`, personIds: [world.playerId], cause: `career.dismissed:${employment.id}` })
  }
  if (absences) next = appendEntry(changeNeeds(next, { stress: absences === 2 ? 8 : 4 }), { at: world.clock, kind: "career",
    text: absences === 1 ? `Você não compareceu ao turno ${inPlace(company.name)}. O dia não será pago. A empresa pediu que você retome o expediente amanhã, se for dia útil.`
      : `${company.name} registrou a segunda falta seguida e enviou uma advertência. Se faltar ao próximo turno, o contrato será encerrado.`, personIds: [world.playerId], cause: `career.absence:${employment.id}:${world.clock.day}` })
  return scheduleWorkDay(next, nextWeekday(world.clock.day + 1))
}
