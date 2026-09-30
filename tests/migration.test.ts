import { afterEach, describe, expect, it } from "vitest"
import { readFileSync } from "node:fs"
import { decodeSnapshot, encodeSnapshot, SqliteSaveRepository } from "@paralelo/persistence"
import { createWorld, createWorldV5, upgradeWorldV5, upgradeWorldV6, validateWorld, worldHash, type WorldState } from "@paralelo/simulation"
import { GameSession } from "../apps/mobile/src/application/game-session"
import { memorySqlite } from "./fixtures/sqlite"

const databases: ReturnType<typeof memorySqlite>[] = []
const payload = readFileSync(new URL("./fixtures/legacy-save-v1.json", import.meta.url), "utf8")
type LegacyPerson = { id: string; relationshipIds: string[] }
// v6 liga vizinhos e amigos entre si: quem existia continua igual, só ganha vínculos novos
const expectPeoplePreserved = (world: WorldState, people: Record<string, LegacyPerson>): void => {
  for (const { relationshipIds, ...rest } of Object.values(people)) {
    const person = world.people[rest.id]!
    expect(person).toMatchObject(rest)
    expect(person.relationshipIds.slice(0, relationshipIds.length)).toEqual(relationshipIds)
  }
}
const expectRelationshipsPreserved = (world: WorldState, relationships: Record<string, unknown>): void => {
  expect(world.relationships).toMatchObject(relationships)
  for (const [id, relationship] of Object.entries(world.relationships))
    if (!(id in relationships)) expect(relationship.tags.every(tag => tag === "neighbor" || tag === "friend")).toBe(true)
}
afterEach(() => { for (const database of databases.splice(0)) database.native.close() })
describe("migrações de campanhas anteriores", () => {
  it("migra v2 preservando cidade, emprego, ledger, memórias e RNG", () => {
    const previous = readFileSync(new URL("./fixtures/legacy-save-v2.json", import.meta.url), "utf8")
    const original = JSON.parse(previous), loaded = decodeSnapshot(previous)
    expect(loaded.ok).toBe(true)
    if (!loaded.ok) throw new Error(loaded.error.message)
    expectPeoplePreserved(loaded.value, original.world.people)
    for (const field of ["companies", "vacancies", "finance", "employment", "training", "memories", "rng", "clock", "timeline"] as const)
      expect(loaded.value[field]).toEqual(original.world[field])
    expect(loaded.value.schemaVersion).toBe(8)
    expect(loaded.value.events.pending).toBeNull()
    expect(loaded.value.scheduled.filter(event => event.kind === "daily-events")).toHaveLength(1)
    expect(validateWorld(loaded.value).ok).toBe(true)
  })
  it("conserva seed, relógio, IDs, pessoas, relações e RNG do save v1", () => {
    const legacy = JSON.parse(payload), result = decodeSnapshot(payload)
    expect(result.ok).toBe(true)
    if (!result.ok) throw new Error(result.error.message)
    const world = result.value
    expect(world.schemaVersion).toBe(8)
    for (const field of ["seed", "clock", "rng", "timeline", "revision"] as const) expect(world[field]).toEqual(legacy.world[field])
    expectRelationshipsPreserved(world, legacy.world.relationships)
    expectPeoplePreserved(world, legacy.world.people)
    expect(Object.keys(world.people)).toHaveLength(100)
    expect(validateWorld(world).ok).toBe(true)
    expect(decodeSnapshot(encodeSnapshot(world))).toEqual(result)
  })
  it("grava migração em SQLite mantendo o save antigo como backup", async () => {
    const database = memorySqlite(); databases.push(database)
    const repo = new SqliteSaveRepository(database.db)
    await repo.load()
    database.native.prepare("INSERT INTO saves (slot, payload) VALUES (?, ?)").run("current", payload)
    const session = new GameSession(repo, "não-usar")
    await session.initialize()
    expect(session.getSnapshot().world?.schemaVersion).toBe(8)
    const current = database.native.prepare("SELECT payload FROM saves WHERE slot = 'current'").get()
    const previous = database.native.prepare("SELECT payload FROM saves WHERE slot = 'previous'").get()
    expect(JSON.parse(String(current?.payload)).schemaVersion).toBe(8)
    expect(previous?.payload).toBe(payload)
  })
  it("migra emprego v3 sem perder salário nem aplicar faltas retroativas", () => {
    const old = readFileSync(new URL("./fixtures/legacy-save-v3.json", import.meta.url), "utf8")
    const original = JSON.parse(old).world, loaded = decodeSnapshot(old)
    if (!loaded.ok) throw new Error(loaded.error.message)
    const world = loaded.value
    expect(world.employment).toMatchObject(original.employment)
    expect(world.employment?.accruedCents).toBeGreaterThan(0)
    expect(world.employment?.requiredFromDay).toBeGreaterThan(world.clock.day)
    expect(world.employment?.consecutiveAbsences).toBe(0)
    // v7: o contrato antigo ganha gestor, salário e conversa do mês sem perder nada
    expect(world.employment?.workplace.managerId).toBe(world.leaders[world.employment!.companyId])
    expect(world.employment?.workplace.salaryCents).toBeGreaterThan(0)
    expect(world.employment?.workplace.nextReviewDay).toBeGreaterThan(world.clock.day)
    expect(world.employmentHistory).toEqual([])
    expectPeoplePreserved(world, original.people)
    for (const field of ["rng", "clock", "timeline", "finance", "events", "recentCommands", "vacancies"] as const) expect(world[field]).toEqual(original[field])
    expect(world.routine.pantryMeals).toBe(4)
    expect(world.scheduled.filter(item => item.kind.startsWith("work-"))).toHaveLength(2)
    expect(decodeSnapshot(encodeSnapshot(world))).toEqual(loaded)
  })
  it("migra v4 acrescentando o sexo pelo nome sem mexer no resto", () => {
    const current = createWorld("migra-v4"), v5 = createWorldV5("migra-v4")
    const people = Object.fromEntries(Object.entries(v5.people).map(([id, person]) => {
      const { sex: _sex, ...rest } = person
      return [id, rest]
    }))
    const legacy = { ...v5, schemaVersion: 4, people }
    const loaded = decodeSnapshot(JSON.stringify({ schemaVersion: 4, hash: worldHash(legacy as never), world: legacy }))
    if (!loaded.ok) throw new Error(loaded.error.message)
    expect(loaded.value).toEqual(current)
    expect(loaded.value.people["person:mother"]?.sex).toBe("F")
    expect(Object.values(loaded.value.people).every(person => person.sex === "F" || person.sex === "M")).toBe(true)
  })
})

