// Mundo vivo: a cidade continua sem o jogador (bíblia §2.1, §13, §15, §19, §20, §45).
// Empresas mudam de saúde, abrem e cortam vagas; moradores têm objetivos e escolhem ações por
// utilidade com inércia; o que acontece vira notícia pública ou mensagem de quem você conhece.
// Aleatoriedade por hash de (seed, sistema, dia, entidade): determinística e sem consumir as
// streams do jogador (bíblia §38).
import { cityRules, fillText, jobRoles, messageTexts, newsTexts, replyTexts } from "@paralelo/content"
import type { CompanyId, MessageId, NewsId, PersonId, RelationshipId, ScheduleId, VacancyId } from "@paralelo/shared"
import type {
  AiDecision, CompanyEconomy, Goal, Message, MessageReply, MessageTopic, NewsItem, NewsSection, Relationship,
  RelationshipTag, Resident, ScheduledEvent, WorldState, WorldStateV5,
} from "../domain/world"
import { hashText } from "../rng"
import { absoluteMinute, addMinutes, ageAt, formatDate } from "../time"
import { appendEntry, entryWeight } from "../timeline"
import { formatMoney, postLedger } from "./finance"
import { remember } from "./memory"
import { changeNeeds } from "./needs"
import { updateRelationship } from "./relationships"

const chance = (world: { seed: string }, key: string): number => hashText(`${world.seed}/city/${key}`) / 4294967296
const clamp = (v: number, lo = 0, hi = 1): number => Math.max(lo, Math.min(hi, v))
const firstName = (name: string): string => name.split(" ")[0] ?? name

export function relationshipBetween(world: Pick<WorldState, "relationships">, a: PersonId, b: PersonId): Relationship | undefined {
  return Object.values(world.relationships).find(r => (r.a === a && r.b === b) || (r.a === b && r.b === a))
}

function nextMonday(day: number): number {
  const weekday = ((day % 7) + 7) % 7
  return day + (weekday === 0 ? 7 : 7 - weekday)
}

// ---------------- migração e criação ----------------

