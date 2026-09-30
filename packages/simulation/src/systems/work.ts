// Trabalho vivido (bíblia §7, §15, §46, §61). O turno tem um momento em que você decide como
// agir; quem responde pela equipe forma uma opinião (confiança); a tarefa da semana tem prazo;
// a conversa do mês pode trazer aumento, advertência ou promoção; candidatura vira entrevista.
// Sorteios pela stream "career"; nada aqui avança o relógio (a camada de comandos avança).
import {
  assignmentTemplates, bodyRules, inPlace, courses, fillText, interviewTexts, jobRoles, reviewTexts, roleCareer, workRules, workSituations,
  type RoleFamily, type WorkChoice, type WorkEffect, type WorkSituation,
} from "@paralelo/content"
import type { CompanyId, EmploymentId, InterviewId, PersonId, RelationshipId, SceneId, ScheduleId, VacancyId } from "@paralelo/shared"
import type { EmploymentV7, Interview, ScheduledEvent, WorkScene, Workplace, WorldState, WorldStateV6, WorldStateV7 } from "../domain/world"
import { draw, hashText } from "../rng"
import { absoluteMinute, ageAt, formatDate, formatTime, weekdayOf } from "../time"
import { appendEntry } from "../timeline"
import { nextWeekday, scheduleWorkDay } from "./career"
import { dismissPlayer, meetCoworkers, relationshipBetween } from "./city"
import { formatMoney, postLedger } from "./finance"
import { remember } from "./memory"
import { changeNeeds } from "./needs"
import { updateRelationship } from "./relationships"
import { burn, dressGap, eat, presenceOf } from "./body"

const clamp = (v: number, lo = 0, hi = 100): number => Math.max(lo, Math.min(hi, v))
/** Confiança e desempenho sobem cada vez mais devagar perto do topo; caem sem desconto. */
const nudge = (value: number, delta: number): number => clamp(delta > 0 ? value + delta * Math.min(1, (100 - value) / 50) : value + delta)
const first = (name: string): string => name.split(" ")[0] ?? name
const roleOf = (id: string) => jobRoles.find(r => r.id === id)
export const familyOf = (roleId: string): RoleFamily => roleCareer[roleId]?.family ?? "atendimento"
const onWeekday = (day: number): string => { const w = weekdayOf({ day, minute: 0 }); return `${w === "sábado" || w === "domingo" ? "no" : "na"} ${w}` }
/** "na quinta, às 10h" / "amanhã, às 15h" relativo ao relógio */
export function whenText(world: Pick<WorldState, "clock">, at: { day: number; minute: number }): string {
  const hour = `${Math.floor(at.minute / 60)}h${at.minute % 60 ? String(at.minute % 60).padStart(2, "0") : ""}`
  const diff = at.day - world.clock.day
  const day = diff === 0 ? "hoje" : diff === 1 ? "amanhã" : onWeekday(at.day)
  return `${day}, às ${hour}`
}
const dueText = (world: Pick<WorldState, "clock">, day: number): string => {
  const diff = day - world.clock.day
  return diff <= 0 ? "hoje" : diff === 1 ? "amanhã" : weekdayOf({ day, minute: 0 })
}

// ---------------- migração e liderança ----------------

/** v6 -> v7: líderes por empresa, local de trabalho do contrato atual e agenda de entrevistas vazia. */
export function upgradeWorldV6(base: WorldStateV6): WorldStateV7 {
  // os ajudantes trabalham sobre o formato atual; campos de versões futuras ficam vazios e saem no fim
  let world = { ...base, schemaVersion: 8, employment: null, leaders: {}, work: { scene: null, interviews: [] }, bodies: {}, wardrobes: {}, gym: null } as unknown as WorldState
  world = ensureLeaders(world, false)
  if (base.employment) {
    const e = base.employment
    const day = base.clock.day
    world = { ...world, employment: { ...e, workplace: newWorkplace(world, e.companyId, e.roleId, false, {
      totalShifts: e.shiftsWorked, nextReviewDay: nextWeekday(Math.max(e.requiredFromDay, day) + 14) }) } }
    world = linkManager(world)
  }
  const { bodies: _bodies, wardrobes: _wardrobes, gym: _gym, ...v7 } = world
  return { ...v7, schemaVersion: 7 }
}

/** Garante uma pessoa responsável por equipe em cada empresa; troca quando ela sai (bíblia §15.1, §15.7). */
export function ensureLeaders(world: WorldState, announce = true): WorldState {
  let next = world
  for (const companyId of Object.keys(world.companies).sort() as CompanyId[]) {
    const current = next.leaders[companyId]
    if (current && next.residents[current]?.job?.companyId === companyId) continue
    const staff = Object.entries(next.residents).filter(([, r]) => r.job?.companyId === companyId)
      .sort(([a, ra], [b, rb]) => absoluteMinute(ra.job!.since) - absoluteMinute(rb.job!.since) || (a < b ? -1 : 1))
    let leaderId = staff[0]?.[0] as PersonId | undefined
    if (!leaderId) {
      // empresa sem ninguém: alguém experiente da cidade assume
      const candidate = Object.entries(next.residents).filter(([id, r]) => { const age = ageAt(next.people[id]!.birthDate, next.clock); return !r.job && age >= 28 && age <= 60 })
        .sort(([a], [b]) => (a < b ? -1 : 1))[0]
      if (!candidate) continue
      leaderId = candidate[0] as PersonId
      const role = jobRoles.filter(r => roleCareer[r.id]?.next === null)[0] ?? jobRoles[0]!
      next = { ...next, residents: { ...next.residents, [leaderId]: { ...candidate[1], goal: null, job: { companyId, roleId: role.id, since: next.clock, satisfaction: 60 } } } }
    }
    next = { ...next, leaders: { ...next.leaders, [companyId]: leaderId } }
    if (next.employment?.companyId === companyId && next.employment.workplace.managerId !== leaderId) {
      next = { ...next, employment: { ...next.employment, workplace: { ...next.employment.workplace, managerId: leaderId, trust: 50 } } }
      next = linkManager(next)
      if (announce) next = appendEntry(next, { at: next.clock, kind: "career", text: `${next.people[leaderId]!.name} passou a responder pela equipe ${inPlace(next.companies[companyId]!.name)}. A confiança vai ter que ser construída de novo.`, personIds: [next.playerId, leaderId], cause: `work.leader:${companyId}:${leaderId}` })
    }
  }
  return next
}

