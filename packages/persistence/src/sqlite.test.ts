import { afterEach, describe, expect, it } from "vitest"
import { createWorld, executeCommand, worldHash, type WorldState } from "@paralelo/simulation"
import { memorySqlite } from "../../../tests/fixtures/sqlite"
import { decodeSnapshot, encodeSnapshot, SqliteSaveRepository } from "."

const databases: ReturnType<typeof memorySqlite>[] = []
const fixture = () => { const f = memorySqlite(); databases.push(f); return f }
afterEach(() => { for (const f of databases.splice(0)) f.native.close() })
const rest = (world: WorldState) => {
  const result = executeCommand(world, { type: "rest" })
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}
describe("SQLite real e snapshot versionado", () => {
  it("cria banco, salva, carrega e continua com o mesmo RNG", async () => {
    const { db, native } = fixture(), repo = new SqliteSaveRepository(db)
    expect(await repo.load()).toEqual({ ok: true, value: null })
    expect(native.prepare("PRAGMA user_version").get()?.user_version).toBe(1)
    const world = rest(createWorld("s"))
    expect(await repo.save(world)).toEqual({ ok: true, value: undefined })
    const loaded = await new SqliteSaveRepository(db).load()
    expect(loaded.ok && loaded.value?.world).toEqual(world)
    if (!loaded.ok || !loaded.value) throw new Error("Save ausente")
    const command = { type: "contact", personId: world.people["person:mother"]!.id } as const
    expect(executeCommand(loaded.value.world, command)).toEqual(executeCommand(world, command))
  })
  it("recupera backup sem apagá-lo quando o save atual foi corrompido", async () => {
    const { db, native } = fixture(), repo = new SqliteSaveRepository(db)
    const first = createWorld("s"), second = rest(first)
    await repo.save(first); await repo.save(second); await repo.save(second)
    native.prepare("UPDATE saves SET payload = ? WHERE slot = ?").run("{truncado", "current")
    expect(await repo.load()).toEqual({ ok: true, value: { world: first, recoveredBackup: true } })
    await repo.save(rest(first))
    expect(await repo.load()).toEqual({ ok: true, value: { world: second, recoveredBackup: false } })
    expect(decodeSnapshot(String(native.prepare("SELECT payload FROM saves WHERE slot = 'previous'").get()?.payload))).toEqual({ ok: true, value: first })
  })
  it("reverte toda a gravação se falhar depois de atualizar o backup", async () => {
    const { db } = fixture(), repo = new SqliteSaveRepository(db)
    const first = createWorld("s"), second = rest(first)
    await repo.save(first); await repo.save(second)
    const failing = { ...db, transaction: (task: Parameters<typeof db.transaction>[0]) => db.transaction(tx => task({
      ...tx, runAsync: async (sql, ...parameters) => { if (parameters[0] === "current") throw new Error("disco cheio"); return tx.runAsync(sql, ...parameters) },
    })) }
    expect(await new SqliteSaveRepository(failing).save(rest(second))).toMatchObject({ ok: false, error: { code: "storage" } })
    expect(await repo.load()).toEqual({ ok: true, value: { world: second, recoveredBackup: false } })
    const backup = await db.getFirstAsync<{ payload: string }>("SELECT payload FROM saves WHERE slot = ?", "previous")
    expect(backup && decodeSnapshot(backup.payload)).toEqual({ ok: true, value: first })
  })
  it("serializa autosaves simultâneos e mantém a cópia anterior", async () => {
    const { db } = fixture(), repo = new SqliteSaveRepository(db)
    const first = createWorld("s"), second = rest(first), third = rest(second)
    await Promise.all([repo.save(first), repo.save(second), repo.save(third)])
    expect(await repo.load()).toEqual({ ok: true, value: { world: third, recoveredBackup: false } })
    const backup = await db.getFirstAsync<{ payload: string }>("SELECT payload FROM saves WHERE slot = ?", "previous")
    expect(backup && decodeSnapshot(backup.payload)).toEqual({ ok: true, value: second })
  })
  it("recusa versão futura sem restaurar silenciosamente uma versão anterior", async () => {
    const { db, native } = fixture(), repo = new SqliteSaveRepository(db)
    await repo.save(createWorld("s")); await repo.save(rest(createWorld("s")))
    native.prepare("UPDATE saves SET payload = ? WHERE slot = ?").run('{"schemaVersion":7}', "current")
    expect(await repo.load()).toMatchObject({ ok: false, error: { code: "unsupported-version" } })
    native.exec("PRAGMA user_version = 2")
    expect(await new SqliteSaveRepository(db).load()).toMatchObject({ ok: false, error: { code: "storage" } })
    expect(native.prepare("SELECT payload FROM saves WHERE slot = 'current'").get()?.payload).toBe('{"schemaVersion":7}')
  })
  it("detecta corrupção, referências inválidas e adulteração de hash", async () => {
    const world = createWorld("s")
    const tampered = JSON.parse(encodeSnapshot(world))
    tampered.world.clock.minute++
    expect(decodeSnapshot(JSON.stringify(tampered)).ok).toBe(false)
    const invalid = { ...world, relationships: {} }
    const repo = new SqliteSaveRepository(fixture().db)
    expect((await repo.save(invalid)).ok).toBe(false)
    expect(await repo.load()).toEqual({ ok: true, value: null })
    expect(worldHash(world)).toBe(worldHash(JSON.parse(JSON.stringify(world))))
  })
})
