import { err, ok, type Result } from "@paralelo/shared"
import type { WorldState, WorldStateV1, WorldStateV2, WorldStateV3, WorldStateV4, WorldStateV5 } from "./domain/world"
import { jobRoles, courses, lifeEvents, routineRules } from "@paralelo/content"
import { RNG_STREAMS } from "./rng"
import { absoluteMinute } from "./time"

const object = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value)
const text = (value: unknown): value is string => typeof value === "string" && value.length > 0 && value.length <= 2000
const number = (value: unknown, min = 0, max = 100): value is number => typeof value === "number" && Number.isFinite(value) && value >= min && value <= max
const integer = (value: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): value is number => number(value, min, max) && Number.isSafeInteger(value)
const id = (value: unknown): value is string => text(value) && /^[a-z][a-z0-9:.-]{0,199}$/.test(value)
const date = (value: unknown): value is { day: number; minute: number } => object(value) && integer(value.day, -366000, 366000) && integer(value.minute, 0, 1439)
const stringArray = (value: unknown): value is string[] => Array.isArray(value) && value.every(id) && new Set(value).size === value.length
const command = (value: unknown): boolean => object(value) &&
  (["rest", "sleep", "work", "buy-groceries"].includes(String(value.type)) || (value.type === "meal" && (value.source === undefined || ["home", "restaurant", "community"].includes(String(value.source)))) || (value.type === "wait" && integer(value.minutes, 1, 10080)) || (value.type === "contact" && id(value.personId)) || (value.type === "apply-job" && id(value.vacancyId)) || (value.type === "study" && id(value.courseId)) || (value.type === "decide" && id(value.decisionId) && text(value.choiceId)) || (value.type === "reply" && id(value.messageId) && ["answer", "call", "later"].includes(String(value.reply))))