/** Quem responde pela equipe entra no círculo do jogador como colega (bíblia §61: "Seu gestor"). */
function linkManager(world: WorldState): WorldState {
  const managerId = world.employment?.workplace.managerId
  if (!managerId || relationshipBetween(world, world.playerId, managerId)) return world
  const relId = `relationship:coworker:${world.playerId}:${managerId}` as RelationshipId
  const player = world.people[world.playerId]!, manager = world.people[managerId]!
  return { ...world,
    relationships: { ...world.relationships, [relId]: { id: relId, a: world.playerId, b: managerId, familiarity: 10, affection: 30, trust: 35, respect: 55, attraction: 0, resentment: 0, tags: ["coworker"], since: world.clock } },
    people: { ...world.people, [player.id]: { ...player, relationshipIds: [...player.relationshipIds, relId] }, [managerId]: { ...manager, relationshipIds: [...manager.relationshipIds, relId] } },
    tiers: { ...world.tiers, [managerId]: "close" } }
}

function newWorkplace(world: WorldState, companyId: CompanyId, roleId: string, referral: boolean, patch: Partial<Workplace> = {}): Workplace {
  return { managerId: world.leaders[companyId]!, trust: referral ? 58 : 50, salaryCents: roleOf(roleId)!.salaryCents, totalShifts: 0,
    lateThisMonth: 0, absencesThisMonth: 0, warnings: 0, lateToday: false, assignment: null, delivered: 0, missed: 0,
    nextReviewDay: nextWeekday(world.clock.day + workRules.reviewEveryDays), prepared: false, recentSituations: [], promotion: null, ...patch }
}

/** Contratação do jogador (entrevista aprovada ou começo com emprego). */
export function hirePlayer(world: WorldState, companyId: CompanyId, roleId: string, vacancyId: VacancyId | null, referral: boolean): WorldState {
  const id = `employment:${world.nextId}` as EmploymentId
  let next: WorldState = { ...world, nextId: world.nextId + 1 }
  // a vaga ocupada fica registrada; sem vaga (começo da campanha), cria-se a do contrato
  let vid = vacancyId
  if (!vid || !next.vacancies[vid]) {
    vid = `vacancy:${next.nextId}` as VacancyId
    next = { ...next, nextId: next.nextId + 1 }
  }
  next = { ...next, vacancies: { ...next.vacancies, [vid]: { id: vid, companyId, roleId, open: false } } }
  next = ensureLeaders(next, false)
  const requiredFromDay = nextWeekday(world.clock.day + 1)
  const employment: EmploymentV7 = { id, personId: world.playerId, companyId, roleId, startedAt: world.clock, lastWorkedDay: null, accruedCents: 0, shiftsWorked: 0, performance: 60,
    requiredFromDay, consecutiveAbsences: 0, lastAssessedDay: null,
    workplace: newWorkplace(next, companyId, roleId, referral, { nextReviewDay: nextWeekday(requiredFromDay + workRules.reviewEveryDays) }) }
  next = { ...next, employment }
  next = linkManager(meetCoworkers(scheduleWorkDay(next, requiredFromDay), companyId))
  // outras entrevistas marcadas perdem o sentido
  const others = next.work.interviews.filter(i => i.status === "scheduled" && !i.internal)
  if (others.length) next = { ...next, work: { ...next.work, interviews: next.work.interviews.map(i => others.includes(i) ? { ...i, status: "canceled" as const } : i) },
    scheduled: next.scheduled.filter(s => !(s.kind === "interview" && others.some(i => i.id === s.interviewId))) }
  return next
}

// ---------------- turno ----------------

export function coworkersAtWork(world: WorldState): PersonId[] {
  const e = world.employment
  if (!e) return []
  return Object.values(world.relationships).filter(r => (r.a === world.playerId || r.b === world.playerId) && r.tags.includes("coworker"))
    .map(r => (r.a === world.playerId ? r.b : r.a)).filter(id => id !== e.workplace.managerId && world.residents[id]?.job?.companyId === e.companyId).sort()
}

function conditionHolds(world: WorldState, s: WorkSituation): boolean {
  const e = world.employment!, w = e.workplace, when = s.when
  if (!when) return true
  const needs = world.people[world.playerId]!.needs
  if (when.lowEnergy && needs.energy >= 35) return false
  if (when.weakCompany && (world.economy[e.companyId]?.health ?? .5) >= .4) return false
  if (when.assignmentDue && !(w.assignment && w.assignment.progress < w.assignment.needed && w.assignment.dueDay - world.clock.day <= 1)) return false
  if (when.late && !w.lateToday) return false
  if (when.minTrust !== undefined && w.trust < when.minTrust) return false
  if (when.minShifts !== undefined && w.totalShifts < when.minShifts) return false
  return true
}
const mentionsCoworker = (s: WorkSituation): boolean => s.actor === "coworker" || JSON.stringify(s).includes("{coworker}")

