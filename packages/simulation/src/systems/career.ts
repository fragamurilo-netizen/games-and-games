import { jobRoles } from "@paralelo/content"
import type { EmploymentId, VacancyId } from "@paralelo/shared"
import type { WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, addMinutes } from "../time"
import { appendEntry } from "../timeline"

export function applicationReason(world: WorldState, vacancyId: VacancyId): string | null {
  const vacancy = world.vacancies[vacancyId], role = jobRoles.find(item => item.id === vacancy?.roleId)
  if (!vacancy?.open || !role) return "Esta vaga não está mais disponível."
  if (world.employment) return "Você já tem um emprego. Mudança de emprego será uma próxima etapa."
  if (world.skills[world.playerId]![role.skill] < role.required) return "Ainda falta preparo para esta função. Um curso pode ajudar."
  const last = [...world.applications].reverse().find(item => item.vacancyId === vacancyId)
  if (last && absoluteMinute(world.clock) - absoluteMinute(last.at) < 2880) return "A empresa já recebeu seu currículo. Aguarde dois dias antes de tentar de novo."
  return null
}
export function applyForJob(world: WorldState, vacancyId: VacancyId): WorldState {
  const vacancy = world.vacancies[vacancyId]!, role = jobRoles.find(item => item.id === vacancy.roleId)!
  const roll = draw(world.seed, world.rng, "career")
  const accepted = roll.value < .55 + world.skills[world.playerId]![role.skill] * .35
  let next: WorldState = { ...world, rng: roll.state, applications: [...world.applications, { vacancyId, at: world.clock, accepted }] }
  const company = world.companies[vacancy.companyId]!
  if (accepted) {
    const id = `employment:${world.nextId}` as EmploymentId
    next = { ...next, nextId: next.nextId + 1, employment: { id, personId: world.playerId, companyId: company.id, roleId: role.id, startedAt: world.clock, lastWorkedDay: null, accruedCents: 0, shiftsWorked: 0, performance: 60 }, vacancies: { ...next.vacancies, [vacancyId]: { ...vacancy, open: false } } }
  }
  return appendEntry(next, { at: world.clock, kind: "career", text: accepted
    ? `${company.name} aceitou seu currículo para ${role.title.toLowerCase()}. O primeiro turno pode começar num dia útil, entre 6h e 14h.`
    : `${company.name} respondeu que não vai seguir com seu currículo desta vez. A vaga continua aberta para outra tentativa.`, personIds: [world.playerId], cause: `career.application:${vacancyId}` })
}
export function workReason(world: WorldState): string | null {
  if (!world.employment) return "Você ainda não tem um emprego."
  if (world.employment.lastWorkedDay === world.clock.day) return "Você já cumpriu o turno de hoje."
  if (world.clock.day % 7 >= 5) return "Hoje não é dia de expediente. Seu trabalho é de segunda a sexta."
  if (world.clock.minute < 360 || world.clock.minute > 840) return "O turno deve começar entre 6h e 14h."
  if (world.people[world.playerId]!.needs.energy < 20) return "Você precisa descansar antes de cumprir oito horas de trabalho."
  return null
}
export function completeShift(world: WorldState, startedDay: number): WorldState {
  const employment = world.employment!, role = jobRoles.find(item => item.id === employment.roleId)!
  const skill = world.skills[world.playerId]![role.skill]
  const performance = Math.max(0, Math.min(100, employment.performance + skill * 4 - (world.people[world.playerId]!.needs.energy < 20 ? 5 : 1)))
  return appendEntry({ ...world, employment: { ...employment, lastWorkedDay: startedDay, accruedCents: employment.accruedCents + Math.round(role.salaryCents / 20), shiftsWorked: employment.shiftsWorked + 1, performance } },
    { at: world.clock, kind: "career", text: `Você terminou o turno em ${world.companies[employment.companyId]!.name}. O pagamento dessas oito horas ficou registrado para o início do próximo mês.`, personIds: [world.playerId], cause: `career.shift:${employment.id}` })
}
export function nextWorkTime(world: WorldState) {
  let day = world.clock.day
  if (world.clock.minute >= 840 || world.employment?.lastWorkedDay === day) day++
  while (day % 7 >= 5) day++
  return addMinutes({ day, minute: 480 }, 0)
}
