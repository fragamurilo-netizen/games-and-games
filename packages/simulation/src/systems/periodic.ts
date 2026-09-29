import type { ScheduleId } from "@paralelo/shared"
import { starterContent } from "@paralelo/content"
import type { ScheduledEvent, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, calendarDate, dayFromCalendar } from "../time"
import { appendEntry } from "../timeline"
import { formatMoney, postLedger } from "./finance"
import { remember } from "./memory"
import { updateRelationship } from "./relationships"

export function processScheduled(world: WorldState, event: ScheduledEvent): WorldState {
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
    next = appendEntry(next, { at: world.clock, kind: "finance", text: `O aluguel de ${formatMoney(world.finance.monthlyRentCents)} foi debitado.${next.finance.balanceCents < 0 ? " A conta ficou negativa. Você precisa reorganizar as despesas." : ""}`, personIds: [world.playerId], cause: event.id })
    const now = calendarDate(world.clock.day)
    const day = now.month === 12 ? dayFromCalendar(now.year + 1, 1, 1) : dayFromCalendar(now.year, now.month + 1, 1)
    return { ...next, scheduled: [...next.scheduled, { ...event, at: { day, minute: 480 } }] }
  }
  // IA inicial: pessoas próximas procuram contato segundo sociabilidade.
  // Ausência prolongada reduz proximidade; memória fica disponível no inspector.
  let next: WorldState = { ...world, memories: world.memories.map(memory => ({ ...memory, salience: memory.salience * .995 })) }
  const relations = Object.values(world.relationships).filter(rel => rel.a === world.playerId || rel.b === world.playerId)
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
      const text = selected.tags.includes("family")
        ? `${other.name} ligou para saber da casa. Você contou o que conseguiu resolver desde a mudança.`
        : `${other.name} puxou assunto: \"E aí, já conseguiu arrumar aquelas caixas?\" Vocês acabaram conversando um pouco.`
      next = updateRelationship(next, selected.id, { affection: 1, familiarity: 1 }, world.clock)
      next = remember(next, other.id, world.playerId, "Procurou você para saber como estava a casa.", event.id)
      next = appendEntry(next, { at: world.clock, kind: "relationship", text, personIds: [world.playerId, other.id], cause: `ai.contact:${selected.id}` })
    }
  }
  return { ...next, scheduled: [...next.scheduled, { ...event, id: "schedule:daily-social" as ScheduleId, at: { day: world.clock.day + 1, minute: 1020 } }] }
}
