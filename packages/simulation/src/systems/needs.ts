import type { WorldState } from "../domain/world"
const clamp = (v: number) => Math.max(0, Math.min(100, v))

// Dono dos estados físicos. Taxas da fundação; rotina diária será a fase seguinte.
export function applyElapsed(world: WorldState, minutes: number, resting = false): WorldState {
  const player = world.people[world.playerId]!
  const energy = clamp(player.needs.energy + minutes * (resting ? .20 : -.015))
  const stress = clamp(player.needs.stress + minutes * (resting ? -.08 : .003))
  return { ...world, people: { ...world.people, [player.id]: { ...player, needs: { energy, stress } } } }
}
