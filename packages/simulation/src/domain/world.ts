import type { CompanyId, CourseId, DecisionId, EmploymentId, HouseholdId, InterviewId, LedgerId, MemoryId, MessageId, NewsId, PersonId, RelationshipId, ResidenceId, SceneId, ScheduleId, TimelineId, VacancyId } from "@paralelo/shared"
import type { RngState } from "../rng"

// Dia 0 = 05/01/2026. Minutos inteiros; nenhum tempo de sistema no domínio.
export type GameDate = Readonly<{ day: number; minute: number }>
export type PersonV3 = Readonly<{
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
export type PersonV4 = Omit<PersonV3, "needs"> & Readonly<{
  needs: PersonV3["needs"] & Readonly<{ hunger: number; sleepPressure: number }>
}>
export type Person = PersonV4 & Readonly<{ sex: "F" | "M" }>
export type RelationshipTag = "family" | "friend" | "neighbor" | "coworker"
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
  tags: readonly RelationshipTag[]
  lastInteractionAt?: GameDate
  /** quando se conheceram, se foi dentro da campanha (bíblia §6.4) */
  since?: GameDate
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
  kind: "mother-message" | "daily-social" | "monthly-finance" | "daily-events" | "event-followup" | "work-reminder" | "work-attendance" | "daily-city" | "weekly-economy" | "interview" | "interview-result"
  employmentId?: EmploymentId
  interviewId?: InterviewId
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
  | Readonly<{ type: "meal"; source?: "home" | "restaurant" | "community" }>
  | Readonly<{ type: "buy-groceries" }>
  | Readonly<{ type: "apply-job"; vacancyId: VacancyId }>
  | Readonly<{ type: "work" }>
  | Readonly<{ type: "study"; courseId: CourseId }>
  | Readonly<{ type: "decide"; decisionId: DecisionId; choiceId: string }>
  | Readonly<{ type: "reply"; messageId: MessageId; reply: MessageReply }>
  | Readonly<{ type: "work-choice"; sceneId: SceneId; choiceId: string }>
  | Readonly<{ type: "prepare"; target: "review" } | { type: "prepare"; target: "interview"; interviewId: InterviewId }>
  | Readonly<{ type: "apply-internal" }>
export type CommandRecord = Readonly<{ revision: number; at: GameDate; command: Command }>
export type WorldStateV1 = Readonly<{
  schemaVersion: 1
  seed: string
  clock: GameDate
  revision: number
  nextId: number
  playerId: PersonId
  city: string
  people: Readonly<Record<string, PersonV3>>
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
export type EmploymentV3 = Readonly<{ id: EmploymentId; personId: PersonId; companyId: CompanyId; roleId: string; startedAt: GameDate; lastWorkedDay: number | null; accruedCents: number; shiftsWorked: number; performance: number }>
export type Employment = EmploymentV3 & Readonly<{ requiredFromDay: number; consecutiveAbsences: number; lastAssessedDay: number | null }>
export type EmploymentRecord = Readonly<{ id: EmploymentId; companyId: CompanyId; roleId: string; startedAt: GameDate; endedAt: GameDate; reason: "absence" | "restructure" | "performance"; settledCents: number }>
export type LedgerEntry = Readonly<{ id: LedgerId; at: GameDate; amountCents: number; category: "salary" | "rent" | "food" | "education" | "event"; text: string; cause: string }>
export type Memory = Readonly<{ id: MemoryId; at: GameDate; personId: PersonId; otherId: PersonId; text: string; salience: number; cause: string }>
export type WorldStateV2 = Omit<WorldStateV1, "schemaVersion"> & Readonly<{
  schemaVersion: 2
  skills: Readonly<Record<string, Skills>>
  tiers: Readonly<Record<string, "player" | "close" | "background">>
  companies: Readonly<Record<string, Company>>
  vacancies: Readonly<Record<string, Vacancy>>
  employment: EmploymentV3 | null
  applications: readonly Readonly<{ vacancyId: VacancyId; at: GameDate; accepted: boolean }>[]
  finance: Readonly<{ openingBalanceCents: number; balanceCents: number; monthlyRentCents: number; ledger: readonly LedgerEntry[] }>
  training: Readonly<Record<string, Readonly<{ sessions: number; lastStudiedDay: number | null }>>>
  memories: readonly Memory[]
}>
export type PendingDecision = Readonly<{ id: DecisionId; definitionId: string; actorId: PersonId | null; at: GameDate }>
export type WorldStateV3 = Omit<WorldStateV2, "schemaVersion"> & Readonly<{
  schemaVersion: 3
  events: Readonly<{ contentVersion: 1; seen: readonly string[]; lastOfferedDay: number | null; pending: PendingDecision | null }>
}>
export type WorldStateV4 = Omit<WorldStateV3, "schemaVersion" | "people" | "employment"> & Readonly<{
  schemaVersion: 4
  people: Readonly<Record<string, PersonV4>>
  employment: Employment | null
  employmentHistory: readonly EmploymentRecord[]
  routine: Readonly<{ pantryMeals: number; lastCommunityMealDay: number | null }>
}>
export type WorldStateV5 = Omit<WorldStateV4, "schemaVersion" | "people"> & Readonly<{
  schemaVersion: 5
  people: Readonly<Record<string, Person>>
}>

// ---- Mundo vivo (v6): a cidade continua sem o jogador (bíblia §2.1, §13, §15, §19, §20) ----
export type GoalKind = "find-job" | "change-job" | "keep-in-touch"
export type Goal = Readonly<{ kind: GoalKind; since: GameDate }>
/** Última decisão da IA, com as notas de cada opção (bíblia §13.3). */
export type AiDecision = Readonly<{ at: GameDate; goal: GoalKind | null; options: readonly Readonly<{ action: string; score: number }>[]; chosen: string }>
export type ResidentJob = Readonly<{ companyId: CompanyId; roleId: string; since: GameDate; satisfaction: number }>
export type Resident = Readonly<{ job: ResidentJob | null; goal: Goal | null; lastDecision: AiDecision | null; lastAppliedDay: number | null; lastMessagedDay: number | null }>
export type CompanyEconomy = Readonly<{ health: number; trend: number; weakWeeks: number }>
export type NewsSection = "negocios" | "trabalho" | "cidade"
export type NewsItem = Readonly<{ id: NewsId; at: GameDate; section: NewsSection; headline: string; body: string; companyId: CompanyId | null; personIds: readonly PersonId[]; cause: string }>
export type MessageTopic = "checkin" | "hired" | "dismissed" | "job-tip" | "worry"
export type MessageReply = "answer" | "call" | "later"
export type Message = Readonly<{ id: MessageId; at: GameDate; fromId: PersonId; topic: MessageTopic; text: string; expiresAt: GameDate; status: "unread" | "answered" | "ignored"; postponed: boolean; vacancyId: VacancyId | null }>
export type WorldStateV6 = Omit<WorldStateV5, "schemaVersion"> & Readonly<{
  schemaVersion: 6
  residents: Readonly<Record<string, Resident>>
  economy: Readonly<Record<string, CompanyEconomy>>
  news: readonly NewsItem[]
  inbox: readonly Message[]
}>

// ---- Trabalho vivido (v7): gestor, confiança, turno com situações, avaliação, entrevistas (bíblia §15, §61) ----
export type Assignment = Readonly<{ templateId: string; title: string; givenDay: number; dueDay: number; needed: number; progress: number }>
export type Workplace = Readonly<{
  managerId: PersonId
  /** confiança profissional de quem responde pela equipe, 0–100 */
  trust: number
  salaryCents: number
  totalShifts: number
  lateThisMonth: number
  absencesThisMonth: number
  warnings: number
  lateToday: boolean
  assignment: Assignment | null
  delivered: number
  missed: number
  nextReviewDay: number
  prepared: boolean
  recentSituations: readonly string[]
  promotion: Readonly<{ roleId: string; untilDay: number; applied: boolean }> | null
}>
export type EmploymentV7 = Employment & Readonly<{ workplace: Workplace }>
export type InterviewStatus = "scheduled" | "awaiting" | "passed" | "failed" | "missed" | "canceled"
export type Interview = Readonly<{ id: InterviewId; vacancyId: VacancyId | null; companyId: CompanyId; roleId: string; internal: boolean; at: GameDate; prepared: boolean; status: InterviewStatus; score: number | null }>
export type WorkScene = Readonly<{
  id: SceneId
  kind: "shift" | "review" | "interview"
  situationId: string
  at: GameDate
  actorId: PersonId | null
  interviewId: InterviewId | null
  /** minutos de turno que faltam depois da cena */
  remainingMinutes: number
  shiftDay: number | null
}>
export type WorldState = Omit<WorldStateV6, "schemaVersion" | "employment"> & Readonly<{
  schemaVersion: 7
  employment: EmploymentV7 | null
  /** quem responde pela equipe em cada empresa (bíblia §15.1) */
  leaders: Readonly<Record<string, PersonId>>
  work: Readonly<{ scene: WorkScene | null; interviews: readonly Interview[] }>
}>
