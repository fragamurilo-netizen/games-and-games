import { DatabaseSync } from "node:sqlite"
import type { SqlDatabase, SqlExecutor } from "@paralelo/persistence"

export function memorySqlite() {
  const native = new DatabaseSync(":memory:")
  const db: SqlDatabase = {
    async execAsync(sql) { native.exec(sql) },
    async runAsync(sql, ...parameters) { return native.prepare(sql).run(...parameters) },
    async getFirstAsync<T>(sql: string, ...parameters: (string | number | null)[]) { return (native.prepare(sql).get(...parameters) as T | undefined) ?? null },
    async transaction(task: (tx: SqlExecutor) => Promise<void>) {
      native.exec("BEGIN IMMEDIATE")
      try { await task(db); native.exec("COMMIT") } catch (error) { native.exec("ROLLBACK"); throw error }
    },
  }
  return { db, native }
}
