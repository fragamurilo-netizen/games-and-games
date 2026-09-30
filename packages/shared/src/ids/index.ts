// IDs com marca de tipo (bíblia §81). Nunca usar índice de array como identidade (§37).
export type Brand<T, B extends string> = T & { readonly __brand: B }

export type PersonId = Brand<string, "PersonId">
export type CompanyId = Brand<string, "CompanyId">
export type RelationshipId = Brand<string, "RelationshipId">
export type MemoryId = Brand<string, "MemoryId">
export type EmploymentId = Brand<string, "EmploymentId">
export type HouseholdId = Brand<string, "HouseholdId">
export type ResidenceId = Brand<string, "ResidenceId">
export type TimelineId = Brand<string, "TimelineId">
export type ScheduleId = Brand<string, "ScheduleId">
export type VacancyId = Brand<string, "VacancyId">
export type CourseId = Brand<string, "CourseId">
export type LedgerId = Brand<string, "LedgerId">
export type DecisionId = Brand<string, "DecisionId">
export type NewsId = Brand<string, "NewsId">
export type MessageId = Brand<string, "MessageId">
