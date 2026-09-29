import { starterContent } from "@paralelo/content"
import type { HouseholdId, PersonId, RelationshipId, ResidenceId, ScheduleId, TimelineId } from "@paralelo/shared"
import type { Person, Relationship, WorldState, WorldStateV1 } from "./domain/world"
import { upgradeWorldV1 } from "./systems/slice"
import { upgradeWorldV2 } from "./systems/events"
import { createRng, draw } from "./rng"
import { dayFromCalendar } from "./time"

export function createWorld(seed: string): WorldState {
  if (!seed.trim() || seed.length > 200) throw new Error("A seed deve ter entre 1 e 200 caracteres.")
  let rng = createRng()
  const roll = () => { const result = draw(seed, rng, "world"); rng = result.state; return result.value }
  const playerId = "person:player" as PersonId
  const people: Record<string, Person> = {}
  const households: Record<string, WorldState["households"][string]> = {}
  const residences: Record<string, WorldState["residences"][string]> = {}
  const relationships: Record<string, Relationship> = {}
  const friendOffset = Math.floor(roll() * starterContent.friendNames.length)
  const names = [starterContent.playerNames[Math.floor(roll() * starterContent.playerNames.length)]!, starterContent.motherName,
    starterContent.friendNames[friendOffset]!, starterContent.friendNames[(friendOffset + 1) % starterContent.friendNames.length]!]
  const ids = [playerId, "person:mother", "person:friend-a", "person:friend-b"] as PersonId[]
  ids.forEach((id, i) => {
    const householdId = `household:${id}` as HouseholdId
    const residenceId = `residence:${id}` as ResidenceId
    const birthYear = i === 1 ? 1974 : 2003
    people[id] = { id, name: names[i]!, birthDate: { day: dayFromCalendar(birthYear, 1 + Math.floor(roll() * 12), 1 + Math.floor(roll() * 28)), minute: 0 },
      householdId, residenceId, appearanceSeed: `${seed}/${id}`,
      personality: { sociability: roll(), discipline: roll(), sensitivity: roll() },
      needs: { energy: 65 + Math.floor(roll() * 20), stress: 20 + Math.floor(roll() * 15) }, relationshipIds: [] }
    households[householdId] = { id: householdId, memberIds: [id] }
    residences[residenceId] = { id: residenceId, district: starterContent.district }
  })
  ids.slice(1).forEach((id, i) => {
    const relationshipId = `relationship:player:${id}` as RelationshipId
    relationships[relationshipId] = { id: relationshipId, a: playerId, b: id, familiarity: i === 0 ? 95 : 55,
      affection: 50 + Math.floor(roll() * 25), trust: 50 + Math.floor(roll() * 25), respect: 60, attraction: 0, resentment: 0, tags: [i === 0 ? "family" : "friend"] }
    for (const personId of [playerId, id]) {
      const person = people[personId]!
      people[personId] = { ...person, relationshipIds: [...person.relationshipIds, relationshipId] }
    }
  })
  const clock = { day: 0, minute: 480 }
  return upgradeWorldV2(upgradeWorldV1({ schemaVersion: 1, seed, clock, revision: 0, nextId: 2, playerId, city: starterContent.city,
    people, households, residences, relationships, rng,
    scheduled: [{ id: "schedule:mother-first-day" as ScheduleId, at: { day: 0, minute: 1080 }, kind: "mother-message", personId: ids[1]!, interrupts: true }],
    timeline: [{ id: "timeline:1" as TimelineId, at: clock, kind: "chapter", text: starterContent.opening, personIds: [playerId], cause: "world.created" }], recentCommands: [] } satisfies WorldStateV1))
}
