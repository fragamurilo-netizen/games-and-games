import { bodyRules, lifeEvents, validateLifeEvents, type EventChoice, type EventDefinition } from "@paralelo/content"
import type { DecisionId, PersonId, ScheduleId } from "@paralelo/shared"
import type { ScheduledEvent, WorldState, WorldStateV2, WorldStateV3 } from "../domain/world"
import { eat } from "./body"
import { draw } from "../rng"
import { advance } from "../scheduling"
import { addMinutes, ageAt, formatDate } from "../time"
import { appendEntry } from "../timeline"
import { postLedger } from "./finance"
import { remember } from "./memory"
import { changeNeeds } from "./needs"
import { updateRelationship } from "./relationships"

export function upgradeWorldV2(base: WorldStateV2): WorldStateV3 {
  const errors = validateLifeEvents()
  if (errors.length) throw new Error(errors.join(" "))
  return { ...base, schemaVersion: 3, events: { contentVersion: 1, seen: [], lastOfferedDay: null, pending: null },
    scheduled: [...base.scheduled, { id: "schedule:daily-events" as ScheduleId, at: { day: base.clock.day + (base.clock.minute >= 1140 ? 1 : 0), minute: 1140 }, kind: "daily-events", personId: base.playerId, interrupts: false }] }
}
export const eventText = (world: WorldState, text: string, actorId: PersonId | null): string => text.replaceAll("{person}", actorId ? world.people[actorId]!.name : "uma pessoa próxima")
function actorFor(world: WorldState, definition: EventDefinition): PersonId | null {
  if (!definition.actor) return null
  const tag = definition.actor === "mother" ? "family" : "friend"
  const rel = Object.values(world.relationships).filter(r => (r.a === world.playerId || r.b === world.playerId) && r.tags.includes(tag)).sort((a, b) => a.affection - b.affection || (a.id < b.id ? -1 : 1))[0]
  return rel ? rel.a === world.playerId ? rel.b : rel.a : null
}
export function eligibleEvent(world: WorldState, definition: EventDefinition): boolean {
  if (definition.actor && !actorFor(world, definition)) return false
  return definition.conditions.every(condition => {
    if (condition.type === "employed") return !!world.employment === condition.value
    const value = condition.type === "money" ? world.finance.balanceCents : world.people[world.playerId]!.needs[condition.type]
    return (condition.min === undefined || value >= condition.min) && (condition.max === undefined || value <= condition.max)
  })
}
function offer(world: WorldState, definition: EventDefinition, actorId: PersonId | null): WorldState {
  const id = `decision:${world.nextId}` as DecisionId
  return { ...world, nextId: world.nextId + 1, events: { ...world.events, seen: [...world.events.seen, definition.id], lastOfferedDay: world.clock.day, pending: { id, definitionId: definition.id, actorId, at: world.clock } } }
}
export function processLifeEvent(world: WorldState, item: ScheduledEvent): WorldState {
  if (item.kind === "event-followup") {
    const definition = lifeEvents.find(event => event.id === item.eventId)
    if (!definition || world.events.seen.includes(definition.id)) return world
    if (world.events.pending || world.work.scene || world.events.lastOfferedDay === world.clock.day)
      return { ...world, scheduled: [...world.scheduled, { ...item, at: { day: world.clock.day + 1, minute: 1140 } }] }
    if (!eligibleEvent(world, definition)) return appendEntry(world, { at: world.clock, kind: "decision", text: `A oportunidade de ${definition.title.toLowerCase()} passou; seu dia tomou outro rumo.`, personIds: [world.playerId], cause: `event.expired:${definition.id}` })
    return offer(world, definition, item.actorId ?? actorFor(world, definition))
  }
  let next: WorldState = { ...world, scheduled: [...world.scheduled, { ...item, at: { day: world.clock.day + 1, minute: 1140 } }] }
  if (world.events.pending || world.work.scene || (world.events.lastOfferedDay !== null && world.clock.day - world.events.lastOfferedDay < 3)) return next
  const eligible = lifeEvents.filter(event => event.root && !world.events.seen.includes(event.id) && eligibleEvent(world, event))
  if (!eligible.length) return next
  const roll = draw(world.seed, world.rng, "event")
  next = { ...next, rng: roll.state }
  const definition = eligible[Math.floor(roll.value * eligible.length)]!
  return offer(next, definition, actorFor(world, definition))
}
export function choiceReason(world: WorldState, option: EventChoice): string | null {
  return option.effect.moneyCents && option.effect.moneyCents < 0 && world.finance.balanceCents + option.effect.moneyCents < 0 ? "O saldo disponível não cobre este gasto." : null
}
export function resolveDecision(world: WorldState, option: EventChoice): WorldState {
  const pending = world.events.pending!, definition = lifeEvents.find(event => event.id === pending.definitionId)!
  let next = advance({ ...world, events: { ...world.events, pending: null } }, addMinutes(world.clock, option.effect.minutes))
  if (option.effect.moneyCents) next = postLedger(next, { amountCents: option.effect.moneyCents, category: "event", text: definition.title, cause: `event.choice:${pending.id}:${option.id}` })
  next = changeNeeds(next, { energy: option.effect.energy ?? 0, stress: option.effect.stress ?? 0, hunger: option.effect.hunger ?? 0 })
  if ((option.effect.hunger ?? 0) < 0) next = eat(next, -option.effect.hunger! * bodyRules.kcalPerHunger)
  const skills = next.skills[next.playerId]!, clamp = (n: number) => Math.max(0, Math.min(1, n))
  next = { ...next, skills: { ...next.skills, [next.playerId]: { organization: clamp(skills.organization + (option.effect.organization ?? 0)), communication: clamp(skills.communication + (option.effect.communication ?? 0)) } } }
  if (pending.actorId) {
    const rel = Object.values(next.relationships).find(r => (r.a === world.playerId && r.b === pending.actorId) || (r.b === world.playerId && r.a === pending.actorId))
    if (rel) next = updateRelationship(next, rel.id, { affection: option.effect.affection ?? 0, trust: option.effect.trust ?? 0 }, next.clock)
    next = remember(next, pending.actorId, world.playerId, eventText(next, option.outcome, pending.actorId), `event.choice:${pending.id}:${option.id}`)
  }
  next = appendEntry(next, { at: next.clock, kind: "decision", text: eventText(next, option.outcome, pending.actorId), personIds: pending.actorId ? [world.playerId, pending.actorId] : [world.playerId], cause: `event.choice:${pending.id}:${option.id}` })
  if (option.followUp) {
    next = { ...next, nextId: next.nextId + 1, scheduled: [...next.scheduled, { id: `schedule:followup-${next.nextId}` as ScheduleId, at: { day: next.clock.day + 2, minute: 1140 }, kind: "event-followup", personId: world.playerId, eventId: option.followUp, actorId: pending.actorId, interrupts: true }] }
  }
  return next
}
export function queryDecision(world: WorldState) {
  const pending = world.events.pending
  if (!pending) return null
  const definition = lifeEvents.find(event => event.id === pending.definitionId)!
  const actor = pending.actorId ? world.people[pending.actorId] : undefined
  return { id: pending.id, title: definition.title, text: eventText(world, definition.text, pending.actorId), date: formatDate(pending.at),
    actor: actor ? { name: actor.name, age: ageAt(actor.birthDate, world.clock), appearance: { seed: actor.appearanceSeed, sex: actor.sex } } : null,
    choices: definition.choices.map(option => ({ id: option.id, label: option.label, reason: choiceReason(world, option), canChoose: !choiceReason(world, option) })) }
}
