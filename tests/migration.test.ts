import { afterEach, describe, expect, it } from "vitest"
import { readFileSync } from "node:fs"
import { decodeSnapshot, encodeSnapshot, SqliteSaveRepository } from "@paralelo/persistence"
import { validateWorld } from "@paralelo/simulation"
import { GameSession } from "../apps/mobile/src/application/game-session"
import { memorySqlite } from "./fixtures/sqlite"

const databases: ReturnType<typeof memorySqlite>[] = []
const payload = readFileSync(new URL("./fixtures/legacy-save-v1.json", import.meta.url), "utf8")
afterEach(() => { for (const database of databases.splice(0)) database.native.close() })
describe("migração da fundação 1670156", () => {
  it("migra v2 para v3 preservando cidade, emprego, ledger, memórias e RNG", () => {
    const previous = readFileSync(new URL("./fixtures/legacy-save-v2.json", import.meta.url), "utf8")
    const original = JSON.parse(previous), loaded = decodeSnapshot(previous)
    expect(loaded.ok).toBe(true)
    if (!loaded.ok) throw new Error(loaded.error.message)
    for (const field of ["people", "companies", "vacancies", "finance", "employment", "training", "memories", "rng", "clock", "timeline"] as const)
      expect(loaded.value[field]).toEqual(original.world[field])
    expect(loaded.value.schemaVersion).toBe(3)
    expect(loaded.value.events.pending).toBeNull()
    expect(loaded.value.scheduled.filter(event => event.kind === "daily-events")).toHaveLength(1)
    expect(validateWorld(loaded.value).ok).toBe(true)
  })
  it("conserva seed, relógio, IDs, pessoas, relações e RNG do save v1", () => {
    const legacy = JSON.parse(payload), result = decodeSnapshot(payload)
    expect(result.ok).toBe(true)
    if (!result.ok) throw new Error(result.error.message)
    const world = result.value
    expect(world.schemaVersion).toBe(3)
    for (const field of ["seed", "clock", "rng", "relationships", "timeline", "revision"] as const) expect(world[field]).toEqual(legacy.world[field])
    for (const person of Object.values(legacy.world.people)) expect(world.people[(person as { id: string }).id]).toEqual(person)
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
    expect(session.getSnapshot().world?.schemaVersion).toBe(3)
    const current = database.native.prepare("SELECT payload FROM saves WHERE slot = 'current'").get()
    const previous = database.native.prepare("SELECT payload FROM saves WHERE slot = 'previous'").get()
    expect(JSON.parse(String(current?.payload)).schemaVersion).toBe(3)
    expect(previous?.payload).toBe(payload)
  })
})
