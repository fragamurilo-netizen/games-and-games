import type { MemoryId, PersonId } from "@paralelo/shared"
import type { WorldState } from "../domain/world"

export function remember(world: WorldState, personId: PersonId, otherId: PersonId, text: string, cause: string): WorldState {
  return { ...world, nextId: world.nextId + 1, memories: [...world.memories, { id: `memory:${world.nextId}` as MemoryId, at: world.clock, personId, otherId, text, cause, salience: .7 }] }
}
