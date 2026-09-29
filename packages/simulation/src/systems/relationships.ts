import type { RelationshipId } from "@paralelo/shared"
import type { GameDate, Relationship, WorldState } from "../domain/world"

export function updateRelationship(world: WorldState, id: RelationshipId, change: Partial<Pick<Relationship, "familiarity" | "affection" | "trust" | "resentment">>, at?: GameDate): WorldState {
  const rel = world.relationships[id]!
  const clamp = (value: number) => Math.max(0, Math.min(100, value))
  const values = { ...rel }
  for (const key of ["familiarity", "affection", "trust", "resentment"] as const) if (change[key] !== undefined) values[key] = clamp(rel[key] + change[key]!)
  return { ...world, relationships: { ...world.relationships, [id]: { ...values, ...(at ? { lastInteractionAt: at } : {}) } } }
}
