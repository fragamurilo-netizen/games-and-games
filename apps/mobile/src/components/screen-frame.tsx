import type { ReactNode } from "react"
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import { colors, space, fonts } from "../theme"
import { useGame } from "../hooks/game-context"
import type { Command } from "@paralelo/simulation"
import { Link } from "expo-router"

export function ScreenFrame({ title, subtitle, children }: { title: string; subtitle: string; children: ReactNode }) {
  const { error, busy, world } = useGame()
  return <SafeAreaView edges={["top", "left", "right"]} style={pageStyles.root}><ScrollView contentContainerStyle={pageStyles.content}>
    <Text style={pageStyles.wordmark}>PARALELO</Text>
    <Text style={pageStyles.subtitle}>{subtitle}</Text>
    <Text accessibilityRole="header" style={pageStyles.title}>{title}</Text>
    {error && <Text accessibilityRole="alert" style={pageStyles.error}>{error}</Text>}
    {world?.events.pending && <Link href="/" style={pageStyles.secondary}>Uma decisão espera sua resposta. Voltar à VIDA.</Link>}
    {children}
    <Text accessibilityLiveRegion="polite" style={pageStyles.footer}>{busy ? "Guardando sua campanha…" : "Sua campanha é salva a cada ação."}</Text>
  </ScrollView></SafeAreaView>
}
export function ActionButton({ label, command, disabled = false }: { label: string; command: Command; disabled?: boolean }) {
  const { busy, dispatch, world } = useGame()
  const blocked = disabled || (!!world?.events.pending && command.type !== "decide")
  return <Pressable accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled: busy || blocked }}
    disabled={busy || blocked} onPress={() => { void dispatch(command) }} style={({ pressed }) => [pageStyles.button, (busy || blocked) && pageStyles.disabled, pressed && pageStyles.pressed]}>
    <Text style={pageStyles.buttonText}>{label}</Text>
  </Pressable>
}
export function Section({ title, children }: { title: string; children: ReactNode }) {
  return <View style={pageStyles.section}><Text accessibilityRole="header" style={pageStyles.sectionTitle}>{title}</Text>{children}</View>
}
export const pageStyles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { padding: space[6], paddingBottom: space[12], maxWidth: 680, width: "100%", alignSelf: "center" },
  wordmark: { color: colors.text, fontFamily: fonts.label, fontSize: 14, letterSpacing: 4, borderBottomColor: colors.rule, borderBottomWidth: 1, paddingBottom: space[6] },
  subtitle: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 12, letterSpacing: 2, marginTop: space[8], marginBottom: space[3] },
  title: { color: colors.text, fontSize: 36, lineHeight: 43, fontFamily: fonts.title, marginBottom: space[6] },
  heading: { color: colors.text, fontFamily: fonts.medium, fontSize: 19, lineHeight: 27, marginBottom: space[2] },
  body: { color: colors.text, fontFamily: fonts.body, fontSize: 16, lineHeight: 25 },
  secondary: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, lineHeight: 22 },
  accent: { color: colors.accent, fontFamily: fonts.medium, fontSize: 32, fontVariant: ["tabular-nums"], marginVertical: space[4] },
  error: { color: colors.danger, fontFamily: fonts.body, fontSize: 15, lineHeight: 23, marginVertical: space[4] },
  footer: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 12, marginTop: space[8] },
  section: { borderTopColor: colors.rule, borderTopWidth: 1, marginTop: space[8], paddingTop: space[6] },
  sectionTitle: { color: colors.text, fontSize: 24, fontFamily: fonts.title, marginBottom: space[4] },
  row: { borderBottomColor: colors.rule, borderBottomWidth: 1, paddingVertical: space[4] },
  button: { borderColor: colors.rule, borderWidth: 1, minHeight: 48, padding: space[3], justifyContent: "center", marginVertical: space[3] },
  buttonText: { color: colors.text, fontFamily: fonts.medium, fontSize: 15, lineHeight: 23 }, disabled: { opacity: .4 }, pressed: { backgroundColor: colors.surfaceRaised },
})