// v5 -> v6: acrescenta emprego e objetivos dos moradores, economia das empresas, vizinhos e
// amizades entre pessoas próximas. Usa uma namespace própria; não consome RNG salvo.
export function upgradeWorldV5(base: WorldStateV5): WorldState {
  const value = (key: string): number => hashText(`${base.seed}/city-v6/${key}`) / 4294967296
  const companyIds = Object.keys(base.companies).sort() as CompanyId[]
  const residents: Record<string, Resident> = {}
  for (const person of Object.values(base.people).sort((a, b) => (a.id < b.id ? -1 : 1))) {
    if (person.id === base.playerId) continue
    const age = ageAt(person.birthDate, base.clock)
    const adult = age >= 18 && age <= 64
    const employed = adult && value(`${person.id}/employed`) < cityRules.employedShare
    const companyId = companyIds[Math.floor(value(`${person.id}/company`) * companyIds.length)]!
    // cada um trabalha em algo que o próprio preparo sustenta
    const skills = base.skills[person.id]
    const fit = skills ? jobRoles.filter(r => skills[r.skill] >= r.required * 0.8) : []
    const pool = fit.length ? fit : jobRoles.filter(r => r.required <= 0.15)
    const role = pool[Math.floor(value(`${person.id}/role`) * pool.length)]!
    residents[person.id] = {
      job: employed ? { companyId, roleId: role.id, since: { day: base.clock.day - Math.floor(value(`${person.id}/since`) * 1500), minute: 480 }, satisfaction: Math.round(40 + value(`${person.id}/sat`) * 40) } : null,
      goal: null, lastDecision: null, lastAppliedDay: null, lastMessagedDay: null,
    }
  }
  const economy: Record<string, CompanyEconomy> = {}
  for (const id of companyIds) economy[id] = { health: +(0.45 + value(`${id}/health`) * 0.3).toFixed(3), trend: 0, weakWeeks: 0 }

  // vizinhos: gente do mesmo bairro passa a fazer parte do círculo (bíblia §48: 20 relevantes)
  const player = base.people[base.playerId]!
  const district = base.residences[player.residenceId]!.district
  const people = { ...base.people }
  const relationships = { ...base.relationships }
  const tiers = { ...base.tiers }
  const link = (a: PersonId, b: PersonId, tag: RelationshipTag, familiarity: number, affection: number, trust: number): void => {
    const id = `relationship:${tag}:${a}:${b}` as RelationshipId
    if (relationships[id] || relationshipBetween({ relationships }, a, b)) return
    relationships[id] = { id, a, b, familiarity, affection, trust, respect: 45, attraction: 0, resentment: 0, tags: [tag] }
    for (const personId of [a, b]) people[personId] = { ...people[personId]!, relationshipIds: [...people[personId]!.relationshipIds, id] }
  }
  const neighbors = Object.values(base.people)
    .filter(p => p.id !== base.playerId && base.tiers[p.id] === "background" && base.residences[p.residenceId]?.district === district)
    .sort((a, b) => value(`${a.id}/neighbor`) - value(`${b.id}/neighbor`))
    .slice(0, cityRules.neighbors)
  for (const n of neighbors) {
    link(base.playerId, n.id, "neighbor", 8, 20 + Math.floor(value(`${n.id}/aff`) * 15), 20)
    tiers[n.id] = "close"
  }
  // pessoas próximas se conhecem entre si (bíblia §11.4)
  const circle = Object.values(base.relationships).filter(r => r.a === base.playerId || r.b === base.playerId).map(r => (r.a === base.playerId ? r.b : r.a))
  const friends = circle.filter(id => relationshipBetween(base, base.playerId, id)?.tags.includes("friend"))
  const family = circle.filter(id => relationshipBetween(base, base.playerId, id)?.tags.includes("family"))
  for (let i = 0; i < friends.length; i++) for (let j = i + 1; j < friends.length; j++) link(friends[i]!, friends[j]!, "friend", 45, 50, 45)
  for (const f of family) for (const fr of friends) link(f, fr, "friend", 20, 40, 35)

  const day = base.clock.day
  const scheduled: ScheduledEvent[] = [...base.scheduled,
    { id: "schedule:daily-city" as ScheduleId, kind: "daily-city", at: { day: base.clock.minute < cityRules.dailyCityMinute ? day : day + 1, minute: cityRules.dailyCityMinute }, personId: base.playerId, interrupts: false },
    { id: "schedule:weekly-economy" as ScheduleId, kind: "weekly-economy", at: { day: nextMonday(day), minute: cityRules.weeklyEconomyMinute }, personId: base.playerId, interrupts: false }]
  return { ...base, schemaVersion: 6, people, relationships, tiers, residents, economy, news: [], inbox: [], scheduled }
}

// ---------------- notícias e mensagens ----------------

type Fill = Parameters<typeof fillText>[1]
function publish(world: WorldState, section: NewsSection, variants: readonly { headline: string; body: string }[], values: Fill, companyId: CompanyId | null, personIds: readonly PersonId[], cause: string): WorldState {
  const variant = variants[hashText(`${world.seed}/${cause}`) % variants.length]!
  const item: NewsItem = { id: `news:${world.nextId}` as NewsId, at: world.clock, section, headline: fillText(variant.headline, values), body: fillText(variant.body, values), companyId, personIds, cause }
  return { ...world, nextId: world.nextId + 1, news: [...world.news, item].slice(-cityRules.newsLimit) }
}

function message(world: WorldState, fromId: PersonId, topic: MessageTopic, text: string, vacancyId: VacancyId | null = null): WorldState {
  const from = world.people[fromId]!
  const item: Message = { id: `message:${world.nextId}` as MessageId, at: world.clock, fromId, topic, text, expiresAt: addMinutes(world.clock, cityRules.messageHours * 60), status: "unread", postponed: false, vacancyId }
  const next: WorldState = { ...world, nextId: world.nextId + 1, inbox: [...world.inbox, item].slice(-cityRules.inboxLimit),
    residents: { ...world.residents, [fromId]: { ...world.residents[fromId]!, lastMessagedDay: world.clock.day } } }
  return appendEntry(next, { at: world.clock, kind: "message", text: `${from.name}: “${text}”`, personIds: [world.playerId, fromId], cause: item.id })
}

