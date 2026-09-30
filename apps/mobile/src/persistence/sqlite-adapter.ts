import { Platform } from "react-native"
import type { SQLiteDatabase } from "expo-sqlite"
import type { SqlDatabase } from "@paralelo/persistence"

export function sqliteAdapter(db: SQLiteDatabase): SqlDatabase {
  return {
    execAsync: sql => db.execAsync(sql),
    runAsync: (sql, ...parameters) => db.runAsync(sql, ...parameters),
    getFirstAsync: (sql, ...parameters) => db.getFirstAsync(sql, ...parameters),
    transaction: task => Platform.OS === "web"
      ? db.withTransactionAsync(() => task(db)) // Repositório serializa todos os acessos no web.
      : db.withExclusiveTransactionAsync(tx => task(tx)),
  }
}