/** Abre o momento do turno. Situações ligadas ao que está acontecendo (prazo, atraso, crise) pesam mais. */
export function openShiftScene(world: WorldState, remainingMinutes: number, shiftDay: number): WorldState {
  const e = world.employment!, family = familyOf(e.roleId)
  const coworkers = coworkersAtWork(world)
  const pool = workSituations.filter(s => (s.family === family || s.family === "geral") && !e.workplace.recentSituations.includes(s.id) &&
    conditionHolds(world, s) && (!mentionsCoworker(s) || coworkers.length > 0))
  if (!pool.length) return finishShift(world, shiftDay)
  const weights = pool.map(s => (s.when ? 3 : 1))
  const roll = draw(world.seed, world.rng, "career")
  let pick = roll.value * weights.reduce((a, b) => a + b, 0), situation = pool[0]!
  for (let i = 0; i < pool.length; i++) { pick -= weights[i]!; if (pick <= 0) { situation = pool[i]!; break } }
  const coworker = coworkers.length ? coworkers[hashText(`${world.seed}/${situation.id}/${world.clock.day}`) % coworkers.length]! : null
  const actorId = situation.actor === "manager" ? e.workplace.managerId : situation.actor === "coworker" ? coworker : null
  const scene: WorkScene = { id: `scene:${world.nextId}` as SceneId, kind: "shift", situationId: situation.id, at: world.clock, actorId, interviewId: null, remainingMinutes, shiftDay }
  return { ...world, rng: roll.state, nextId: world.nextId + 1, work: { ...world.work, scene },
    employment: { ...e, workplace: { ...e.workplace, recentSituations: [...e.workplace.recentSituations, situation.id].slice(-workRules.recentSituations) } } }
}

/** Valores usados nos textos de uma cena. */
export function sceneValues(world: WorldState, scene: Pick<WorkScene, "actorId" | "interviewId" | "kind">): Record<string, string> {
  const e = world.employment
  const interview = scene.interviewId ? world.work.interviews.find(i => i.id === scene.interviewId) : undefined
  const companyId = interview?.companyId ?? e?.companyId
  const managerId = interview ? world.leaders[interview.companyId] : e?.workplace.managerId
  const coworkerId = scene.kind === "shift" && scene.actorId && scene.actorId !== managerId ? scene.actorId : coworkersAtWork(world)[0]
  const next = e ? roleCareer[e.roleId]?.next : null
  const roleId = interview?.roleId ?? e?.workplace.promotion?.roleId ?? next ?? e?.roleId
  return {
    company: companyId ? world.companies[companyId]!.name : "", manager: managerId ? first(world.people[managerId]!.name) : "a equipe",
    coworker: coworkerId ? first(world.people[coworkerId]!.name) : "alguém da equipe", role: roleId ? (roleOf(roleId)?.title.toLowerCase() ?? "") : "",
    task: e?.workplace.assignment?.title ?? "a tarefa", due: e?.workplace.assignment ? dueText(world, e.workplace.assignment.dueDay) : "",
  }
}

/** Chance de dar certo, dita em palavras (bíblia §7.2). */
export function riskOf(world: WorldState, choice: Pick<WorkChoice, "difficulty">, skill: "organization" | "communication"): { chance: number; hint: string | null } {
  if (choice.difficulty === undefined) return { chance: 1, hint: null }
  const level = world.skills[world.playerId]![skill]
  const tired = world.people[world.playerId]!.needs.energy < 25 ? .12 : 0
  const chance = clamp(.55 + (level - choice.difficulty) * 2.2 - tired, .08, .95)
  return { chance, hint: chance >= .75 ? "você se sente preparado para isso" : chance >= .45 ? "pode dar certo" : "arriscado" }
}

function applyEffect(world: WorldState, effect: WorkEffect, actorId: PersonId | null, text: string, cause: string): WorldState {
  let next = world
  const e = next.employment
  if (e) {
    const w = e.workplace
    const assignment = w.assignment ? { ...w.assignment, progress: Math.min(w.assignment.needed, w.assignment.progress + (effect.progress ?? 0)), dueDay: w.assignment.dueDay + (effect.extendDue ?? 0) } : null
    next = { ...next, employment: { ...e, performance: nudge(e.performance, effect.performance ?? 0), workplace: { ...w, trust: nudge(w.trust, effect.trust ?? 0), assignment } } }
    if (effect.practice) {
      const skill = roleOf(e.roleId)!.skill, skills = next.skills[next.playerId]!
      next = { ...next, skills: { ...next.skills, [next.playerId]: { ...skills, [skill]: Math.min(1, skills[skill] + effect.practice) } } }
    }
  }
  next = changeNeeds(next, { energy: effect.energy ?? 0, stress: effect.stress ?? 0, hunger: effect.hunger ?? 0 })
  if ((effect.hunger ?? 0) < 0) next = eat(next, -effect.hunger! * bodyRules.kcalPerHunger)
  if (effect.moneyCents) next = postLedger(next, { amountCents: effect.moneyCents, category: "food", text: "Almoço com a equipe", cause })
  if (actorId && (effect.coworker || effect.trust)) {
    const rel = relationshipBetween(next, next.playerId, actorId)
    const change = effect.coworker ?? Math.sign(effect.trust ?? 0)
    if (rel) next = updateRelationship(next, rel.id, { affection: change, trust: Math.round(change / 2), familiarity: 1 }, next.clock)
    if (Math.abs(change) >= 2) next = remember(next, actorId, next.playerId, text, cause)
  }
  return next
}

/** Resolve a escolha do momento do turno; devolve o mundo e os minutos que o turno ainda dura. */
export function resolveShiftChoice(world: WorldState, choice: WorkChoice): { world: WorldState; minutes: number } {
  const scene = world.work.scene!, e = world.employment!
  const skill = roleOf(e.roleId)!.skill
  let next: WorldState = { ...world, work: { ...world.work, scene: null } }
  let outcome = choice.success
  if (choice.difficulty !== undefined && choice.failure) {
    const roll = draw(world.seed, next.rng, "career")
    next = { ...next, rng: roll.state }
    if (roll.value >= riskOf(world, choice, skill).chance) outcome = choice.failure
  }
  const text = fillText(outcome.text, sceneValues(world, scene))
  const cause = `work.moment:${scene.situationId}:${scene.id}`
  next = applyEffect(next, outcome.effect, scene.actorId, text, cause)
  next = appendEntry(next, { at: next.clock, kind: "career", text, personIds: [next.playerId, ...(scene.actorId ? [scene.actorId] : [])], cause })
  return { world: next, minutes: scene.remainingMinutes + (choice.minutes ?? 0) }
}

