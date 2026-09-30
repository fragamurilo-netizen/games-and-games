import type { ScheduleId } from "@paralelo/shared"
import { socialTexts, starterContent } from "@paralelo/content"
import type { ScheduledEvent, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, calendarDate, dayFromCalendar } from "../time"
import { appendEntry } from "../timeline"
import { formatMoney, postLedger } from "./finance"
import { remember } from "./memory"
import { updateRelationship } from "./relationships"
import { processLifeEvent } from "./events"
import { processWorkEvent } from "./career"
import { processDailyCity, processWeeklyEconomy } from "./city"
import { processInterviewEvent } from "./work"
import { chargeGym, processDailyBody } from "./body"

export function processScheduled(world: WorldState, event: ScheduledEvent): WorldState {
  if (event.kind === "work-reminder" || event.kind === "work-attendance") return processWorkEvent(world, event)
  if (event.kind === "daily-events" || event.kind === "event-followup") return processLifeEvent(world, event)
  if (event.kind === "daily-city") return processDailyCity(world, event)
  if (event.kind === "interview" || event.kind === "interview-result") return processInterviewEvent(world, event)
  if (event.kind === "daily-body") return processDailyBody(world, event)
  if (event.kind === "weekly-economy") return processWeeklyEconomy(world, event)
  if (event.kind === "mother-message") return appendEntry(world, { at: world.clock, kind: "message", text: starterContent.reminder, personIds: [event.personId], cause: event.id })
  if (event.kind === "monthly-finance") {
    let next = world
    const accrued = world.employment?.accruedCents ?? 0
    if (accrued > 0 && world.employment) {
      next = postLedger(next, { amountCents: accrued, category: "salary", text: `Salário · ${world.companies[world.employment.companyId]!.name}`, cause: world.employment.id })
      next = { ...next, employment: { ...world.employment, accruedCents: 0, shiftsWorked: 0 } }
      next = appendEntry(next, { at: world.clock, kind: "finance", text: `Caiu o pagamento dos turnos do mês: ${formatMoney(accrued)}.`, personIds: [world.playerId], cause: world.employment.id })
    }
    next = postLedger(next, { amountCents: -world.finance.monthlyRentCents, category: "rent", text: "Aluguel · Vila das Flores", cause: event.id })
    next = chargeGym(next)
    next = appendEntry(next, { at: world.clock, kind: "finance", text: `O aluguel de ${formatMoney(world.finance.monthlyRentCents)} foi debitado.${next.finance.balanceCents < 0 ? " A conta ficou negativa. Você precisa reorganizar as despesas." : ""}`, personIds: [world.playerId], cause: event.id })
    const now = calendarDate(world.clock.day)
    const day = now.month === 12 ? dayFromCalendar(now.year + 1, 1, 1) : dayFromCalendar(now.year, now.month + 1, 1)
    return { ...next, scheduled: [...next.scheduled, { ...event, at: { day, minute: 480 } }] }
  }
  // IA inicial: pessoas próximas procuram contato segundo sociabilidade.
  // Ausência prolongada reduz proximidade; memória fica disponível no inspector.
  let next: WorldState = { ...world, memories: world.memories.map(memory => ({ ...memory, salience: memory.salience * .995 })) }
  // Ligações diretas vêm de família e amizades; vizinhos e colegas falam por mensagem (systems/city).
  const relations = Object.values(world.relationships).filter(rel => (rel.a === world.playerId || rel.b === world.playerId) && (rel.tags.includes("family") || rel.tags.includes("friend")))
  const roll = draw(world.seed, next.rng, "ai")
  next = { ...next, rng: roll.state }
  const selected = relations[Math.floor(roll.value * relations.length)]
  for (const rel of relations) {
    const last = rel.lastInteractionAt ? absoluteMinute(rel.lastInteractionAt) : 0
    if (absoluteMinute(world.clock) - last > 10080) next = updateRelationship(next, rel.id, { affection: -.2, familiarity: -.1 })
  }
  if (selected) {
    const other = world.people[selected.a === world.playerId ? selected.b : selected.a]!
    const chance = draw(world.seed, next.rng, "ai")
    next = { ...next, rng: chance.state }
    const recent = selected.lastInteractionAt && absoluteMinute(world.clock) - absoluteMinute(selected.lastInteractionAt) < 1440
    if (!recent && chance.value < .08 + other.personality.sociability * .2) {
      const pool = selected.tags.includes("family") ? socialTexts.family : world.clock.day < 14 ? socialTexts.arrival : world.employment ? socialTexts.employed : socialTexts.everyday
      const recentTexts = next.memories.filter(memory => memory.personId === other.id).slice(-3).map(memory => memory.text)
      const texts = pool.map(text => text.replaceAll("{person}", other.name).replaceAll("{company}", world.employment ? world.companies[world.employment.companyId]!.name : "a empresa"))
      const fresh = texts.filter(text => !recentTexts.includes(text))
      const variant = draw(world.seed, next.rng, "ai")
      next = { ...next, rng: variant.state }
      const options = fresh.length ? fresh : texts
      const text = options[Math.floor(variant.value * options.length)]!
      next = updateRelationship(next, selected.id, { affection: 1, familiarity: 1 }, world.clock)
      next = remember(next, other.id, world.playerId, text, event.id)
      next = appendEntry(next, { at: world.clock, kind: "relationship", text, personIds: [world.playerId, other.id], cause: `ai.contact:${selected.id}` })
    }
  }
  return { ...next, scheduled: [...next.scheduled, { ...event, id: "schedule:daily-social" as ScheduleId, at: { day: world.clock.day + 1, minute: 1020 } }] }
}