// Valida forma e referências antes de converter dados externos em domínio.
function validateBase(input: unknown, version: 1 | 2 | 3 | 4 | 5 | 6): Result<unknown, readonly string[]> {
  const errors: string[] = []
  if (!object(input)) return err(["Save não é um objeto."])
  if (input.schemaVersion !== version) return err(["Versão de save não suportada; é necessário um migrador explícito."])
  if (!text(input.seed) || input.seed.length > 200 || !input.seed.trim()) errors.push("Seed inválida.")
  if (!date(input.clock) || input.clock.day < 0) errors.push("Relógio inválido.")
  if (!integer(input.revision) || !integer(input.nextId, 1) || !id(input.playerId) || !text(input.city)) errors.push("Metadados inválidos.")
  const rng = object(input.rng) ? input.rng : {}
  if (!object(input.rng) || RNG_STREAMS.some(stream => !integer(rng[stream]))) errors.push("Streams RNG inválidas.")
  const people = object(input.people) ? input.people : {}
  const relationships = object(input.relationships) ? input.relationships : {}
  const households = object(input.households) ? input.households : {}
  const residences = object(input.residences) ? input.residences : {}
  if (!object(input.people) || !object(input.relationships) || !object(input.households) || !object(input.residences)) errors.push("Coleções de entidades inválidas.")
  if (!id(input.playerId) || !Object.hasOwn(people, input.playerId)) errors.push("Jogador ausente.")
  for (const [key, person] of Object.entries(people)) {
    if (!id(key) || !object(person) || person.id !== key || !text(person.name) || !text(person.appearanceSeed) || !date(person.birthDate) ||
      !id(person.householdId) || !Object.hasOwn(households, person.householdId) || !id(person.residenceId) || !Object.hasOwn(residences, person.residenceId) ||
      !object(person.needs) || !number(person.needs.energy) || !number(person.needs.stress) ||
      !object(person.personality) || ![person.personality.sociability, person.personality.discipline, person.personality.sensitivity].every(v => number(v, 0, 1)) ||
      !stringArray(person.relationshipIds)) { errors.push(`Pessoa inválida: ${key}.`); continue }
    if (date(input.clock) && absoluteMinute(person.birthDate) > absoluteMinute(input.clock)) errors.push(`Nascimento futuro: ${key}.`)
    for (const relId of person.relationshipIds) {
      const rel = relationships[relId]
      if (!object(rel) || (rel.a !== key && rel.b !== key)) errors.push(`Relação sem referência recíproca: ${key}/${relId}.`)
    }
    const household = households[person.householdId]
    if (!object(household) || !Array.isArray(household.memberIds) || !household.memberIds.includes(key)) errors.push(`Família sem pessoa: ${key}.`)
  }
  for (const [key, residence] of Object.entries(residences))
    if (!id(key) || !object(residence) || residence.id !== key || !text(residence.district)) errors.push(`Residência inválida: ${key}.`)
  for (const [key, household] of Object.entries(households)) {
    if (!id(key) || !object(household) || household.id !== key || !stringArray(household.memberIds) || household.memberIds.length === 0) { errors.push(`Família inválida: ${key}.`); continue }
    for (const memberId of household.memberIds) {
      const member = people[memberId]
      if (!object(member) || member.householdId !== key) errors.push(`Morador inválido: ${key}/${memberId}.`)
    }
  }
  for (const [key, rel] of Object.entries(relationships)) {
    if (!id(key) || !object(rel) || rel.id !== key || !id(rel.a) || !id(rel.b) || rel.a === rel.b || !Object.hasOwn(people, rel.a) || !Object.hasOwn(people, rel.b) ||
      ![rel.familiarity, rel.affection, rel.trust, rel.respect, rel.attraction, rel.resentment].every(v => number(v)) ||
      !Array.isArray(rel.tags) || !rel.tags.every(tag => ["family", "friend", "neighbor", "coworker"].includes(String(tag))) ||
      (rel.lastInteractionAt !== undefined && (!date(rel.lastInteractionAt) || (date(input.clock) && absoluteMinute(rel.lastInteractionAt) > absoluteMinute(input.clock))))) {
      errors.push(`Relação inválida: ${key}.`); continue
    }
    for (const personId of [rel.a, rel.b]) {
      const person = people[personId]
      if (!object(person) || !Array.isArray(person.relationshipIds) || !person.relationshipIds.includes(key)) errors.push(`Índice de relação ausente: ${key}/${personId}.`)
    }
  }
  const seen = new Set<string>()
  if (!Array.isArray(input.timeline) || input.timeline.length === 0) errors.push("Histórico inválido.")
  else for (const entry of input.timeline) {
    if (!object(entry) || !id(entry.id) || seen.has(entry.id) || !date(entry.at) || !text(entry.text) || !text(entry.cause) ||
      !["chapter", "action", "relationship", "message", "career", "finance", "education", "decision"].includes(String(entry.kind)) || !stringArray(entry.personIds) || entry.personIds.some(p => !Object.hasOwn(people, p)) ||
      (date(input.clock) && absoluteMinute(entry.at) > absoluteMinute(input.clock))) { errors.push("Entrada de timeline inválida."); continue }
    seen.add(entry.id)
    const sequence = /^timeline:(\d+)$/.exec(entry.id)
    if (!sequence || !integer(input.nextId) || Number(sequence[1]) >= input.nextId) errors.push("Sequência de ID da timeline inválida.")
  }
  const schedules = new Set<string>()
  if (!Array.isArray(input.scheduled)) errors.push("Agenda inválida.")
  else for (const item of input.scheduled) {
    if (!object(item) || !id(item.id) || schedules.has(item.id) || !date(item.at) || !["mother-message", "daily-social", "monthly-finance", "daily-events", "event-followup", "work-reminder", "work-attendance", "daily-city", "weekly-economy"].includes(String(item.kind)) || !id(item.personId) || !Object.hasOwn(people, item.personId) ||
      typeof item.interrupts !== "boolean" || (date(input.clock) && absoluteMinute(item.at) < absoluteMinute(input.clock))) errors.push("Evento agendado inválido.")
    else schedules.add(item.id)
  }
  let lastRevision = 0
  if (!Array.isArray(input.recentCommands) || input.recentCommands.length > 256) errors.push("Log de comandos inválido.")
  else for (const item of input.recentCommands) {
    if (!object(item) || !integer(item.revision, lastRevision + 1) || !integer(input.revision) || item.revision > input.revision || !date(item.at) || !command(item.command) ||
      (date(input.clock) && absoluteMinute(item.at) > absoluteMinute(input.clock))) errors.push("Comando histórico inválido.")
    else lastRevision = item.revision
  }
  return errors.length ? err(errors) : ok(input)
}

export function validateWorldV1(input: unknown): Result<WorldStateV1, readonly string[]> {
  const result = validateBase(input, 1)
  return result.ok ? ok(result.value as WorldStateV1) : result
}

