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
  it("conserva seed, relógio, IDs, pessoas, relações e RNG do save v1", () => {
    const legacy = JSON.parse(payload), result = decodeSnapshot(payload)
    expect(result.ok).toBe(true)
    if (!result.ok) throw new Error(result.error.message)
    const world = result.value
    expect(world.schemaVersion).toBe(2)
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
    expect(session.getSnapshot().world?.schemaVersion).toBe(2)
    const current = database.native.prepare("SELECT payload FROM saves WHERE slot = 'current'").get()
    const previous = database.native.prepare("SELECT payload FROM saves WHERE slot = 'previous'").get()
    expect(JSON.parse(String(current?.payload)).schemaVersion).toBe(2)
    expect(previous?.payload).toBe(payload)
  })
})