describe("migração v5 → v6 (mundo vivo)", () => {
  it("dá emprego, economia, vizinhos e caixa de entrada sem tocar no que já existia", () => {
    const v5 = createWorldV5("migra-v5")
    const loaded = decodeSnapshot(JSON.stringify({ schemaVersion: 5, hash: worldHash(v5), world: v5 }))
    if (!loaded.ok) throw new Error(loaded.error.message)
    const world = loaded.value
    expect(world).toEqual(createWorld("migra-v5"))
    expect(world.schemaVersion).toBe(8)
    for (const field of ["rng", "clock", "timeline", "finance", "companies", "vacancies", "memories", "employment"] as const) expect(world[field]).toEqual(v5[field])
    expectRelationshipsPreserved(world, v5.relationships)
    expectPeoplePreserved(world, v5.people)
    expect(Object.keys(world.residents)).toHaveLength(Object.keys(world.people).length - 1)
    expect(Object.keys(world.economy).sort()).toEqual(Object.keys(world.companies).sort())
    expect(Object.values(world.relationships).filter(r => r.tags.includes("neighbor"))).toHaveLength(7)
    expect(world.inbox).toEqual([])
    expect(world.scheduled.filter(item => item.kind === "daily-city" || item.kind === "weekly-economy")).toHaveLength(2)
    expect(validateWorld(world).ok).toBe(true)
    expect(decodeSnapshot(encodeSnapshot(world))).toEqual(loaded)
  })
})

describe("migração v6 → v7 (trabalho vivido)", () => {
  it("dá liderança às empresas e agenda de trabalho vazia sem mexer no resto", () => {
    const v6 = upgradeWorldV5(createWorldV5("migra-v6"))
    const loaded = decodeSnapshot(JSON.stringify({ schemaVersion: 6, hash: worldHash(v6), world: v6 }))
    if (!loaded.ok) throw new Error(loaded.error.message)
    const world = loaded.value
    expect(world).toEqual(createWorld("migra-v6"))
    expect(world.schemaVersion).toBe(8)
    for (const field of ["rng", "clock", "timeline", "finance", "companies", "vacancies", "news", "inbox", "economy"] as const) expect(world[field]).toEqual(v6[field])
    expect(Object.keys(world.leaders).sort()).toEqual(Object.keys(world.companies).sort())
    expect(world.work).toEqual({ scene: null, interviews: [] })
    expect(validateWorld(world).ok).toBe(true)
  })
})

describe("migração v7 → v8 (corpo e aparência)", () => {
  it("dá corpo e guarda-roupa a todo mundo e agenda o balanço diário sem mexer no resto", () => {
    const v7 = upgradeWorldV6(upgradeWorldV5(createWorldV5("migra-v7")))
    const loaded = decodeSnapshot(JSON.stringify({ schemaVersion: 7, hash: worldHash(v7), world: v7 }))
    if (!loaded.ok) throw new Error(loaded.error.message)
    const world = loaded.value
    expect(world).toEqual(createWorld("migra-v7"))
    expect(world.schemaVersion).toBe(8)
    for (const field of ["rng", "clock", "timeline", "finance", "people", "relationships", "residents", "work", "leaders", "inbox"] as const) expect(world[field]).toEqual(v7[field])
    expect(Object.keys(world.bodies).sort()).toEqual(Object.keys(world.people).sort())
    expect(Object.keys(world.wardrobes).sort()).toEqual(Object.keys(world.people).sort())
    expect(world.gym).toBeNull()
    expect(world.scheduled.filter(item => item.kind === "daily-body")).toHaveLength(1)
    expect(world.scheduled.slice(0, v7.scheduled.length)).toEqual(v7.scheduled)
    expect(validateWorld(world).ok).toBe(true)
    expect(decodeSnapshot(encodeSnapshot(world))).toEqual(loaded)
  })
})