const pick = <T>(list: readonly T[], key: string, world: { seed: string }): T => list[Math.floor(chance(world, key) * list.length)]!
const roleTitle = (roleId: string): string => jobRoles.find(r => r.id === roleId)?.title.toLowerCase() ?? roleId

// ---------------- economia semanal ----------------

/** Pessoas empregadas na empresa, contando o jogador. */
function staffOf(world: WorldState, companyId: CompanyId): number {
  let n = world.employment?.companyId === companyId ? 1 : 0
  for (const r of Object.values(world.residents)) if (r.job?.companyId === companyId) n++
  return n
}
/** Quadro que o movimento sustenta: a cidade tende a ~10% de desemprego em tempos normais. */
function capacityOf(world: WorldState, companyId: CompanyId): number {
  const companies = Object.keys(world.companies).length
  let adults = 1
  for (const id of Object.keys(world.residents)) { const age = ageAt(world.people[id]!.birthDate, world.clock); if (age >= 18 && age <= 64) adults++ }
  const health = world.economy[companyId]?.health ?? 0.5
  return Math.round((adults / companies) * cityRules.employedTarget * (0.75 + 0.5 * health))
}

export function processWeeklyEconomy(world: WorldState, event: ScheduledEvent): WorldState {
  let next = world
  const day = world.clock.day
  // satisfação no trabalho flutua; empresas fracas pesam; aos 65 a pessoa se aposenta
  const residents = { ...next.residents }
  for (const [id, r] of Object.entries(residents)) {
    if (!r.job) continue
    if (ageAt(next.people[id]!.birthDate, next.clock) >= 65) { residents[id] = { ...r, job: null, goal: null }; continue }
    const health = next.economy[r.job.companyId]?.health ?? 0.5
    residents[id] = { ...r, job: { ...r.job, satisfaction: Math.round(clamp(r.job.satisfaction + (chance(next, `sat/${id}/${day}`) - 0.5) * 10 - (health < 0.4 ? 3 : 0), 0, 100)) } }
  }
  next = { ...next, residents }
  // rotatividade: todo mês alguém sai por conta própria, mais ainda quem está insatisfeito (bíblia §15.2)
  for (const [id, r] of Object.entries(next.residents).sort(([a], [b]) => (a < b ? -1 : 1))) {
    if (!r.job || chance(next, `quit/${id}/${day}`) >= cityRules.weeklyTurnover + (r.job.satisfaction < 40 ? 0.04 : 0)) continue
    const job = r.job
    next = { ...next, residents: { ...next.residents, [id]: { ...r, job: null, goal: { kind: "find-job", since: next.clock } } } }
    next = openReplacement(next, id as PersonId, job)
  }
  for (const companyId of Object.keys(next.economy).sort() as CompanyId[]) {
    const before = next.economy[companyId]!
    const company = next.companies[companyId]!
    const trend = clamp(before.trend * 0.7 + (chance(next, `trend/${companyId}/${day}`) - 0.5) * 0.14, -0.12, 0.12)
    const health = +clamp(before.health + trend * 0.5 + (0.55 - before.health) * 0.04, 0.05, 0.95).toFixed(3)
    const weakWeeks = health < 0.3 ? before.weakWeeks + 1 : 0
    next = { ...next, economy: { ...next.economy, [companyId]: { health, trend: +trend.toFixed(3), weakWeeks } } }
    const values = { company: company.name, district: company.district }
    if (before.health >= 0.35 && health < 0.35) {
      next = publish(next, "negocios", newsTexts.weak, values, companyId, [], `economy.weak:${companyId}:${day}`)
      for (const [id, r] of Object.entries(next.residents)) if (r.job?.companyId === companyId && relationshipBetween(next, next.playerId, id as PersonId))
        next = message(next, id as PersonId, "worry", fillText(pick(messageTexts.worry, `worry/${id}/${day}`, next), values))
      const open = Object.values(next.vacancies).filter(v => v.open && v.companyId === companyId)
      for (const v of open) {
        next = { ...next, vacancies: { ...next.vacancies, [v.id]: { ...v, open: false } } }
        next = publish(next, "trabalho", newsTexts.freeze, { ...values, role: roleTitle(v.roleId) }, companyId, [], `economy.freeze:${v.id}:${day}`)
      }
    }
    if (before.health < 0.5 && health >= 0.7) next = publish(next, "negocios", newsTexts.recovery, values, companyId, [], `economy.recovery:${companyId}:${day}`)
    if (weakWeeks >= 2) next = layoff(next, companyId, day)
    // quadro acima do que o movimento sustenta: corte pontual mesmo sem crise declarada
    else if (health < 0.45 && staffOf(next, companyId) > capacityOf(next, companyId) + 1 && chance(next, `trim/${companyId}/${day}`) < 0.25) next = layoff(next, companyId, day)
    const openHere = Object.values(next.vacancies).filter(v => v.open && v.companyId === companyId).length
    // só contrata quem tem espaço no quadro; empresa saudável sustenta mais gente
    if (health >= 0.4 && staffOf(next, companyId) + openHere < capacityOf(next, companyId) && chance(next, `open/${companyId}/${day}`) < 0.45) {
      // a vaga nasce para o que a cidade tem de gente: prefere funções que alguém sem emprego consegue ocupar
      const seekers = Object.entries(next.residents).filter(([, r]) => !r.job && r.goal?.kind === "find-job").map(([id]) => next.skills[id]).filter(s => !!s)
      const reachable = jobRoles.filter(role => seekers.some(s => s[role.skill] >= role.required * 0.8))
      const role = pick(reachable.length && chance(next, `reach/${companyId}/${day}`) < 0.8 ? reachable : jobRoles, `open-role/${companyId}/${day}`, next)
      const id = `vacancy:${next.nextId}` as VacancyId
      next = { ...next, nextId: next.nextId + 1, vacancies: { ...next.vacancies, [id]: { id, companyId, roleId: role.id, open: true } } }
      next = publish(next, "trabalho", newsTexts.opening, { ...values, role: role.title.toLowerCase() }, companyId, [], `economy.opening:${id}`)
    }
  }
  return { ...next, scheduled: [...next.scheduled, { ...event, at: { day: nextMonday(day), minute: cityRules.weeklyEconomyMinute } }] }
}

