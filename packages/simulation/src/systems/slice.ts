import { cityNames, companies as companyNames, jobRoles, courses, validateStarterContent, starterContent } from "@paralelo/content"
import type { CompanyId, CourseId, HouseholdId, PersonId, ResidenceId, ScheduleId, VacancyId } from "@paralelo/shared"
import type { Company, Person, Skills, Vacancy, WorldStateV2, WorldStateV1 } from "../domain/world"
import { hashText } from "../rng"
import { calendarDate, dayFromCalendar } from "../time"

// Migração aditiva v1 -> v2 e criação da cidade usam uma namespace própria;
// não consomem os cursores de RNG que a campanha antiga já salvou.
export function upgradeWorldV1(base: WorldStateV1): WorldStateV2 {
  const invalid = validateStarterContent()
  if (invalid.length) throw new Error(invalid.join(" "))
  const value = (key: string) => hashText(`${base.seed}/slice-v2/${key}`) / 4294967296
  const people: Record<string, Person> = { ...base.people }
  const households = { ...base.households }, residences = { ...base.residences }
  for (let i = 0; i < 96; i++) {
    const id = `person:city-${i + 1}` as PersonId
    const householdId = `household:city-${i + 1}` as HouseholdId, residenceId = `residence:city-${i + 1}` as ResidenceId
    const name = `${cityNames.first[Math.floor(value(`${id}/name`) * cityNames.first.length)]} ${cityNames.last[Math.floor(value(`${id}/surname`) * cityNames.last.length)]}`
    people[id] = { id, name, birthDate: { day: dayFromCalendar(1960 + Math.floor(value(`${id}/year`) * 44), 1 + Math.floor(value(`${id}/month`) * 12), 1 + Math.floor(value(`${id}/day`) * 28)), minute: 0 },
      householdId, residenceId, appearanceSeed: `${base.seed}/${id}`, personality: { sociability: value(`${id}/social`), discipline: value(`${id}/discipline`), sensitivity: value(`${id}/sensitivity`) },
      needs: { energy: 75, stress: 20 }, relationshipIds: [] }
    households[householdId] = { id: householdId, memberIds: [id] }
    residences[residenceId] = { id: residenceId, district: i % 2 ? "Centro" : starterContent.district }
  }
  const skills: Record<string, Skills> = {}, tiers: Record<string, WorldStateV2["tiers"][string]> = {}
  for (const person of Object.values(people)) {
    skills[person.id] = { organization: .15 + value(`${person.id}/organization`) * .3, communication: .15 + value(`${person.id}/communication`) * .3 }
    tiers[person.id] = person.id === base.playerId ? "player" : person.relationshipIds.length ? "close" : "background"
  }
  const companies: Record<string, Company> = {}, vacancies: Record<string, Vacancy> = {}
  companyNames.forEach((name, i) => {
    const id = `company:${i + 1}` as CompanyId
    companies[id] = { id, name, district: i % 2 ? "Centro" : starterContent.district }
  })
  jobRoles.forEach((role, i) => {
    const id = `vacancy:${role.id}` as VacancyId
    vacancies[id] = { id, companyId: `company:${(i % companyNames.length) + 1}` as CompanyId, roleId: role.id, open: true }
  })
  const now = calendarDate(base.clock.day)
  const nextMonth = now.month === 12 ? dayFromCalendar(now.year + 1, 1, 1) : dayFromCalendar(now.year, now.month + 1, 1)
  const training: Record<string, WorldStateV2["training"][string]> = {}
  for (const course of courses) training[`course:${course.id}` as CourseId] = { sessions: 0, lastStudiedDay: null }
  return { ...base, schemaVersion: 2, people, households, residences, skills, tiers, companies, vacancies, employment: null,
    applications: [], finance: { openingBalanceCents: 80000, balanceCents: 80000, monthlyRentCents: 75000, ledger: [] }, training, memories: [],
    scheduled: [...base.scheduled,
      { id: "schedule:daily-social" as ScheduleId, kind: "daily-social", at: { day: base.clock.day + 1, minute: 1020 }, personId: base.playerId, interrupts: false },
      { id: "schedule:monthly-finance" as ScheduleId, kind: "monthly-finance", at: { day: nextMonth, minute: 480 }, personId: base.playerId, interrupts: true }] }
}
