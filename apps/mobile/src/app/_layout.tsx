import { Link, Slot, usePathname } from "expo-router"
import { SQLiteProvider } from "expo-sqlite"
import { StatusBar } from "expo-status-bar"
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context"
import { Pressable, StyleSheet, Text, View } from "react-native"
import { colors, fonts } from "../theme"
import { useEffect, useState } from "react"
import { useFonts } from "expo-font"
import * as SplashScreen from "expo-splash-screen"
import { Newsreader_400Regular } from "@expo-google-fonts/newsreader/400Regular"
import { Newsreader_600SemiBold } from "@expo-google-fonts/newsreader/600SemiBold"
import { Commissioner_400Regular } from "@expo-google-fonts/commissioner/400Regular"
import { Commissioner_500Medium } from "@expo-google-fonts/commissioner/500Medium"
import { Commissioner_600SemiBold } from "@expo-google-fonts/commissioner/600SemiBold"
import { GameProvider, useGame } from "../hooks/game-context"
import LifeScreen from "../screens/life-screen"
import { Consequence, DayTurn, DecisionScene } from "../components/game-feel"
void SplashScreen.preventAutoHideAsync()

export default function RootLayout() {
  const [loaded, error] = useFonts({ Newsreader_400Regular, Newsreader_600SemiBold, Commissioner_400Regular, Commissioner_500Medium, Commissioner_600SemiBold })
  const [databaseError, setDatabaseError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => { if (loaded || error) SplashScreen.hide() }, [loaded, error])
  if (!loaded && !error) return null
  return <SafeAreaProvider>
    {databaseError ? <View style={styles.failure}>
      <Text style={styles.failureTitle}>Sua vida ficou guardada.</Text>
      <Text accessibilityRole="alert" style={styles.failureText}>Não conseguimos abrir a campanha agora. Seus dados foram preservados.</Text>
      <Pressable accessibilityRole="button" style={styles.retry} onPress={() => { setDatabaseError(null); setAttempt(value => value + 1) }}><Text style={styles.failureText}>Tentar novamente</Text></Pressable>
    </View> : <SQLiteProvider key={attempt} databaseName="paralelo.db" onError={error => setDatabaseError(error.message)}>
      <GameProvider><Campaign /></GameProvider>
    </SQLiteProvider>}
    <StatusBar style="light" />
  </SafeAreaProvider>
}
function Campaign() {
  const { world } = useGame()
  return <View style={styles.page}>{world ? <><View style={styles.page}><Slot /><Consequence /></View><Navigation /><DecisionScene /><DayTurn /></> : <LifeScreen />}</View>
}
function Navigation() {
  const path = usePathname()
  const items = [{ href: "/", label: "VIDA" }, { href: "/people", label: "PESSOAS" }, { href: "/career", label: "CARREIRA" }, { href: "/money", label: "DINHEIRO" }, { href: "/world", label: "MUNDO" }] as const
  return <SafeAreaView edges={["bottom"]} style={styles.navigation}><View style={styles.links}>{items.map(item => <Link href={item.href} asChild key={item.href}>
    <Pressable accessibilityRole="link" accessibilityLabel={item.label} accessibilityState={{ selected: path === item.href }} style={styles.link}><Text style={[styles.label, path === item.href && styles.active]}>{item.label}</Text></Pressable>
  </Link>)}</View></SafeAreaView>
}
const styles = StyleSheet.create({ page: { flex: 1, backgroundColor: colors.bg }, navigation: { borderTopColor: colors.rule, borderTopWidth: 1, backgroundColor: colors.bg }, links: { flexDirection: "row", maxWidth: 680, width: "100%", alignSelf: "center" }, link: { flex: 1, minHeight: 56, justifyContent: "center", alignItems: "center", paddingHorizontal: 2 }, label: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 11, letterSpacing: .25 }, active: { color: colors.accent, fontFamily: fonts.label }, failure: { flex: 1, backgroundColor: colors.bg, justifyContent: "center", padding: 24 }, failureTitle: { color: colors.text, fontFamily: fonts.title, fontSize: 30, marginBottom: 16 }, failureText: { color: colors.text, fontFamily: fonts.body, fontSize: 16, lineHeight: 25 }, retry: { borderColor: colors.rule, borderWidth: 1, marginTop: 24, padding: 16, minHeight: 48 } })