/** Fim do turno: pagamento, experiência, tarefa, e a conversa do mês quando chega a hora. */
export function finishShift(world: WorldState, shiftDay: number): WorldState {
  const e = world.employment!, w = e.workplace, role = roleOf(e.roleId)!
  const skill = world.skills[world.playerId]![role.skill]
  const needs = world.people[world.playerId]!.needs
  const strain = (needs.energy < 20 ? 3 : 0) + (needs.hunger >= 75 ? 2 : 0) + (needs.sleepPressure >= 80 ? 2 : 0) + (needs.stress >= 70 ? 2 : 0)
  // o desempenho tende ao que o preparo sustenta; cansaço, fome e sono puxam para baixo (bíblia §15.4)
  const target = clamp(42 + skill * 60 - strain * 5)
  const performance = clamp(e.performance + (target - e.performance) * .1)
  const assignment = w.assignment ? { ...w.assignment, progress: Math.min(w.assignment.needed, w.assignment.progress + 1) } : null
  const condition = needs.sleepPressure >= 80 ? " O sono dificultou a concentração." : needs.hunger >= 75 ? " A fome atrapalhou a segunda parte do turno." : needs.energy < 20 ? " Você terminou o expediente sem disposição." : ""
  // a experiência também ensina, devagar
  const skills = world.skills[world.playerId]!
  let next: WorldState = { ...world, skills: { ...world.skills, [world.playerId]: { ...skills, [role.skill]: Math.min(1, skills[role.skill] + .003) } },
    employment: { ...e, lastWorkedDay: shiftDay, consecutiveAbsences: 0, accruedCents: e.accruedCents + Math.round(w.salaryCents / 20), shiftsWorked: e.shiftsWorked + 1, performance,
      workplace: { ...w, totalShifts: w.totalShifts + 1, assignment, lateToday: false } } }
  next = burn(next, bodyRules.shiftKcal[familyOf(e.roleId)] ?? 150)
  next = appendEntry(next, { at: next.clock, kind: "career", text: `Turno encerrado ${inPlace(world.companies[e.companyId]!.name)}.${condition}`, personIds: [world.playerId], cause: `career.shift:${e.id}` })
  next = settleAssignment(next, true)
  next = giveAssignment(next)
  if (next.employment && next.clock.day >= next.employment.workplace.nextReviewDay) next = openReview(next)
  return next
}

// ---------------- tarefa da semana ----------------

function giveAssignment(world: WorldState): WorldState {
  const e = world.employment
  if (!e || e.workplace.assignment) return world
  const templates = assignmentTemplates[familyOf(e.roleId)]
  const template = templates[hashText(`${world.seed}/task/${e.id}/${world.clock.day}`) % templates.length]!
  // um dia útil de folga além do necessário
  let dueDay = world.clock.day
  for (let n = 0; n < template.needed + 1; n++) dueDay = nextWeekday(dueDay + 1)
  const assignment = { templateId: template.id, title: template.title, givenDay: world.clock.day, dueDay, needed: template.needed, progress: 0 }
  const next: WorldState = { ...world, employment: { ...e, workplace: { ...e.workplace, assignment } } }
  const manager = next.people[e.workplace.managerId]!
  return appendEntry(next, { at: next.clock, kind: "career", text: `${first(manager.name)} passou a tarefa da semana: ${template.title}, até ${dueText(next, dueDay)}.`, personIds: [next.playerId, manager.id], cause: `work.assignment:${e.id}:${world.clock.day}` })
}

/** Entrega ou atraso da tarefa; chamado no fim do turno e na checagem diária de presença. */
export function settleAssignment(world: WorldState, endOfShift = false): WorldState {
  const e = world.employment
  const a = e?.workplace.assignment
  if (!e || !a) return world
  const done = a.progress >= a.needed, overdue = world.clock.day > a.dueDay || (endOfShift && world.clock.day >= a.dueDay)
  if (!done && !overdue) return world
  const w = e.workplace
  const next: WorldState = { ...world, employment: { ...e, performance: nudge(e.performance, done ? 3 : -4),
    workplace: { ...w, assignment: null, trust: nudge(w.trust, done ? 3 : -6), delivered: w.delivered + (done ? 1 : 0), missed: w.missed + (done ? 0 : 1) } } }
  const manager = first(world.people[w.managerId]!.name)
  return appendEntry(next, { at: next.clock, kind: "career", text: done ? `Você entregou ${a.title} dentro do prazo. ${manager} conferiu e não pediu nada de volta.` : `O prazo para ${a.title} passou sem a entrega. ${manager} cobrou na frente da equipe.`,
    personIds: [next.playerId, w.managerId], cause: `work.assignment-${done ? "done" : "missed"}:${e.id}:${a.givenDay}` })
}

// ---------------- conversa do mês ----------------

function openReview(world: WorldState): WorldState {
  const e = world.employment!
  if (world.work.scene) return world
  const scene: WorkScene = { id: `scene:${world.nextId}` as SceneId, kind: "review", situationId: "review", at: world.clock, actorId: e.workplace.managerId, interviewId: null, remainingMinutes: 0, shiftDay: null }
  return { ...world, nextId: world.nextId + 1, work: { ...world.work, scene } }
}

type ReviewChoiceId = "raise" | "responsibility" | "listen" | "explain"
export function reviewEvaluation(world: WorldState): { bad: boolean; good: boolean; facts: string[] } {
  const e = world.employment!, w = e.workplace
  const bad = e.performance < 40 || w.lateThisMonth >= 4 || w.absencesThisMonth >= 2 || w.missed >= 2
  const good = !bad && e.performance >= 60 && w.lateThisMonth <= 1 && w.absencesThisMonth === 0 && w.missed === 0
  const v = { manager: first(world.people[w.managerId]!.name), count: w.lateThisMonth === 1 ? "uma vez" : `${w.lateThisMonth} vezes` }
  const facts = [fillText(reviewTexts.intro, v), w.prepared ? reviewTexts.prepared : reviewTexts.unprepared]
  if (w.lateThisMonth) facts.push(fillText(reviewTexts.late, v))
  if (w.absencesThisMonth) facts.push(fillText(reviewTexts.absences, v))
  if (w.delivered) facts.push(reviewTexts.delivered)
  if (w.missed) facts.push(fillText(reviewTexts.missed, v))
  facts.push(fillText(bad ? reviewTexts.weak : good ? reviewTexts.good : "{manager} disse que o mês foi razoável.", v))
  return { bad, good, facts }
}

