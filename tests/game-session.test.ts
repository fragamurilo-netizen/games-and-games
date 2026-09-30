import { afterEach, describe, expect, it } from "vitest"
import { err } from "@paralelo/shared"
import { SqliteSaveRepository } from "@paralelo/persistence"
import { GameSession } from "../apps/mobile/src/application/game-session"
import { memorySqlite } from "./fixtures/sqlite"

const databases: ReturnType<typeof memorySqlite>[] = []
const fixture = () => { const f = memorySqlite(); databases.push(f); return f }
afterEach(() => { for (const f of databases.splice(0)) f.native.close() })
describe("fluxo aplicação -> comando -> save -> query", () => {
  it("abre uma vez, aplica ação e retoma a campanha salva", async () => {
    const repo = new SqliteSaveRepository(fixture().db), session = new GameSession(repo, "s")
    let notifications = 0
    const unsubscribe = session.subscribe(() => { notifications++ })
    await Promise.all([session.initialize(), session.initialize()])
    await session.dispatch({ type: "rest" })
    expect(session.getSnapshot().world?.revision).toBe(1)
    const resumed = new GameSession(repo, "outra-seed")
    await resumed.initialize()
    expect(resumed.getSnapshot().world).toEqual(session.getSnapshot().world)
    expect(notifications).toBeGreaterThan(0)
    unsubscribe()
  })
  it("não publica ação que falhou ao salvar e permite tentar novamente", async () => {
    const repo = new SqliteSaveRepository(fixture().db)
    let fail = false
    const session = new GameSession({ load: () => repo.load(), save: world => fail ? Promise.resolve(err({ code: "storage", message: "disco cheio" })) : repo.save(world) }, "s")
    await session.initialize()
    const before = session.getSnapshot().world
    fail = true
    await session.dispatch({ type: "rest" })
    expect(session.getSnapshot()).toMatchObject({ world: before, busy: false, error: "disco cheio" })
    fail = false
    await session.dispatch({ type: "rest" })
    expect(session.getSnapshot().world?.revision).toBe(1)
  })
  it("bloqueia duplo toque enquanto a ação está sendo salva", async () => {
    const session = new GameSession(new SqliteSaveRepository(fixture().db), "s")
    await session.initialize()
    await Promise.all([session.dispatch({ type: "rest" }), session.dispatch({ type: "rest" })])
    expect(session.getSnapshot().world?.revision).toBe(1)
  })
  it("preserva campanha danificada e não cria outra por cima dela", async () => {
    const { db, native } = fixture()
    const repo = new SqliteSaveRepository(db)
    await repo.load()
    native.prepare("INSERT INTO saves (slot, payload) VALUES (?, ?)").run("current", "quebrado")
    const session = new GameSession(repo, "s")
    await session.initialize()
    expect(session.getSnapshot().world).toBeNull()
    expect(session.getSnapshot().error).toBeTruthy()
    expect(native.prepare("SELECT payload FROM saves WHERE slot = 'current'").get()?.payload).toBe("quebrado")
  })
})
describe("começo da campanha (bíblia §47)", () => {
  it("sem save, espera a escolha e só então cria e grava a vida", async () => {
    const repo = new SqliteSaveRepository(fixture().db)
    const session = new GameSession(repo, "s", { onboarding: true, newSeed: () => "nova" })
    await session.initialize()
    expect(session.getSnapshot()).toMatchObject({ world: null, needsStart: true, busy: false })
    await session.start({ firstName: "x", sex: "F", age: 22, start: "job-search" })
    expect(session.getSnapshot().world).toBeNull()
    expect(session.getSnapshot().error).toBeTruthy()
    await session.start({ firstName: "Débora", sex: "F", age: 24, start: "simple-job" })
    const world = session.getSnapshot().world!
    expect(world.people[world.playerId]!.name).toBe("Débora Ferreira")
    expect(world.employment).not.toBeNull()
    const resumed = new GameSession(repo, "s", { onboarding: true })
    await resumed.initialize()
    expect(resumed.getSnapshot()).toMatchObject({ world, needsStart: false })
  })
})
