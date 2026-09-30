import type { Person, WorldState } from "../domain/world"
const clamp = (value: number) => Math.max(0, Math.min(100, value))
export type Activity = "awake" | "rest" | "sleep"

// Integra a necessidade acima do limiar. Eventos intermediários não criam
// saltos artificiais de fadiga. Nenhuma dependência de FPS ou tempo real.
function exposure(start: number, rate: number, minutes: number, threshold: number): number {
  const points = [0, minutes, (threshold - start) / rate, (100 - start) / rate, -start / rate]
    .filter(value => Number.isFinite(value) && value >= 0 && value <= minutes).sort((a, b) => a - b)
  let total = 0
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1]!, b = points[i]!
    total += (Math.max(0, clamp(start + rate * a) - threshold) + Math.max(0, clamp(start + rate * b) - threshold)) * (b - a) / 2
  }
  return total
}
export function applyElapsed(world: WorldState, minutes: number, activity: Activity = "awake"): WorldState {
  const player = world.people[world.playerId]!, needs = player.needs
  const sleeping = activity === "sleep", resting = activity === "rest"
  const hungerRate = sleeping ? .02 : .06, sleepRate = sleeping ? -.15 : .05
  const hungerExposure = exposure(needs.hunger, hungerRate, minutes, 65)
  const sleepExposure = exposure(needs.sleepPressure, sleepRate, minutes, 75)
  const energy = clamp(needs.energy + minutes * (sleeping ? .16 : resting ? .13 : -.035) - hungerExposure * .0003 - sleepExposure * .0004)
  const stress = clamp(needs.stress + minutes * (sleeping ? -.025 : resting ? -.06 : .003) + hungerExposure * .00005 + sleepExposure * .00008)
  return { ...world, people: { ...world.people, [player.id]: { ...player, needs: { energy, stress, hunger: clamp(needs.hunger + minutes * hungerRate), sleepPressure: clamp(needs.sleepPressure + minutes * sleepRate) } } } }
}
export function changeNeeds(world: WorldState, change: Partial<Person["needs"]>): WorldState {
  const player = world.people[world.playerId]!
  const needs = { ...player.needs }
  for (const key of ["energy", "stress", "hunger", "sleepPressure"] as const) needs[key] = clamp(needs[key] + (change[key] ?? 0))
  return { ...world, people: { ...world.people, [player.id]: { ...player, needs } } }
}