export function reviewChoices(world: WorldState): { id: ReviewChoiceId; label: string; available: boolean; reason: string | null }[] {
  const e = world.employment!, w = e.workplace
  const tenure = world.clock.day - e.startedAt.day
  const { bad } = reviewEvaluation(world)
  const out: { id: ReviewChoiceId; label: string; available: boolean; reason: string | null }[] = []
  out.push({ id: "raise", label: reviewTexts.choices.raise.label, available: !bad && tenure >= workRules.raiseMinDays, reason: bad ? "Não depois de um mês assim." : tenure < workRules.raiseMinDays ? "Ainda é cedo: pouco tempo de casa." : null })
  out.push({ id: "responsibility", label: reviewTexts.choices.responsibility.label, available: !bad && !w.promotion, reason: bad ? "Não depois de um mês assim." : w.promotion ? "Já existe um processo interno aberto." : null })
  out.push({ id: "listen", label: reviewTexts.choices.listen.label, available: true, reason: null })
  if (w.lateThisMonth >= 2 || w.absencesThisMonth || w.missed) out.push({ id: "explain", label: reviewTexts.choices.explain.label, available: true, reason: null })
  return out
}

/** O que falta para o próximo degrau, em palavras. */
export function promotionGaps(world: WorldState): string[] {
  const e = world.employment!, w = e.workplace
  const nextId = roleCareer[e.roleId]?.next
  if (!nextId) return []
  const nextRole = roleOf(nextId)!
  const gaps: string[] = []
  if (world.clock.day - e.startedAt.day < workRules.promotionMinDays) gaps.push("mais tempo de casa")
  if (world.skills[world.playerId]![nextRole.skill] < nextRole.required) gaps.push(`preparo em ${nextRole.skill === "organization" ? "organização" : "comunicação"}`)
  if (w.trust < 60) gaps.push("mais confiança da liderança")
  if (e.performance < 60) gaps.push("um desempenho mais constante")
  if ((world.economy[e.companyId]?.health ?? .5) < .4) gaps.push("a empresa sair da fase ruim")
  return gaps
}

export function resolveReview(world: WorldState, choiceId: ReviewChoiceId): WorldState {
  const e = world.employment!, w = e.workplace
  const { bad, good, facts } = reviewEvaluation(world)
  const nextRoleId = roleCareer[e.roleId]?.next ?? null
  const v: Record<string, string> = { manager: first(world.people[w.managerId]!.name), role: nextRoleId ? roleOf(nextRoleId)!.title.toLowerCase() : "", percent: `${Math.round(workRules.raise * 100)}%` }
  let trust = w.trust + (bad ? -4 : good ? 4 : 0), salary = w.salaryCents, warnings = w.warnings + (bad ? 1 : 0), promotion = w.promotion
  let next: WorldState = { ...world, work: { ...world.work, scene: null } }
  const lines = [...facts]
  if (bad) lines.push(warnings >= workRules.warningLimit ? reviewTexts.secondWarning : fillText(reviewTexts.warning, v))
  const roll = draw(world.seed, next.rng, "career")
  next = { ...next, rng: roll.state }
  const texts = reviewTexts.choices
  if (choiceId === "raise") {
    const weak = (world.economy[e.companyId]?.health ?? .5) < .4
    const chance = clamp(.25 + (e.performance - 60) / 80 + (w.trust - 50) / 100 + (w.prepared ? .15 : 0), .05, .9)
    if (weak) lines.push(fillText(texts.raise.weakCompany, v))
    else if (roll.value < chance) { salary = Math.round(salary * (1 + workRules.raise)); lines.push(fillText(texts.raise.success, v)) }
    else { trust -= 1; lines.push(fillText(texts.raise.failure, v)) }
  } else if (choiceId === "responsibility") {
    if (!nextRoleId) lines.push(fillText(texts.responsibility.noNext, v))
    else {
      const gaps = promotionGaps(world)
      if (gaps.length) lines.push(fillText(texts.responsibility.failure, { ...v, missing: gaps.join(", ") }))
      else { promotion = { roleId: nextRoleId, untilDay: world.clock.day + workRules.promotionWindowDays, applied: false }; lines.push(fillText(texts.responsibility.success, v)); trust += 2 }
    }
  } else if (choiceId === "listen") {
    trust += 2
    const skill = roleOf(e.roleId)!.skill, skills = next.skills[next.playerId]!
    next = { ...next, skills: { ...next.skills, [next.playerId]: { ...skills, [skill]: Math.min(1, skills[skill] + .01) } } }
    lines.push(fillText(texts.listen.success, v))
  } else {
    if (w.prepared) { trust += 2; lines.push(fillText(texts.explain.success, v)) } else lines.push(fillText(texts.explain.failure, v))
  }
  // promoção oferecida sem pedir, quando o mês foi muito bom (bíblia §15.5)
  if (!promotion && good && nextRoleId && trust >= 75 && !promotionGaps({ ...world, employment: { ...e, workplace: { ...w, trust } } }).length) {
    promotion = { roleId: nextRoleId, untilDay: world.clock.day + workRules.promotionWindowDays, applied: false }
    lines.push(fillText(reviewTexts.offer, v))
  }
  const ee = next.employment!
  next = { ...next, employment: { ...ee, workplace: { ...ee.workplace, trust: nudge(w.trust, trust - w.trust), salaryCents: salary, warnings, promotion,
    lateThisMonth: 0, absencesThisMonth: 0, delivered: 0, missed: 0, prepared: false, nextReviewDay: nextWeekday(world.clock.day + workRules.reviewEveryDays) } } }
  const rel = relationshipBetween(next, next.playerId, w.managerId)
  if (rel) next = updateRelationship(next, rel.id, { familiarity: 2, trust: bad ? -2 : 1 }, next.clock)
  next = appendEntry(next, { at: next.clock, kind: "career", text: lines.join(" "), personIds: [next.playerId, w.managerId], cause: `work.review:${e.id}:${world.clock.day}` })
  if (bad && warnings >= workRules.warningLimit) next = dismissForPerformance(next)
  return next
}

