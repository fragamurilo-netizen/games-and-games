import { Link, Slot, usePathname } from "expo-router"
import { SQLiteProvider } from "expo-sqlite"
import { StatusBar } from "expo-status-bar"
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context"
import { Pressable, StyleSheet, Text, View } from "react-native"
import { colors } from "../theme"
import { GameProvider } from "../hooks/game-context"

export default function RootLayout() {
  return <SafeAreaProvider>
    <SQLiteProvider databaseName="paralelo.db">
      <GameProvider><View style={styles.page}><Slot /><Navigation /></View></GameProvider>
    </SQLiteProvider>
    <StatusBar style="light" />
  </SafeAreaProvider>
}
function Navigation() {
  const path = usePathname()
  const items = [{ href: "/", label: "VIDA" }, { href: "/people", label: "PESSOAS" }, { href: "/career", label: "CARREIRA" }, { href: "/money", label: "DINHEIRO" }, { href: "/world", label: "MUNDO" }] as const
  return <SafeAreaView edges={["bottom"]} style={styles.navigation}><View style={styles.links}>{items.map(item => <Link href={item.href} asChild key={item.href}>
    <Pressable accessibilityRole="link" accessibilityLabel={item.label} accessibilityState={{ selected: path === item.href }} style={styles.link}><Text style={[styles.label, path === item.href && styles.active]}>{item.label}</Text></Pressable>
  </Link>)}</View></SafeAreaView>
}
const styles = StyleSheet.create({ page: { flex: 1, backgroundColor: colors.bg }, navigation: { borderTopColor: colors.rule, borderTopWidth: 1, backgroundColor: colors.bg }, links: { flexDirection: "row", maxWidth: 680, width: "100%", alignSelf: "center" }, link: { flex: 1, minHeight: 56, justifyContent: "center", alignItems: "center" }, label: { color: colors.textSecondary, fontSize: 10, letterSpacing: .5 }, active: { color: colors.accent, fontWeight: "700" } })
