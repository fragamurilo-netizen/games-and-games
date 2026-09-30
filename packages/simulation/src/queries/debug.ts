// Ferramentas internas (bíblia §42): inspector de pessoa, inspector de evento e estatísticas.
// Read models de depuração: expõem números de propósito e nunca aparecem na interface do jogo.
import { jobRoles, lifeEvents } from "@paralelo/content"
import type { PersonId } from "@paralelo/shared"
import type { WorldState } from "../domain/world"
import { eligibleEvent } from "../systems/events"
import { absoluteMinute, ageAt, formatDate, formatTime } from "../time"

const when = (at: WorldState["clock"]): string => `${formatDate(at)} ${formatTime(at)}`

export function inspectPerson(world: WorldState, id: string) {
  const person = world.people[id]
  if (!person) return null
  const resident = world.residents[id]
  const role = resident?.job ? jobRoles.find(r => r.id === resident.job!.roleId) : undefined
  const other = (a: PersonId, b: PersonId): PersonId => (a === person.id ? b : a)
  return {
    id: person.id, name: person.name, sex: person.sex, age: ageAt(person.birthDate, world.clock), tier: world.tiers[id] ?? (id === world.playerId ? "player" : "background"),
    district: world.residences[person.residenceId]?.district ?? null,
    state: { needs: person.needs, personality: person.personality, skills: world.skills[id] ?? null },
    job: resident?.job ? { company: world.companies[resident.job.companyId]!.name, role: role?.title ?? resident.job.roleId, since: formatDate(resident.job.since), satisfaction: resident.job.satisfaction }
      : id === world.playerId && world.employment ? { company: world.companies[world.employment.companyId]!.name, role: jobRoles.find(r => r.id === world.employment!.roleId)?.title ?? "", since: formatDate(world.employment.startedAt), satisfaction: null }
      : null,
    goal: resident?.goal ? { kind: resident.goal.kind, since: formatDate(resident.goal.since) } : null,
    relationships: person.relationshipIds.map(rid => world.relationships[rid]).filter(r => !!r).map(r => ({
      with: world.people[other(r.a, r.b)]!.name, id: other(r.a, r.b), tags: r.tags,
      familiarity: +r.familiarity.toFixed(1), affection: +r.affection.toFixed(1), trust: +r.trust.toFixed(1), respect: +r.respect.toFixed(1), resentment: +r.resentment.toFixed(1),
      lastInteraction: r.lastInteractionAt ? when(r.lastInteractionAt) : null })),
    memories: world.memories.filter(m => m.personId === id).slice(-10).reverse().map(m => ({ at: when(m.at), about: world.people[m.otherId]?.name ?? m.otherId, text: m.text, salience: +m.salience.toFixed(3) })),
    agenda: world.scheduled.filter(s => s.personId === id).sort((a, b) => absoluteMinute(a.at) - absoluteMinute(b.at)).map(s => ({ at: when(s.at), kind: s.kind })),
    // conhecimento: quem a pessoa conhece e quais mensagens trocou com o jogador
    knows: person.relationshipIds.length,
    messages: world.inbox.filter(m => m.fromId === id).map(m => ({ at: when(m.at), topic: m.topic, status: m.status, text: m.text })),
    lastDecision: resident?.lastDecision ? { at: when(resident.lastDecision.at), goal: resident.lastDecision.goal, chosen: resident.lastDecision.chosen,
      options: [...resident.lastDecision.options].sort((a, b) => b.score - a.score).map(o => ({ action: o.action, score: +o.score.toFixed(3) })) } : null,
  }
}

export function inspectEvents(world: WorldState) {
  const player = world.people[world.playerId]!
  return lifeEvents.map(event => {
    const conditions = event.conditions.map(c => {
      if (c.type === "employed") return { condition: `employed = ${c.value}`, value: String(!!world.employment), ok: !!world.employment === c.value }
      const value = c.type === "money" ? world.finance.balanceCents : player.needs[c.type]
      const ok = (c.min === undefined || value >= c.min) && (c.max === undefined || value <= c.max)
      return { condition: `${c.type} ${c.min !== undefined ? `>= ${c.min}` : ""}${c.min !== undefined && c.max !== undefined ? " e " : ""}${c.max !== undefined ? `<= ${c.max}` : ""}`, value: String(value), ok }
    })
    const seen = world.events.seen.includes(event.id)
    const eligible = eligibleEvent(world, event)
    const blocked = seen ? "já aconteceu" : !event.root ? "só aparece como desdobramento" : world.events.pending ? "outra decisão está pendente"
      : world.events.lastOfferedDay !== null && world.clock.day - world.events.lastOfferedDay < 3 ? "intervalo mínimo de 3 dias entre decisões"
      : !eligible ? (conditions.some(c => !c.ok) ? "condição não atendida" : "sem pessoa para o papel") : null
    return { id: event.id, title: event.title, root: event.root, seen, conditions, eligible: eligible && !seen && event.root, blocked }
  })
}

export function worldStats(world: WorldState) {
  const residents = Object.entries(world.residents)
  const adults = residents.filter(([id]) => { const age = ageAt(world.people[id]!.birthDate, world.clock); return age >= 18 && age <= 64 })
  const unemployed = adults.filter(([, r]) => !r.job).length
  const since = absoluteMinute(world.clock) - 30 * 1440
  const recent = world.finance.ledger.filter(e => absoluteMinute(e.at) >= since)
  const causes = (prefix: string): number => world.news.filter(n => n.cause.startsWith(prefix)).length
  const withJob = residents.filter(([, r]) => r.job)
  return {
    date: when(world.clock), day: world.clock.day,
    population: Object.keys(world.people).length, adults: adults.length,
    unemployment: adults.length ? +(unemployed / adults.length).toFixed(3) : 0,
    satisfaction: withJob.length ? Math.round(withJob.reduce((s, [, r]) => s + r.job!.satisfaction, 0) / withJob.length) : null,
    companies: Object.entries(world.economy).map(([id, e]) => ({ name: world.companies[id]!.name, health: e.health, weakWeeks: e.weakWeeks,
      staff: withJob.filter(([, r]) => r.job!.companyId === id).length, open: Object.values(world.vacancies).filter(v => v.open && v.companyId === id).length })),
    player: { balanceCents: world.finance.balanceCents, income30d: recent.filter(e => e.amountCents > 0).reduce((s, e) => s + e.amountCents, 0),
      spent30d: recent.filter(e => e.amountCents < 0).reduce((s, e) => s - e.amountCents, 0), employed: !!world.employment, jobsLost: world.employmentHistory.length },
    relationships: { total: Object.keys(world.relationships).length, withPlayer: world.people[world.playerId]!.relationshipIds.length },
    news: { total: world.news.length, hires: causes("city.hire"), openings: causes("economy.opening"), layoffs: causes("economy.layoff"), weak: causes("economy.weak") },
    messages: { total: world.inbox.length, unread: world.inbox.filter(m => m.status === "unread").length, answered: world.inbox.filter(m => m.status === "answered").length, ignored: world.inbox.filter(m => m.status === "ignored").length },
    events: { seen: world.events.seen.length, pending: !!world.events.pending },
    size: { timeline: world.timeline.length, memories: world.memories.length, vacancies: Object.keys(world.vacancies).length, bytes: JSON.stringify(world).length },
  }
}