function dismissForPerformance(world: WorldState): WorldState {
  const e = world.employment!, company = world.companies[e.companyId]!
  let next = world
  if (e.accruedCents > 0) next = postLedger(next, { amountCents: e.accruedCents, category: "salary", text: `Acerto dos turnos · ${company.name}`, cause: `career.settlement:${e.id}` })
  next = { ...next, employment: null,
    employmentHistory: [...next.employmentHistory, { id: e.id, companyId: e.companyId, roleId: e.roleId, startedAt: e.startedAt, endedAt: world.clock, reason: "performance", settledCents: e.accruedCents }],
    vacancies: reopenPost(next, e.companyId, e.roleId),
    scheduled: next.scheduled.filter(item => item.employmentId !== e.id) }
  next = changeNeeds(next, { stress: 18 })
  return appendEntry(next, { at: next.clock, kind: "career", text: `${company.name} encerrou seu contrato depois de duas conversas difíceis seguidas.${e.accruedCents > 0 ? ` Os turnos cumpridos foram pagos: ${formatMoney(e.accruedCents)}.` : ""} ${first(world.people[e.workplace.managerId]!.name)} desejou sorte na saída.`,
    personIds: [next.playerId, e.workplace.managerId], cause: `career.performance:${e.id}` })
}

function reopenPost(world: WorldState, companyId: CompanyId, roleId: string): WorldState["vacancies"] {
  const existing = Object.values(world.vacancies).find(v => v.companyId === companyId && v.roleId === roleId && !v.open)
  return existing ? { ...world.vacancies, [existing.id]: { ...existing, open: true } } : world.vacancies
}

// ---------------- entrevistas ----------------

export function interviewReason(world: WorldState, vacancyId: VacancyId): string | null {
  const pending = world.work.interviews.find(i => i.vacancyId === vacancyId && (i.status === "scheduled" || i.status === "awaiting"))
  if (pending?.status === "scheduled") return `Sua entrevista já está marcada: ${whenText(world, pending.at)}.`
  if (pending?.status === "awaiting") return "A empresa ainda vai dar a resposta da entrevista."
  return null
}

/** Candidatura vira entrevista marcada (bíblia §15.3). */
export function scheduleInterview(world: WorldState, companyId: CompanyId, roleId: string, vacancyId: VacancyId | null, internal: boolean): WorldState {
  const day = nextWeekday(world.clock.day + 1)
  const minute = workRules.interviewHours[hashText(`${world.seed}/interview/${world.nextId}`) % workRules.interviewHours.length]!
  const id = `interview:${world.nextId}` as InterviewId
  const interview: Interview = { id, vacancyId, companyId, roleId, internal, at: { day, minute }, prepared: false, status: "scheduled", score: null }
  const event: ScheduledEvent = { id: `schedule:${id}` as ScheduleId, kind: "interview", at: { day, minute }, personId: world.playerId, interviewId: id, interrupts: true }
  const next: WorldState = { ...world, nextId: world.nextId + 1, work: { ...world.work, interviews: [...world.work.interviews, interview].slice(-40) }, scheduled: [...world.scheduled, event] }
  const company = world.companies[companyId]!
  return appendEntry(next, { at: next.clock, kind: "career", text: internal ? `O processo interno para ${roleOf(roleId)!.title.toLowerCase()} ficou marcado: entrevista ${whenText(next, event.at)}.`
    : fillText(interviewTexts.scheduled, { company: company.name, when: whenText(next, event.at) }), personIds: [next.playerId], cause: `work.interview-scheduled:${id}` })
}

export function processInterviewEvent(world: WorldState, event: ScheduledEvent): WorldState {
  const interview = world.work.interviews.find(i => i.id === event.interviewId)
  if (!interview) return world
  const company = world.companies[interview.companyId]!
  const set = (w: WorldState, status: Interview["status"], score: number | null = interview.score): WorldState =>
    ({ ...w, work: { ...w.work, interviews: w.work.interviews.map(i => (i.id === interview.id ? { ...i, status, score } : i)) } })
  if (event.kind === "interview-result") return interviewResult(world, interview)
  if (interview.status !== "scheduled") return world
  if (!interview.internal && (!interview.vacancyId || !world.vacancies[interview.vacancyId]?.open))
    return appendEntry(set(world, "canceled"), { at: world.clock, kind: "career", text: fillText(interviewTexts.canceled, { company: company.name }), personIds: [world.playerId], cause: `work.interview-canceled:${interview.id}` })
  if (world.work.scene) return appendEntry(set(world, "missed"), { at: world.clock, kind: "career", text: fillText(interviewTexts.missed, { company: company.name }), personIds: [world.playerId], cause: `work.interview-missed:${interview.id}` })
  const scene: WorkScene = { id: `scene:${world.nextId}` as SceneId, kind: "interview", situationId: `interview:${familyOf(interview.roleId)}`, at: world.clock, actorId: world.leaders[interview.companyId] ?? null, interviewId: interview.id, remainingMinutes: 45, shiftDay: null }
  return { ...world, nextId: world.nextId + 1, work: { ...world.work, scene } }
}

const hasExperience = (world: WorldState, roleId: string): boolean => {
  const family = familyOf(roleId)
  return world.employmentHistory.some(r => familyOf(r.roleId) === family) || (world.employment ? familyOf(world.employment.roleId) === family : false)
}
const relevantCourse = (world: WorldState, roleId: string) => {
  const skill = roleOf(roleId)!.skill
  return courses.find(c => c.skill === skill && (world.training[`course:${c.id}`]?.sessions ?? 0) >= 3)
}