function layoff(world: WorldState, companyId: CompanyId, day: number): WorldState {
  const company = world.companies[companyId]!
  let next: WorldState = { ...world, economy: { ...world.economy, [companyId]: { ...world.economy[companyId]!, health: +clamp(world.economy[companyId]!.health + 0.08).toFixed(3), weakWeeks: 0 } } }
  const employment = next.employment
  if (employment && employment.companyId === companyId && chance(next, `layoff-player/${companyId}/${day}`) < 0.3 + (60 - employment.performance) / 150) return dismissPlayer(next)
  const staff = Object.entries(next.residents).filter(([, r]) => r.job?.companyId === companyId)
    .sort(([a, ra], [b, rb]) => ra.job!.satisfaction - rb.job!.satisfaction || (a < b ? -1 : 1))
  const target = staff[0]
  if (!target) return next
  const [id, resident] = target
  const person = next.people[id]!
  next = { ...next, residents: { ...next.residents, [id]: { ...resident, job: null } } }
  next = publish(next, "trabalho", newsTexts.layoff, { company: company.name, name: person.name, role: roleTitle(resident.job!.roleId), district: company.district }, companyId, [id as PersonId], `economy.layoff:${id}:${day}`)
  if (relationshipBetween(next, next.playerId, id as PersonId))
    next = message(next, id as PersonId, "dismissed", fillText(pick(messageTexts.dismissed, `dismissed/${id}/${day}`, next), { company: company.name }))
  return next
}

