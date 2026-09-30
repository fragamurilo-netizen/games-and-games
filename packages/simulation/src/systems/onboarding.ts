// Começo da campanha (bíblia §47, §48): identidade básica e ponto de partida escolhidos pelo
// jogador; o resto vem da seed. Aplicado sobre o mundo recém-criado, antes do primeiro save.
import { jobRoles, starterContent } from "@paralelo/content"
import { err, ok, type EmploymentId, type Result, type VacancyId } from "@paralelo/shared"
import type { WorldState } from "../domain/world"
import { calendarDate, dayFromCalendar, formatDate } from "../time"
import { appendEntry } from "../timeline"
import { nextWeekday, scheduleWorkDay } from "./career"
import { meetCoworkers } from "./city"

export type StartingPoint = "job-search" | "simple-job"
export type StartProfile = Readonly<{ firstName: string; sex: "F" | "M"; age: number; start: StartingPoint }>
export const startingPoints: readonly Readonly<{ id: StartingPoint; title: string; text: string }>[] = [
  { id: "job-search", title: "Procurando trabalho", text: "Você chegou com as economias da mudança e ainda sem emprego. O primeiro mês depende de achar uma vaga." },
  { id: "simple-job", title: "Com um emprego simples", text: "Uma empresa do bairro já fechou contrato para uma função de entrada. O salário é curto, mas chega todo mês." },
]
export const startAges = { min: 18, max: 30 } as const

export function validateProfile(profile: StartProfile): Result<StartProfile, string> {
  const firstName = profile.firstName.trim().replace(/\s+/g, " ")
  if (firstName.length < 2 || firstName.length > 24) return err("O nome precisa ter entre 2 e 24 letras.")
  if (!/^[\p{L}][\p{L}' -]*$/u.test(firstName)) return err("Use só letras no nome.")
  if (profile.sex !== "F" && profile.sex !== "M") return err("Escolha como o corpo do personagem será desenhado.")
  if (!Number.isInteger(profile.age) || profile.age < startAges.min || profile.age > startAges.max) return err(`A idade inicial vai de ${startAges.min} a ${startAges.max} anos.`)
  if (!startingPoints.some(point => point.id === profile.start)) return err("Escolha um ponto de partida.")
  return ok({ ...profile, firstName })
}

export function beginLife(world: WorldState, input: StartProfile): Result<WorldState, string> {
  const valid = validateProfile(input)
  if (!valid.ok) return valid
  const profile = valid.value
  const player = world.people[world.playerId]!
  // mesmo sobrenome da mãe: a família já existe no mundo gerado
  const surname = starterContent.motherName.split(" ").at(-1)!
  const today = calendarDate(world.clock.day), born = calendarDate(player.birthDate.day)
  const year = today.year - profile.age - (born.month > today.month || (born.month === today.month && born.day > today.day) ? 1 : 0)
  let next: WorldState = { ...world, people: { ...world.people, [player.id]: { ...player, name: `${profile.firstName} ${surname}`, sex: profile.sex,
    birthDate: { day: dayFromCalendar(year, born.month, Math.min(born.day, 28)), minute: 0 } } } }
  if (profile.start === "simple-job") next = hireAtStart(next)
  return ok(next)
}

function hireAtStart(world: WorldState): WorldState {
  const entry = jobRoles.filter(role => role.required <= 0.15)
  const vacancy = Object.values(world.vacancies).filter(v => v.open && entry.some(role => role.id === v.roleId)).sort((a, b) => (a.id < b.id ? -1 : 1))[0]
  const companyId = vacancy?.companyId ?? (Object.keys(world.companies).sort()[0]! as keyof WorldState["companies"])
  const company = world.companies[companyId]!
  const role = jobRoles.find(r => r.id === vacancy?.roleId) ?? entry[0]!
  const id = `employment:${world.nextId}` as EmploymentId
  let next: WorldState = { ...world, nextId: world.nextId + 1,
    employment: { id, personId: world.playerId, companyId: company.id, roleId: role.id, startedAt: world.clock, lastWorkedDay: null, accruedCents: 0, shiftsWorked: 0, performance: 60,
      requiredFromDay: nextWeekday(world.clock.day + 1), consecutiveAbsences: 0, lastAssessedDay: null },
    vacancies: vacancy ? { ...world.vacancies, [vacancy.id as VacancyId]: { ...vacancy, open: false } } : world.vacancies }
  next = meetCoworkers(scheduleWorkDay(next, next.employment!.requiredFromDay), company.id)
  return appendEntry(next, { at: world.clock, kind: "career", text: `O contrato com ${company.name} foi fechado antes da mudança: ${role.title.toLowerCase()}, oito horas por dia útil. O primeiro turno é em ${formatDate({ day: next.employment!.requiredFromDay, minute: 0 })}.`,
    personIds: [world.playerId], cause: `career.start:${id}` })
}
