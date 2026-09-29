import type { HouseholdId, PersonId, RelationshipId, ResidenceId, ScheduleId, TimelineId } from "@paralelo/shared"
import type { RngState } from "../rng"

// Dia 0 = 05/01/2026. Minutos inteiros; nenhum tempo de sistema no domínio.
export type GameDate = Readonly<{ day: number; minute: number }>
export type Person = Readonly<{
  id: PersonId
  name: string
  birthDate: GameDate
  householdId: HouseholdId
  residenceId: ResidenceId
  appearanceSeed: string
  personality: Readonly<{ sociability: number; discipline: number; sensitivity: number }>
  needs: Readonly<{ energy: number; stress: number }>
  relationshipIds: readonly RelationshipId[]
}>
export type Relationship = Readonly<{
  id: RelationshipId
  a: PersonId
  b: PersonId
  familiarity: number
  affection: number
  trust: number
  respect: number
  attraction: number
  resentment: number
  tags: readonly ("family" | "friend")[]
  lastInteractionAt?: GameDate
}>
export type TimelineEntry = Readonly<{
  id: TimelineId
  at: GameDate
  kind: "chapter" | "action" | "relationship" | "message"
  text: string
  personIds: readonly PersonId[]
  cause: string
}>
export type ScheduledEvent = Readonly<{
  id: ScheduleId
  at: GameDate
  kind: "mother-message"
  personId: PersonId
  interrupts: boolean
}>
export type Command =
  | Readonly<{ type: "wait"; minutes: number }>
  | Readonly<{ type: "rest" }>
  | Readonly<{ type: "contact"; personId: PersonId }>
export type CommandRecord = Readonly<{ revision: number; at: GameDate; command: Command }>
export type WorldState = Readonly<{
  schemaVersion: 1
  seed: string
  clock: GameDate
  revision: number
  nextId: number
  playerId: PersonId
  city: string
  people: Readonly<Record<string, Person>>
  households: Readonly<Record<string, Readonly<{ id: HouseholdId; memberIds: readonly PersonId[] }>>>
  residences: Readonly<Record<string, Readonly<{ id: ResidenceId; district: string }>>>
  relationships: Readonly<Record<string, Relationship>>
  rng: RngState
  scheduled: readonly ScheduledEvent[]
  timeline: readonly TimelineEntry[]
  recentCommands: readonly CommandRecord[]
}>