/** Corte de custos atinge o jogador (bíblia §15.6, §45). */
export function dismissPlayer(world: WorldState): WorldState {
  const employment = world.employment!
  const company = world.companies[employment.companyId]!
  let next = world
  if (employment.accruedCents > 0) next = postLedger(next, { amountCents: employment.accruedCents, category: "salary", text: `Acerto dos turnos · ${company.name}`, cause: `career.settlement:${employment.id}` })
  next = { ...next, employment: null,
    employmentHistory: [...next.employmentHistory, { id: employment.id, companyId: employment.companyId, roleId: employment.roleId, startedAt: employment.startedAt, endedAt: world.clock, reason: "restructure", settledCents: employment.accruedCents }],
    scheduled: next.scheduled.filter(item => item.employmentId !== employment.id) }
  next = changeNeeds(next, { stress: 18 })
  next = publish(next, "trabalho", newsTexts.layoff, { company: company.name, name: next.people[next.playerId]!.name, role: roleTitle(employment.roleId), district: company.district }, company.id, [next.playerId], `economy.layoff:${next.playerId}:${world.clock.day}`)
  return appendEntry(next, { at: next.clock, kind: "career", text: `${company.name} cortou custos depois de semanas fracas e encerrou seu contrato.${employment.accruedCents > 0 ? ` Os turnos cumpridos foram pagos: ${formatMoney(employment.accruedCents)}.` : ""} A decisão não teve relação com faltas.`, personIds: [next.playerId], cause: `career.restructure:${employment.id}` })
}

// ---------------- vida diária dos moradores ----------------

function goalFor(world: WorldState, id: PersonId, r: Resident): Goal | null {
  const age = ageAt(world.people[id]!.birthDate, world.clock)
  const rel = relationshipBetween(world, world.playerId, id)
  let kind: Goal["kind"] | null = null
  if (!r.job && age >= 18 && age <= 64) kind = "find-job"
  else if (r.job && r.job.satisfaction < 35) kind = "change-job"
  else if (rel && world.tiers[id] === "close" && (!rel.lastInteractionAt || absoluteMinute(world.clock) - absoluteMinute(rel.lastInteractionAt) > 10 * 1440)) kind = "keep-in-touch"
  if (!kind) return null
  return r.goal?.kind === kind ? r.goal : { kind, since: world.clock }
}

export function processDailyCity(world: WorldState, event: ScheduledEvent): WorldState {
  // memórias que o tempo apagou saem do registro (bíblia §10.2, §43: memória não cresce sem limite)
  let next = expireMessages({ ...world, memories: world.memories.filter(m => m.salience >= 0.05), vacancies: pruneVacancies(world), timeline: pruneTimeline(world) })
  const day = world.clock.day
  const ids = Object.keys(next.residents).sort() as PersonId[]
  for (const id of ids) {
    const close = next.tiers[id] === "close"
    if (!close && hashText(id) % 7 !== ((day % 7) + 7) % 7) continue // população de fundo: uma vez por semana (bíblia §39)
    next = residentTurn(next, id, close)
  }
  return { ...next, scheduled: [...next.scheduled, { ...event, at: { day: day + 1, minute: cityRules.dailyCityMinute } }] }
}

// o histórico guarda o que importa por anos; ruído sai em um mês e rotina em um ano (bíblia §6.4, §43)
function pruneTimeline(world: WorldState): WorldState["timeline"] {
  if (world.clock.day % 7 !== 0) return world.timeline
  // a timeline é cronológica: só o trecho com mais de 30 dias precisa ser olhado
  const now = absoluteMinute(world.clock)
  let end = 0
  while (end < world.timeline.length && now - absoluteMinute(world.timeline[end]!.at) > 30 * 1440) end++
  if (!end) return world.timeline
  const old = world.timeline.slice(0, end).filter(e => {
    const weight = entryWeight(e)
    return weight === "ruido" ? false : weight === "cotidiano" ? now - absoluteMinute(e.at) <= 365 * 1440 : true
  })
  return old.length === end ? world.timeline : [...old, ...world.timeline.slice(end)]
}

