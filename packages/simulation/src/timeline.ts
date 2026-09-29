import type { TimelineId } from "@paralelo/shared"
import type { TimelineEntry, WorldState } from "./domain/world"

export function appendEntry(world: WorldState, entry: Omit<TimelineEntry, "id">): WorldState {
  return { ...world, nextId: world.nextId + 1, timeline: [...world.timeline, { ...entry, id: `timeline:${world.nextId}` as TimelineId }] }
}
