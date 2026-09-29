import { Slot } from "expo-router"
import { SQLiteProvider } from "expo-sqlite"
import { StatusBar } from "expo-status-bar"
import { SafeAreaProvider } from "react-native-safe-area-context"
import { GameProvider } from "../hooks/game-context"

export default function RootLayout() {
  return <SafeAreaProvider>
    <SQLiteProvider databaseName="paralelo.db">
      <GameProvider><Slot /></GameProvider>
    </SQLiteProvider>
    <StatusBar style="light" />
  </SafeAreaProvider>
}
