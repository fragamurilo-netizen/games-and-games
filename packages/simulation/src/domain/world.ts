import type { CompanyId, CourseId, DecisionId, EmploymentId, HouseholdId, LedgerId, MemoryId, PersonId, RelationshipId, ResidenceId, ScheduleId, TimelineId, VacancyId } from "@paralelo/shared"
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
  kind: "chapter" | "action" | "relationship" | "message" | "career" | "finance" | "education" | "decision"
  text: string
  personIds: readonly PersonId[]
  cause: string
}>
export type ScheduledEvent = Readonly<{
  id: ScheduleId
  at: GameDate
  kind: "mother-message" | "daily-social" | "monthly-finance" | "daily-events" | "event-followup"
  eventId?: string
  actorId?: PersonId | null
  personId: PersonId
  interrupts: boolean
}>
export type Command =
  | Readonly<{ type: "wait"; minutes: number }>
  | Readonly<{ type: "rest" }>
  | Readonly<{ type: "contact"; personId: PersonId }>
  | Readonly<{ type: "sleep" }>
  | Readonly<{ type: "meal" }>
  | Readonly<{ type: "apply-job"; vacancyId: VacancyId }>
  | Readonly<{ type: "work" }>
  | Readonly<{ type: "study"; courseId: CourseId }>
  | Readonly<{ type: "decide"; decisionId: DecisionId; choiceId: string }>
export type CommandRecord = Readonly<{ revision: number; at: GameDate; command: Command }>
export type WorldStateV1 = Readonly<{
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

export type Skills = Readonly<{ organization: number; communication: number }>
export type Company = Readonly<{ id: CompanyId; name: string; district: string }>
export type Vacancy = Readonly<{ id: VacancyId; companyId: CompanyId; roleId: string; open: boolean }>
export type Employment = Readonly<{ id: EmploymentId; personId: PersonId; companyId: CompanyId; roleId: string; startedAt: GameDate; lastWorkedDay: number | null; accruedCents: number; shiftsWorked: number; performance: number }>
export type LedgerEntry = Readonly<{ id: LedgerId; at: GameDate; amountCents: number; category: "salary" | "rent" | "food" | "education" | "event"; text: string; cause: string }>
export type Memory = Readonly<{ id: MemoryId; at: GameDate; personId: PersonId; otherId: PersonId; text: string; salience: number; cause: string }>
export type WorldStateV2 = Omit<WorldStateV1, "schemaVersion"> & Readonly<{
  schemaVersion: 2
  skills: Readonly<Record<string, Skills>>
  tiers: Readonly<Record<string, "player" | "close" | "background">>
  companies: Readonly<Record<string, Company>>
  vacancies: Readonly<Record<string, Vacancy>>
  employment: Employment | null
  applications: readonly Readonly<{ vacancyId: VacancyId; at: GameDate; accepted: boolean }>[]
  finance: Readonly<{ openingBalanceCents: number; balanceCents: number; monthlyRentCents: number; ledger: readonly LedgerEntry[] }>
  training: Readonly<Record<string, Readonly<{ sessions: number; lastStudiedDay: number | null }>>>
  memories: readonly Memory[]
}>
export type PendingDecision = Readonly<{ id: DecisionId; definitionId: string; actorId: PersonId | null; at: GameDate }>
export type WorldState = Omit<WorldStateV2, "schemaVersion"> & Readonly<{
  schemaVersion: 3
  events: Readonly<{ contentVersion: 1; seen: readonly string[]; lastOfferedDay: number | null; pending: PendingDecision | null }>
}>
