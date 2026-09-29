import type { GameDate, WorldState } from "../domain/world"
import { absoluteMinute, fromMinute } from "../time"
import { applyElapsed } from "../systems/needs"
import { processScheduled } from "../systems/periodic"
export { appendEntry } from "../timeline"

// Eventos vencidos em ordem estável. Skip pausa no primeiro fato importante.
export function advance(world: WorldState, target: GameDate, options: { resting?: boolean; interruptible?: boolean } = {}): WorldState {
  let next = world
  const end = absoluteMinute(target)
  // Reconsultar a fila inclui eventos recorrentes criados durante o próprio skip.
  for (;;) {
    const event = [...next.scheduled].sort((a, b) => absoluteMinute(a.at) - absoluteMinute(b.at) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))[0]
    if (!event) break
    const at = absoluteMinute(event.at)
    if (at > end) break
    next = { ...applyElapsed(next, at - absoluteMinute(next.clock), options.resting), clock: event.at,
      scheduled: next.scheduled.filter(item => item.id !== event.id) }
    next = processScheduled(next, event)
    if (options.interruptible && (event.interrupts || next.events.pending)) return next
  }
  return { ...applyElapsed(next, end - absoluteMinute(next.clock), options.resting), clock: fromMinute(end) }
}