// vaga fechada some do mercado; só fica registrada se o jogador se candidatou ou se uma mensagem cita
function pruneVacancies(world: WorldState): WorldState["vacancies"] {
  const kept = new Set<string>([...world.applications.map(a => a.vacancyId), ...world.inbox.flatMap(m => (m.vacancyId ? [m.vacancyId] : []))])
  const vacancies: Record<string, WorldState["vacancies"][string]> = {}
  for (const [id, v] of Object.entries(world.vacancies)) if (v.open || kept.has(id)) vacancies[id] = v
  return vacancies
}

function residentTurn(world: WorldState, id: PersonId, close: boolean): WorldState {
  const r0 = world.residents[id]!
  const person = world.people[id]!
  const day = world.clock.day
  const goal = goalFor(world, id, r0)
  const r: Resident = { ...r0, goal }
  const noise = (k: string): number => (chance(world, `noise/${id}/${day}/${k}`) - 0.5) * 0.16
  const options: { action: string; score: number; run: () => WorldState }[] = []
  const withResident = (w: WorldState, patch: Partial<Resident>): WorldState => ({ ...w, residents: { ...w.residents, [id]: { ...w.residents[id]!, ...patch } } })

  // candidatar-se: utilidade = urgência × preparo × disciplina, com inércia após uma tentativa
  const skills = world.skills[id]
  if (goal && (goal.kind === "find-job" || goal.kind === "change-job") && skills) {
    const urgency = goal.kind === "find-job" ? 0.8 : 0.45
    for (const v of Object.values(world.vacancies).filter(v => v.open && v.companyId !== r.job?.companyId).sort((a, b) => (a.id < b.id ? -1 : 1))) {
      const role = jobRoles.find(x => x.id === v.roleId)!
      const skill = skills[role.skill]
      if (skill < role.required * 0.8) continue
      const inertia = r.lastAppliedDay !== null && day - r.lastAppliedDay < 5 ? 0.2 : 1
      options.push({ action: `candidatar-se:${v.id}`, score: urgency * (skill >= role.required ? 1 : 0.6) * (0.6 + 0.4 * person.personality.discipline) * inertia + noise(v.id),
        run: () => applyResident(withResident(world, { goal, lastAppliedDay: day }), id, v.id) })
    }
  }
  const rel = relationshipBetween(world, world.playerId, id)
  if (rel) {
    // vínculo mais próximo escreve mais; depois de escrever, a pessoa espera uma semana
    const weight = rel.tags.includes("family") ? 1 : rel.tags.includes("friend") ? 0.85 : rel.tags.includes("coworker") ? 0.6 : 0.4
    const inertia = r.lastMessagedDay !== null && day - r.lastMessagedDay < 7 ? 0.05 : 1
    options.push({ action: "mandar-mensagem", score: (0.04 + person.personality.sociability * 0.22 + (goal?.kind === "keep-in-touch" ? 0.3 : 0)) * weight * inertia + noise("msg"),
      run: () => {
        const tag = rel.tags[0] ?? "friend"
        const pool = messageTexts.checkin[tag]
        const company = r.job ? world.companies[r.job.companyId]! : null
        const text = fillText(pick(pool, `checkin/${id}/${day}`, world), { first: firstName(person.name), district: world.residences[person.residenceId]!.district, company: company?.name ?? "" })
        return message(withResident(world, { goal }), id, "checkin", text)
      } })
    const tip = r.job && !world.employment && rel.trust >= 45
      ? Object.values(world.vacancies).find(v => v.open && v.companyId === r.job!.companyId) : undefined
    if (tip) options.push({ action: `indicar-vaga:${tip.id}`, score: (0.75 + noise("tip")) * inertia,
      run: () => message(withResident(world, { goal }), id, "job-tip", fillText(pick(messageTexts.jobTip, `tip/${id}/${day}`, world), { company: world.companies[tip.companyId]!.name, role: roleTitle(tip.roleId) }), tip.id) })
  }
  options.push({ action: "seguir-a-rotina", score: 0.3 + noise("routine"), run: () => withResident(world, { goal }) })
  options.sort((a, b) => b.score - a.score || (a.action < b.action ? -1 : 1))
  const chosen = options[0]!
  let next = chosen.run()
  if (close) {
    const decision: AiDecision = { at: world.clock, goal: goal?.kind ?? null, options: options.slice(0, 5).map(o => ({ action: o.action, score: +o.score.toFixed(3) })), chosen: chosen.action }
    next = withResident(next, { lastDecision: decision })
  }
  return next
}