type InterviewChoiceId = "experience" | "motivation" | "course" | "team"
export function interviewChoices(world: WorldState, interview: Interview): { id: InterviewChoiceId; label: string; difficulty: number; skill: "organization" | "communication" }[] {
  const role = roleOf(interview.roleId)!
  const out: { id: InterviewChoiceId; label: string; difficulty: number; skill: "organization" | "communication" }[] = [
    { id: "experience", label: interviewTexts.choices.experience.label, difficulty: hasExperience(world, interview.roleId) ? .15 : .55, skill: role.skill },
    { id: "motivation", label: interviewTexts.choices.motivation.label, difficulty: .35, skill: "communication" },
  ]
  if (relevantCourse(world, interview.roleId)) out.push({ id: "course", label: interviewTexts.choices.course.label, difficulty: .2, skill: role.skill })
  else out.push({ id: "team", label: interviewTexts.choices.team.label, difficulty: .2, skill: "communication" })
  return out
}

/** Concorrência: quem na cidade procura trabalho e poderia ocupar a vaga (bíblia §15.3). */
export function competitionFor(world: WorldState, roleId: string): number {
  const role = roleOf(roleId)!
  return Object.entries(world.residents).filter(([id, r]) => !r.job && r.goal?.kind === "find-job" && (world.skills[id]?.[role.skill] ?? 0) >= role.required * .8).length
}

export function resolveInterviewChoice(world: WorldState, choiceId: InterviewChoiceId): WorldState {
  const scene = world.work.scene!, interview = world.work.interviews.find(i => i.id === scene.interviewId)!
  const role = roleOf(interview.roleId)!
  const choice = interviewChoices(world, interview).find(c => c.id === choiceId)!
  const { chance } = riskOf(world, choice, choice.skill)
  let next: WorldState = { ...world, work: { ...world.work, scene: null } }
  const r1 = draw(world.seed, next.rng, "career")
  next = { ...next, rng: r1.state }
  const went = r1.value < chance
  const referral = !interview.internal && interview.vacancyId ? world.inbox.some(m => m.topic === "job-tip" && m.vacancyId === interview.vacancyId && m.status === "answered") : false
  const skill = world.skills[world.playerId]![role.skill]
  const trust = interview.internal && world.employment ? world.employment.workplace.trust : 50
  const score = clamp(.28 + skill * .5 + (interview.prepared ? .15 : 0) + (referral ? .2 : 0) + (hasExperience(world, interview.roleId) ? .08 : 0) +
    (went ? (choiceId === "team" ? .06 : .14) : -.06) - Math.min(.15, competitionFor(world, interview.roleId) * .025) + (presenceOf(world, world.playerId) - .5) * .25 + (interview.internal ? (trust - 55) / 150 : 0), .03, .95)
  const texts = interviewTexts.choices[choiceId]
  const v = sceneValues(world, scene)
  const intro = fillText(interview.internal ? interviewTexts.internal : interviewTexts.intro[familyOf(interview.roleId)], v)
  next = { ...next, work: { ...next.work, interviews: next.work.interviews.map(i => (i.id === interview.id ? { ...i, status: "awaiting" as const, score } : i)) } }
  next = changeNeeds(next, { stress: went ? -2 : 5, energy: -3 })
  next = appendEntry(next, { at: next.clock, kind: "career", text: `${intro} ${fillText(went ? texts.success : texts.failure, v)} A resposta deve vir amanhã.`,
    personIds: [next.playerId, ...(scene.actorId ? [scene.actorId] : [])], cause: `work.interview:${interview.id}` })
  const at = { day: next.clock.day + 1, minute: 660 }
  return { ...next, scheduled: [...next.scheduled, { id: `schedule:${interview.id}:result` as ScheduleId, kind: "interview-result", at, personId: next.playerId, interviewId: interview.id, interrupts: true }] }
}

function interviewResult(world: WorldState, interview: Interview): WorldState {
  if (interview.status !== "awaiting") return world
  const roll = draw(world.seed, world.rng, "career")
  let next: WorldState = { ...world, rng: roll.state }
  const passed = roll.value < (interview.score ?? 0)
  const company = world.companies[interview.companyId]!, role = roleOf(interview.roleId)!
  next = { ...next, work: { ...next.work, interviews: next.work.interviews.map(i => (i.id === interview.id ? { ...i, status: passed ? "passed" as const : "failed" as const } : i)) } }
  const v: Record<string, string> = { company: company.name, role: role.title.toLowerCase(), manager: first(world.people[world.leaders[interview.companyId]!]?.name ?? "") }
  if (interview.internal) {
    const e = next.employment
    if (!e || e.companyId !== interview.companyId) return next
    if (!passed) {
      next = { ...next, employment: { ...e, workplace: { ...e.workplace, promotion: null, trust: clamp(e.workplace.trust + 1) } } }
      return appendEntry(next, { at: next.clock, kind: "career", text: fillText(interviewTexts.notPromoted, v), personIds: [next.playerId], cause: `work.promotion-denied:${interview.id}` })
    }
    return promote(next, interview.roleId)
  }
  if (interview.vacancyId) next = { ...next, applications: [...next.applications, { vacancyId: interview.vacancyId, at: next.clock, accepted: passed && !next.employment }] }
  if (!passed || next.employment || !interview.vacancyId || !next.vacancies[interview.vacancyId]?.open)
    return appendEntry(next, { at: next.clock, kind: "career", text: fillText(interviewTexts.failed, v), personIds: [next.playerId], cause: `career.application:${interview.vacancyId ?? interview.id}` })
  const referral = world.inbox.some(m => m.topic === "job-tip" && m.vacancyId === interview.vacancyId && m.status === "answered")
  next = hirePlayer(next, interview.companyId, interview.roleId, interview.vacancyId, referral)
  return appendEntry(next, { at: next.clock, kind: "career", text: `${fillText(interviewTexts.passed, { ...v, start: formatDate({ day: next.employment!.requiredFromDay, minute: 0 }) })} São oito horas por dia útil; o combinado é chegar até as 8h30. Três faltas seguidas encerram o contrato.`,
    personIds: [next.playerId], cause: `career.application:${interview.vacancyId}` })
}

