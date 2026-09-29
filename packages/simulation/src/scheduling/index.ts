import { starterContent } from "@paralelo/content"
import type { TimelineId } from "@paralelo/shared"
import type { GameDate, TimelineEntry, WorldState } from "../domain/world"
import { absoluteMinute, fromMinute } from "../time"
import { applyElapsed } from "../systems/needs"

export function appendEntry(world: WorldState, entry: Omit<TimelineEntry, "id">): WorldState {
  return { ...world, nextId: world.nextId + 1, timeline: [...world.timeline, { ...entry, id: `timeline:${world.nextId}` as TimelineId }] }
}

// Eventos vencidos em ordem estável. Skip pausa no primeiro fato importante.
export function advance(world: WorldState, target: GameDate, options: { resting?: boolean; interruptible?: boolean } = {}): WorldState {
  let next = world
  const end = absoluteMinute(target)
  const due = [...world.scheduled].sort((a, b) => absoluteMinute(a.at) - absoluteMinute(b.at) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
  for (const event of due) {
    const at = absoluteMinute(event.at)
    if (at > end) break
    next = { ...applyElapsed(next, at - absoluteMinute(next.clock), options.resting), clock: event.at,
      scheduled: next.scheduled.filter(item => item.id !== event.id) }
    next = appendEntry(next, { at: event.at, kind: "message", text: starterContent.reminder, personIds: [event.personId], cause: event.id })
    if (options.interruptible && event.interrupts) return next
  }
  return { ...applyElapsed(next, end - absoluteMinute(next.clock), options.resting), clock: fromMinute(end) }
}
