import { err, ok, type Result } from "@paralelo/shared"
import { validateWorld, type WorldState } from "@paralelo/simulation"
import { decodeSnapshot, encodeSnapshot, type SaveError } from "./snapshot"

export interface SqlExecutor {
  execAsync(sql: string): Promise<void>
  runAsync(sql: string, ...parameters: (string | number | null)[]): Promise<unknown>
  getFirstAsync<T>(sql: string, ...parameters: (string | number | null)[]): Promise<T | null>
}
export interface SqlDatabase extends SqlExecutor {
  transaction(task: (connection: SqlExecutor) => Promise<void>): Promise<void>
}
export type LoadedSave = Readonly<{ world: WorldState; recoveredBackup: boolean }>

// Banco v1: snapshot versionado + cópia anterior em transação atômica.
// Nenhuma dependência de Expo; adaptadores vivem na borda da aplicação.
export class SqliteSaveRepository {
  private initialized = false
  private queue: Promise<unknown> = Promise.resolve()
  constructor(private readonly db: SqlDatabase) {}
  private serial<T>(task: () => Promise<T>): Promise<T> {
    const result = this.queue.then(task, task)
    this.queue = result.catch(() => undefined)
    return result
  }
  private async initialize(): Promise<void> {
    if (this.initialized) return
    const header = await this.db.getFirstAsync<{ user_version: number }>("PRAGMA user_version")
    const version = header?.user_version ?? 0
    if (version > 1) throw new Error("Versão do banco mais nova que este aplicativo. Nenhum dado foi alterado.")
    if (version === 0) await this.db.transaction(async tx => {
      await tx.execAsync("CREATE TABLE saves (slot TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL); PRAGMA user_version = 1;")
    })
    this.initialized = true
  }
  async load(): Promise<Result<LoadedSave | null, SaveError>> {
    return this.serial(async () => {
      try {
        await this.initialize()
        const current = await this.db.getFirstAsync<{ payload: string }>("SELECT payload FROM saves WHERE slot = ?", "current")
        if (current) {
          const decoded = decodeSnapshot(current.payload)
          if (decoded.ok) return ok({ world: decoded.value, recoveredBackup: false })
          if (decoded.error.code === "unsupported-version") return decoded
        }
        const backup = await this.db.getFirstAsync<{ payload: string }>("SELECT payload FROM saves WHERE slot = ?", "previous")
        if (backup) {
          const decoded = decodeSnapshot(backup.payload)
          if (decoded.ok) return ok({ world: decoded.value, recoveredBackup: true })
        }
        return current || backup ? err({ code: "invalid-save", message: "O save e a cópia anterior estão danificados. Os arquivos foram preservados." }) : ok(null)
      } catch (error) { return err({ code: "storage", message: error instanceof Error ? error.message : "Não foi possível abrir o save." }) }
    })
  }
  async save(world: WorldState): Promise<Result<void, SaveError>> {
    return this.serial(async () => {
      const checked = validateWorld(world)
      if (!checked.ok) return err({ code: "invalid-save", message: checked.error.join(" ") })
      try {
        await this.initialize()
        const payload = encodeSnapshot(world)
        await this.db.transaction(async tx => {
          const current = await tx.getFirstAsync<{ payload: string }>("SELECT payload FROM saves WHERE slot = ?", "current")
          if (current?.payload === payload) return // Background não substitui backup pelo mesmo save.
          if (current && decodeSnapshot(current.payload).ok)
            await tx.runAsync("INSERT OR REPLACE INTO saves (slot, payload) VALUES (?, ?)", "previous", current.payload)
          await tx.runAsync("INSERT OR REPLACE INTO saves (slot, payload) VALUES (?, ?)", "current", payload)
        })
        return ok(undefined)
      } catch (error) { return err({ code: "storage", message: error instanceof Error ? error.message : "Não foi possível salvar agora." }) }
    })
  }
}