function applyResident(world: WorldState, id: PersonId, vacancyId: VacancyId): WorldState {
  const v = world.vacancies[vacancyId]!
  const role = jobRoles.find(x => x.id === v.roleId)!
  const skill = world.skills[id]![role.skill]
  if (chance(world, `hire/${id}/${vacancyId}/${world.clock.day}`) >= 0.45 + skill * 0.5) return world
  const person = world.people[id]!
  const company = world.companies[v.companyId]!
  const previous = world.residents[id]!.job
  let next: WorldState = { ...world, vacancies: { ...world.vacancies, [vacancyId]: { ...v, open: false } },
    residents: { ...world.residents, [id]: { ...world.residents[id]!, goal: null, job: { companyId: v.companyId, roleId: v.roleId, since: world.clock, satisfaction: 65 } } } }
  next = publish(next, "trabalho", newsTexts.hire, { company: company.name, name: person.name, role: role.title.toLowerCase(), district: company.district }, company.id, [id], `city.hire:${id}:${vacancyId}`)
  if (previous) next = openReplacement(next, id, previous)
  if (relationshipBetween(next, next.playerId, id)) next = message(next, id, "hired", fillText(pick(messageTexts.hired, `hired/${id}/${vacancyId}`, next), { company: company.name, role: role.title.toLowerCase() }))
  return next
}

/** Quem sai abre vaga de substituição quando o quadro precisa (bíblia §15.2). */
function openReplacement(world: WorldState, id: PersonId, previous: NonNullable<Resident["job"]>): WorldState {
  if (staffOf(world, previous.companyId) >= capacityOf(world, previous.companyId)) return world
  const old = world.companies[previous.companyId]!
  const replacement = `vacancy:${world.nextId}` as VacancyId
  const next: WorldState = { ...world, nextId: world.nextId + 1, vacancies: { ...world.vacancies, [replacement]: { id: replacement, companyId: old.id, roleId: previous.roleId, open: true } } }
  return publish(next, "trabalho", newsTexts.replacement, { company: old.name, name: world.people[id]!.name, role: roleTitle(previous.roleId), district: old.district }, old.id, [id], `city.replacement:${replacement}`)
}

// ---------------- mensagens do jogador ----------------

function expireMessages(world: WorldState): WorldState {
  let next = world
  for (const m of world.inbox) {
    if (m.status !== "unread" || absoluteMinute(m.expiresAt) > absoluteMinute(world.clock)) continue
    const from = next.people[m.fromId]!
    next = { ...next, inbox: next.inbox.map(x => (x.id === m.id ? { ...x, status: "ignored" as const } : x)) }
    const rel = relationshipBetween(next, next.playerId, m.fromId)
    if (rel) next = updateRelationship(next, rel.id, { affection: -2, trust: -1 })
    // o silêncio também é ação e vira memória (bíblia §12.2)
    next = remember(next, m.fromId, next.playerId, `Ficou sem resposta a mensagem de ${formatDate(m.at)}.`, m.id)
    next = appendEntry(next, { at: next.clock, kind: "relationship", text: fillText(replyTexts.ignored, { first: firstName(from.name) }), personIds: [next.playerId, m.fromId], cause: `message.ignored:${m.id}` })
  }
  return next
}