function validateSlice(input: unknown, version: 2 | 3 | 4 | 5 | 6): Result<unknown, readonly string[]> {
  const base = validateBase(input, version)
  if (!base.ok) return base
  if (!object(input)) return err(["Mundo inválido."])
  const errors: string[] = []
  const people = object(input.people) ? input.people : {}
  const clock = date(input.clock) ? input.clock : { day: 0, minute: 0 }
  const past = (v: unknown) => date(v) && absoluteMinute(v) <= absoluteMinute(clock)
  const skills = object(input.skills) ? input.skills : {}, tiers = object(input.tiers) ? input.tiers : {}
  for (const personId of Object.keys(people)) {
    const skill = skills[personId]
    if (!object(skill) || !number(skill.organization, 0, 1) || !number(skill.communication, 0, 1)) errors.push(`Habilidades inválidas: ${personId}.`)
    if (!["player", "close", "background"].includes(String(tiers[personId])) || (personId === input.playerId && tiers[personId] !== "player")) errors.push(`Tier inválido: ${personId}.`)
  }
  if (Object.keys(skills).some(p => !Object.hasOwn(people, p)) || Object.keys(tiers).some(p => !Object.hasOwn(people, p))) errors.push("Habilidades/tier de pessoa ausente.")
  const companies = object(input.companies) ? input.companies : {}, vacancies = object(input.vacancies) ? input.vacancies : {}
  if (!object(input.companies) || !Object.keys(companies).length || !object(input.vacancies)) errors.push("Mercado de trabalho inválido.")
  for (const [key, company] of Object.entries(companies))
    if (!id(key) || !object(company) || company.id !== key || !text(company.name) || !text(company.district)) errors.push(`Empresa inválida: ${key}.`)
  for (const [key, vacancy] of Object.entries(vacancies))
    if (!id(key) || !object(vacancy) || vacancy.id !== key || !id(vacancy.companyId) || !Object.hasOwn(companies, vacancy.companyId) || !jobRoles.some(r => r.id === vacancy.roleId) || typeof vacancy.open !== "boolean") errors.push(`Vaga inválida: ${key}.`)
  const employment = input.employment
  if (employment !== null && (!object(employment) || !id(employment.id) || employment.personId !== input.playerId || !id(employment.companyId) || !Object.hasOwn(companies, employment.companyId) ||
    !jobRoles.some(r => r.id === employment.roleId) || !past(employment.startedAt) || (employment.lastWorkedDay !== null && !integer(employment.lastWorkedDay, 0, clock.day)) || !integer(employment.accruedCents, 0, 1e12) || !integer(employment.shiftsWorked, 0, 31) || !number(employment.performance))) errors.push("Emprego inválido.")
  if (!Array.isArray(input.applications)) errors.push("Candidaturas inválidas.")
  else for (const application of input.applications)
    if (!object(application) || !id(application.vacancyId) || !Object.hasOwn(vacancies, application.vacancyId) || !past(application.at) || typeof application.accepted !== "boolean") errors.push("Candidatura inválida.")
  const finance = input.finance
  if (!object(finance) || !integer(finance.openingBalanceCents, -1e12, 1e12) || !integer(finance.balanceCents, -1e12, 1e12) || !integer(finance.monthlyRentCents, 1, 1e12) || !Array.isArray(finance.ledger)) errors.push("Conta financeira inválida.")
  else {
    let balance = finance.openingBalanceCents
    const seen = new Set<string>()
    for (const entry of finance.ledger) {
      if (!object(entry) || !id(entry.id) || seen.has(entry.id) || !past(entry.at) || !integer(entry.amountCents, -1e12, 1e12) || !["salary", "rent", "food", "education", "event"].includes(String(entry.category)) || !text(entry.text) || !text(entry.cause)) { errors.push("Lançamento financeiro inválido."); continue }
      seen.add(entry.id)
      balance += entry.amountCents
    }
    if (balance !== finance.balanceCents) errors.push("Saldo não confere com o ledger.")
  }
  const training = input.training
  if (!object(training) || Object.keys(training).length !== courses.length) errors.push("Formação inválida.")
  else for (const course of courses) {
    const progress = training[`course:${course.id}`]
    if (!object(progress) || !integer(progress.sessions, 0, course.sessions) || (progress.lastStudiedDay !== null && !integer(progress.lastStudiedDay, 0, clock.day))) errors.push(`Curso inválido: ${course.id}.`)
  }
  if (!Array.isArray(input.memories)) errors.push("Memórias inválidas.")
  else {
    const seen = new Set<string>()
    for (const memory of input.memories) {
      if (!object(memory) || !id(memory.id) || seen.has(memory.id) || !past(memory.at) || !id(memory.personId) || !id(memory.otherId) || !Object.hasOwn(people, memory.personId) || !Object.hasOwn(people, memory.otherId) || !text(memory.text) || !text(memory.cause) || !number(memory.salience, 0, 1)) errors.push("Memória inválida.")
      else seen.add(memory.id)
    }
  }
  const periodic = Array.isArray(input.scheduled) ? input.scheduled : []
  for (const kind of ["daily-social", "monthly-finance"])
    if (periodic.filter(item => object(item) && item.kind === kind).length !== 1) errors.push(`Evento periódico ausente/duplicado: ${kind}.`)
  return errors.length ? err(errors) : ok(input)
}
export function validateWorldV2(input: unknown): Result<WorldStateV2, readonly string[]> {
  const result = validateSlice(input, 2)
  return result.ok ? ok(result.value as WorldStateV2) : result
}
function validateEvents(input: unknown, version: 3 | 4 | 5 | 6): Result<unknown, readonly string[]> {
  const result = validateSlice(input, version)
  if (!result.ok) return result
  if (!object(input) || !object(input.events)) return err(["Estado de eventos ausente."])
  const events = input.events, errors: string[] = []
  if (events.contentVersion !== 1 || !Array.isArray(events.seen) || new Set(events.seen).size !== events.seen.length || events.seen.some(id => !lifeEvents.some(event => event.id === id))) errors.push("Histórico de eventos inválido.")
  const clock = date(input.clock) ? input.clock : { day: 0, minute: 0 }
  if (events.lastOfferedDay !== null && !integer(events.lastOfferedDay, 0, clock.day)) errors.push("Orçamento de atenção inválido.")
  const pending = events.pending, people = object(input.people) ? input.people : {}
  if (pending !== null && (!object(pending) || !id(pending.id) || !lifeEvents.some(event => event.id === pending.definitionId) || !Array.isArray(events.seen) || !events.seen.includes(pending.definitionId) ||
    !date(pending.at) || absoluteMinute(pending.at) > absoluteMinute(clock) || (pending.actorId !== null && (!id(pending.actorId) || !Object.hasOwn(people, pending.actorId))))) errors.push("Decisão pendente inválida.")
  const scheduled = Array.isArray(input.scheduled) ? input.scheduled : []
  if (scheduled.filter(item => object(item) && item.kind === "daily-events").length !== 1) errors.push("Agenda de eventos inválida.")
  for (const item of scheduled) if (object(item) && item.kind === "event-followup" &&
    (!lifeEvents.some(event => !event.root && event.id === item.eventId) || (item.actorId !== null && (!id(item.actorId) || !Object.hasOwn(people, item.actorId))))) errors.push("Cadeia agendada inválida.")
  return errors.length ? err(errors) : ok(input)
}
export function validateWorldV3(input: unknown): Result<WorldStateV3, readonly string[]> {
  const result = validateEvents(input, 3)
  return result.ok ? ok(result.value as WorldStateV3) : result
}
function validateRoutine(input: unknown, version: 4 | 5 | 6): Result<unknown, readonly string[]> {
  const result = validateEvents(input, version)
  if (!result.ok) return result
  if (!object(input) || !date(input.clock)) return err(["Mundo inválido."])
  const clock = input.clock, errors: string[] = []
  for (const person of Object.values(object(input.people) ? input.people : {}))
    if (!object(person) || !object(person.needs) || !number(person.needs.hunger) || !number(person.needs.sleepPressure)) errors.push("Necessidades de rotina inválidas.")
  const routine = input.routine
  if (!object(routine) || !integer(routine.pantryMeals, 0, routineRules.groceries.capacity) || (routine.lastCommunityMealDay !== null && !integer(routine.lastCommunityMealDay, 0, clock.day))) errors.push("Despensa ou atendimento comunitário inválido.")
  const employment = input.employment
  const scheduled = Array.isArray(input.scheduled) ? input.scheduled.filter(object) : []
  const workEvents = scheduled.filter(item => item.kind === "work-reminder" || item.kind === "work-attendance")
  if (employment === null && workEvents.length) errors.push("Compromisso de emprego encerrado.")
  if (object(employment)) {
    const firstDay = date(employment.startedAt) ? employment.startedAt.day : 0
    if (!integer(employment.requiredFromDay, firstDay, clock.day + 3) || employment.requiredFromDay % 7 >= 5 ||
      !integer(employment.consecutiveAbsences, 0, routineRules.work.dismissalAbsences - 1) ||
      (employment.lastAssessedDay !== null && (!integer(employment.lastAssessedDay, Number(employment.requiredFromDay), clock.day) || employment.lastAssessedDay % 7 >= 5))) errors.push("Controle de presença inválido.")
    const vacancies = object(input.vacancies) ? Object.values(input.vacancies).filter(object) : []
    if (!vacancies.some(v => !v.open && v.companyId === employment.companyId && v.roleId === employment.roleId)) errors.push("Emprego sem vaga ocupada.")
    const assessments = workEvents.filter(item => item.kind === "work-attendance"), reminders = workEvents.filter(item => item.kind === "work-reminder")
    const at = assessments[0]?.at
    if (assessments.length !== 1 || reminders.length > 1 || !date(at) || at.day < Number(employment.requiredFromDay) ||
      (integer(employment.lastAssessedDay) && at.day <= employment.lastAssessedDay)) errors.push("Agenda de presença ausente ou duplicada.")
    if (date(at) && (at.day > clock.day || clock.minute < routineRules.work.reminderMinute) && reminders.length !== 1) errors.push("Lembrete de trabalho ausente.")
    for (const item of workEvents) if (item.employmentId !== employment.id || item.personId !== input.playerId || !date(item.at) || item.at.day % 7 >= 5 || !date(at) || item.at.day !== at.day ||
      item.at.minute !== (item.kind === "work-reminder" ? routineRules.work.reminderMinute : routineRules.work.lastStartMinute + 1)) errors.push("Compromisso de trabalho inválido.")
  }
  if (!Array.isArray(input.employmentHistory)) errors.push("Histórico profissional ausente.")
  else {
    const companies = object(input.companies) ? input.companies : {}, seen = new Set<string>()
    for (const record of input.employmentHistory) {
      if (!object(record) || !id(record.id) || seen.has(record.id) || (object(employment) && record.id === employment.id) ||
        !id(record.companyId) || !Object.hasOwn(companies, record.companyId) || !jobRoles.some(role => role.id === record.roleId) || (record.reason !== "absence" && record.reason !== "restructure") ||
        !date(record.startedAt) || !date(record.endedAt) || absoluteMinute(record.startedAt) > absoluteMinute(record.endedAt) || absoluteMinute(record.endedAt) > absoluteMinute(clock) || !integer(record.settledCents, 0, 1e12)) errors.push("Contrato encerrado inválido.")
      else {
        seen.add(record.id)
        const finance = object(input.finance) ? input.finance : {}
        const ledger = Array.isArray(finance.ledger) ? finance.ledger.filter(object) : []
        const settled = ledger.filter(entry => entry.cause === `career.settlement:${record.id}` && entry.category === "salary").reduce((sum, entry) => sum + Number(entry.amountCents), 0)
        if (settled !== record.settledCents) errors.push("Acerto de contrato não confere com o extrato.")
      }
    }
  }
  return errors.length ? err(errors) : ok(input)
}
export function validateWorldV4(input: unknown): Result<WorldStateV4, readonly string[]> {
  const result = validateRoutine(input, 4)
  return result.ok ? ok(result.value as WorldStateV4) : result
}
function validateSexed(input: unknown, version: 5 | 6): Result<unknown, readonly string[]> {
  const result = validateRoutine(input, version)
  if (!result.ok) return result
  const people = object(input) && object(input.people) ? input.people : {}
  const errors = Object.entries(people).filter(([, person]) => !object(person) || (person.sex !== "F" && person.sex !== "M")).map(([key]) => `Sexo inválido: ${key}.`)
  return errors.length ? err(errors) : ok(input)
}
export function validateWorldV5(input: unknown): Result<WorldStateV5, readonly string[]> {
  const result = validateSexed(input, 5)
  return result.ok ? ok(result.value as WorldStateV5) : result
}
// v6: moradores, economia, notícias e mensagens referenciam entidades existentes.
export function validateWorld(input: unknown): Result<WorldState, readonly string[]> {
  const result = validateSexed(input, 6)
  if (!result.ok) return result
  if (!object(input) || !date(input.clock)) return err(["Mundo inválido."])
  const clock = input.clock, errors: string[] = []
  const people = object(input.people) ? input.people : {}, companies = object(input.companies) ? input.companies : {}, vacancies = object(input.vacancies) ? input.vacancies : {}
  const residents = object(input.residents) ? input.residents : null
  if (!residents) errors.push("Moradores ausentes.")
  else {
    for (const key of Object.keys(people)) if (key !== input.playerId && !Object.hasOwn(residents, key)) errors.push(`Morador sem estado: ${key}.`)
    for (const [key, r] of Object.entries(residents)) {
      if (!Object.hasOwn(people, key) || key === input.playerId || !object(r)) { errors.push(`Morador inválido: ${key}.`); continue }
      const job = r.job
      if (job !== null && (!object(job) || !id(job.companyId) || !Object.hasOwn(companies, job.companyId) || !jobRoles.some(role => role.id === job.roleId) || !date(job.since) || !number(job.satisfaction))) errors.push(`Emprego de morador inválido: ${key}.`)
      const goal = r.goal
      if (goal !== null && (!object(goal) || !["find-job", "change-job", "keep-in-touch"].includes(String(goal.kind)) || !date(goal.since))) errors.push(`Objetivo inválido: ${key}.`)
      const decision = r.lastDecision
      if (decision !== null && (!object(decision) || !date(decision.at) || !Array.isArray(decision.options) || !text(decision.chosen))) errors.push(`Decisão de IA inválida: ${key}.`)
      for (const field of ["lastAppliedDay", "lastMessagedDay"] as const) if (r[field] !== null && !integer(r[field], 0, clock.day)) errors.push(`Marcação de dia inválida: ${key}.`)
    }
  }
  const economy = object(input.economy) ? input.economy : null
  if (!economy || Object.keys(companies).some(c => !Object.hasOwn(economy, c))) errors.push("Economia das empresas ausente.")
  else for (const [key, e] of Object.entries(economy))
    if (!Object.hasOwn(companies, key) || !object(e) || !number(e.health, 0, 1) || !number(e.trend, -1, 1) || !integer(e.weakWeeks, 0, 1000)) errors.push(`Economia inválida: ${key}.`)
  const seen = new Set<string>()
  if (!Array.isArray(input.news)) errors.push("Notícias ausentes.")
  else for (const n of input.news)
    if (!object(n) || !id(n.id) || seen.has(n.id) || !date(n.at) || absoluteMinute(n.at) > absoluteMinute(clock) || !["negocios", "trabalho", "cidade"].includes(String(n.section)) || !text(n.headline) || !text(n.body) || !text(n.cause) ||
      (n.companyId !== null && (!id(n.companyId) || !Object.hasOwn(companies, n.companyId))) || !stringArray(n.personIds) || n.personIds.some(p => !Object.hasOwn(people, p))) errors.push("Notícia inválida.")
    else seen.add(n.id)
  if (!Array.isArray(input.inbox)) errors.push("Mensagens ausentes.")
  else for (const m of input.inbox)
    if (!object(m) || !id(m.id) || seen.has(m.id) || !date(m.at) || !date(m.expiresAt) || absoluteMinute(m.at) > absoluteMinute(clock) || !id(m.fromId) || !Object.hasOwn(people, m.fromId) ||
      !["checkin", "hired", "dismissed", "job-tip", "worry"].includes(String(m.topic)) || !text(m.text) || !["unread", "answered", "ignored"].includes(String(m.status)) || typeof m.postponed !== "boolean" ||
      (m.vacancyId !== null && (!id(m.vacancyId) || !Object.hasOwn(vacancies, m.vacancyId)))) errors.push("Mensagem inválida.")
    else seen.add(m.id)
  const scheduled = Array.isArray(input.scheduled) ? input.scheduled.filter(object) : []
  for (const kind of ["daily-city", "weekly-economy"]) if (scheduled.filter(item => item.kind === kind).length !== 1) errors.push(`Rotina da cidade ausente/duplicada: ${kind}.`)
  return errors.length ? err(errors) : ok(input as unknown as WorldState)
}