function promote(world: WorldState, roleId: string): WorldState {
  const e = world.employment!, role = roleOf(roleId)!, company = world.companies[e.companyId]!
  let next = world
  // o posto antigo vira vaga de substituição; o novo fica registrado como ocupado
  const newVacancy = `vacancy:${next.nextId}` as VacancyId
  next = { ...next, nextId: next.nextId + 1, vacancies: { ...reopenPost(next, e.companyId, e.roleId), [newVacancy]: { id: newVacancy, companyId: e.companyId, roleId, open: false } } }
  const salary = Math.max(role.salaryCents, Math.round(e.workplace.salaryCents * 1.1))
  next = { ...next, employment: { ...e, roleId, workplace: { ...e.workplace, salaryCents: salary, promotion: null, trust: clamp(e.workplace.trust + 5), assignment: null } } }
  return appendEntry(next, { at: next.clock, kind: "career", text: `${fillText(interviewTexts.promoted, { role: role.title.toLowerCase(), company: company.name })} O salário passa a ${formatMoney(salary)} por mês.`,
    personIds: [next.playerId], cause: `work.promotion:${e.id}:${roleId}` })
}

// ---------------- comandos auxiliares ----------------

export function internalApplicationReason(world: WorldState): string | null {
  const p = world.employment?.workplace.promotion
  if (!p) return "Não há processo interno aberto."
  if (p.applied) return "Sua candidatura interna já está em andamento."
  if (world.clock.day > p.untilDay) return "O prazo do processo interno acabou."
  return null
}
export function applyInternal(world: WorldState): WorldState {
  const e = world.employment!, p = e.workplace.promotion!
  const next: WorldState = { ...world, employment: { ...e, workplace: { ...e.workplace, promotion: { ...p, applied: true } } } }
  return scheduleInterview(next, e.companyId, p.roleId, null, true)
}

export function prepareReason(world: WorldState, target: "review" | "interview", interviewId?: InterviewId): string | null {
  if (target === "review") {
    const w = world.employment?.workplace
    if (!w) return "Você não tem conversa marcada."
    if (w.prepared) return "Você já preparou a conversa deste mês."
    if (w.nextReviewDay - world.clock.day > 3) return "A conversa do mês ainda está longe."
    return null
  }
  const interview = world.work.interviews.find(i => i.id === interviewId)
  if (!interview || interview.status !== "scheduled") return "Não há entrevista marcada."
  if (interview.prepared) return "Você já se preparou para essa entrevista."
  return null
}
export function prepare(world: WorldState, target: "review" | "interview", interviewId?: InterviewId): WorldState {
  if (target === "review") {
    const e = world.employment!
    const next: WorldState = { ...world, employment: { ...e, workplace: { ...e.workplace, prepared: true } } }
    return appendEntry(next, { at: next.clock, kind: "action", text: `Você anotou o que fez no mês e o que quer pedir na conversa com ${first(world.people[e.workplace.managerId]!.name)}.`, personIds: [world.playerId], cause: `work.prepare-review:${e.id}` })
  }
  const interview = world.work.interviews.find(i => i.id === interviewId)!
  const next: WorldState = { ...world, work: { ...world.work, interviews: world.work.interviews.map(i => (i.id === interview.id ? { ...i, prepared: true } : i)) } }
  return appendEntry(next, { at: next.clock, kind: "action", text: `Você pesquisou sobre ${world.companies[interview.companyId]!.name} e ensaiou as respostas em voz alta.`, personIds: [world.playerId], cause: `work.prepare-interview:${interview.id}` })
}

/** Compromisso marcado que uma ação de `minutes` atravessaria (entrevistas). */
export function appointmentConflict(world: WorldState, minutes: number): string | null {
  const now = absoluteMinute(world.clock), end = now + minutes
  const hit = world.work.interviews.find(i => i.status === "scheduled" && absoluteMinute(i.at) > now && absoluteMinute(i.at) < end)
  if (!hit) return null
  return `Você tem entrevista ${inPlace(world.companies[hit.companyId]!.name)} às ${formatTime(hit.at)}. Isso terminaria depois.`
}

/** Checagem diária do trabalho: faltas contam no mês, a confiança cai, prazos vencem. */
export function workDailyCheck(world: WorldState, absent: boolean): WorldState {
  const e = world.employment
  if (!e) return world
  let w = e.workplace
  if (absent) w = { ...w, absencesThisMonth: w.absencesThisMonth + 1, trust: clamp(w.trust - 5) }
  if (w.promotion && !w.promotion.applied && world.clock.day > w.promotion.untilDay) w = { ...w, promotion: null }
  return settleAssignment({ ...world, employment: { ...e, workplace: w } })
}

/** Registra o atraso na chegada. */
export function checkIn(world: WorldState): WorldState {
  const e = world.employment!
  const late = world.clock.minute > workRules.onTimeMinute
  // roupa abaixo do que a função pede também é notada (uma vez por dia, na chegada)
  const gap = dressGap(world)
  let next: WorldState = { ...world, employment: { ...e, lastWorkedDay: world.clock.day, workplace: { ...e.workplace, lateToday: late, lateThisMonth: e.workplace.lateThisMonth + (late ? 1 : 0), trust: clamp(e.workplace.trust - (late ? 2 : 0) - gap) } } }
  if (gap) next = appendEntry(next, { at: next.clock, kind: "career", text: `${first(world.people[e.workplace.managerId]!.name)} olhou para a sua roupa e comentou que aqui se espera algo mais arrumado.`, personIds: [world.playerId, e.workplace.managerId], cause: `work.dress:${e.id}:${world.clock.day}` })
  return next
}