export type ReplyError = Readonly<{ code: "unavailable"; message: string }>
export function replyReason(world: WorldState, messageId: MessageId, reply: MessageReply): string | null {
  const m = world.inbox.find(x => x.id === messageId)
  if (!m || m.status !== "unread") return "Essa mensagem já foi respondida."
  if (absoluteMinute(m.expiresAt) <= absoluteMinute(world.clock)) return "A conversa esfriou. Agora só puxando assunto de novo."
  if (reply === "later" && m.postponed) return "Você já deixou essa mensagem para depois uma vez."
  if (world.people[world.playerId]!.needs.energy < 10 && reply === "call") return "Você está sem energia para uma ligação agora."
  return null
}

/** Resposta do jogador. Retorna o mundo já com o tempo gasto (a camada de comandos avança o relógio). */
export function resolveReply(world: WorldState, messageId: MessageId, reply: MessageReply): { world: WorldState; minutes: number } {
  const m = world.inbox.find(x => x.id === messageId)!
  const from = world.people[m.fromId]!
  const first = firstName(from.name)
  if (reply === "later") {
    const next = { ...world, inbox: world.inbox.map(x => (x.id === m.id ? { ...x, postponed: true, expiresAt: addMinutes(x.expiresAt, cityRules.messageHours * 60) } : x)) }
    return { world: appendEntry(next, { at: world.clock, kind: "relationship", text: fillText(replyTexts.later, { first }), personIds: [world.playerId, m.fromId], cause: `message.later:${m.id}` }), minutes: 1 }
  }
  let next: WorldState = { ...world, inbox: world.inbox.map(x => (x.id === m.id ? { ...x, status: "answered" as const } : x)) }
  const rel = relationshipBetween(next, next.playerId, m.fromId)
  if (rel) next = updateRelationship(next, rel.id, reply === "call" ? { affection: 3, trust: 2, familiarity: 2 } : { affection: 2, trust: 1, familiarity: 1 }, next.clock)
  const company = m.vacancyId ? next.companies[next.vacancies[m.vacancyId]!.companyId]!.name : (next.residents[m.fromId]?.job ? next.companies[next.residents[m.fromId]!.job!.companyId]!.name : "")
  const key = m.topic === "job-tip" ? "jobTip" : m.topic
  const text = reply === "call" ? fillText(replyTexts.call, { first }) : fillText(replyTexts.answer[key], { first, company })
  next = remember(next, m.fromId, next.playerId, reply === "call" ? `Você ligou de volta depois da mensagem de ${formatDate(m.at)}.` : `Você respondeu a mensagem de ${formatDate(m.at)}.`, m.id)
  return { world: appendEntry(next, { at: next.clock, kind: "relationship", text, personIds: [next.playerId, m.fromId], cause: `message.${reply}:${m.id}` }), minutes: reply === "call" ? 30 : 15 }
}

/** Indicação aceita pelo jogador vale para aquela vaga (bíblia §15.3, §45). */
export const hasReferral = (world: WorldState, vacancyId: VacancyId): boolean =>
  world.inbox.some(m => m.topic === "job-tip" && m.vacancyId === vacancyId && m.status === "answered")

/** Colegas de trabalho entram no círculo quando o jogador é contratado. */
export function meetCoworkers(world: WorldState, companyId: CompanyId): WorldState {
  let next = world
  const staff = Object.entries(world.residents).filter(([id, r]) => r.job?.companyId === companyId && !relationshipBetween(world, world.playerId, id as PersonId))
    .sort(([a], [b]) => (a < b ? -1 : 1)).slice(0, 2)
  for (const [id] of staff) {
    const relId = `relationship:coworker:${world.playerId}:${id}` as RelationshipId
    if (next.relationships[relId]) continue
    next = { ...next,
      relationships: { ...next.relationships, [relId]: { id: relId, a: next.playerId, b: id as PersonId, familiarity: 10, affection: 25, trust: 25, respect: 45, attraction: 0, resentment: 0, tags: ["coworker"], lastInteractionAt: next.clock } },
      people: { ...next.people, [next.playerId]: { ...next.people[next.playerId]!, relationshipIds: [...next.people[next.playerId]!.relationshipIds, relId] }, [id]: { ...next.people[id]!, relationshipIds: [...next.people[id]!.relationshipIds, relId] } },
      tiers: { ...next.tiers, [id]: "close" } }
  }
  return next
}
