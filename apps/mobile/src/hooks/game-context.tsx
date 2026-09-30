import { createContext, useContext, useEffect, useMemo, useSyncExternalStore, type ReactNode } from "react"
import { AppState } from "react-native"
import { useSQLiteContext } from "expo-sqlite"
import { SqliteSaveRepository } from "@paralelo/persistence"
import { GameSession } from "../application/game-session"
import { sqliteAdapter } from "../persistence/sqlite-adapter"

const GameContext = createContext<GameSession | null>(null)
export function GameProvider({ children }: { children: ReactNode }) {
  const db = useSQLiteContext()
  const session = useMemo(() => new GameSession(new SqliteSaveRepository(sqliteAdapter(db)), "vila-das-flores", { onboarding: true, newSeed: () => `santa-aurora/${Date.now().toString(36)}` }), [db])
  useEffect(() => {
    void session.initialize()
    const listener = AppState.addEventListener("change", state => { if (state !== "active") void session.save() })
    return () => listener.remove()
  }, [session])
  return <GameContext.Provider value={session}>{children}</GameContext.Provider>
}
export function useGame() {
  const session = useContext(GameContext)
  if (!session) throw new Error("GameProvider ausente.")
  const snapshot = useSyncExternalStore(session.subscribe, session.getSnapshot, session.getSnapshot)
  return { ...snapshot, dispatch: session.dispatch, retry: session.initialize, start: session.start }
}
