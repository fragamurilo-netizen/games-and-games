// Gramática editorial das telas (bíblia §27–31, §69–70):
// espaço e tipografia antes de caixas, filetes estruturais, horários e valores em coluna,
// ações como linhas de texto (verbo à esquerda, custo à direita), acento verde raro.
import type { ReactNode } from "react"
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import type { Command } from "@paralelo/simulation"
import { Link } from "expo-router"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

/** Página: faixa superior discreta com a marca e a hora da campanha; sem título-slogan. */
export function Page({ children, time }: { children: ReactNode; time?: string }) {
  const { error, busy, world } = useGame()
  return <SafeAreaView edges={["top", "left", "right"]} style={ui.root}>
    <ScrollView contentContainerStyle={ui.content}>
      <View style={ui.masthead}>
        <Text style={ui.wordmark}>PARALELO</Text>
        {time && <Text style={ui.clock}>{time}</Text>}
      </View>
      {error && <Text accessibilityRole="alert" style={ui.alert}>{error}</Text>}
      {world?.events.pending && <Link href="/" style={ui.pending}>Uma decisão espera sua resposta em Vida.</Link>}
      {children}
      <Text accessibilityLiveRegion="polite" style={ui.saved}>{busy ? "Guardando…" : "Salvo."}</Text>
    </ScrollView>
  </SafeAreaView>
}

/** Rótulo pequeno em caixa alta sobre um filete, com metadado opcional à direita. */
export function Kicker({ children, meta, first = false }: { children: string; meta?: string; first?: boolean }) {
  return <View style={[ui.kicker, first && ui.kickerFirst]}>
    <Text accessibilityRole="header" style={ui.kickerText}>{children.toLocaleUpperCase("pt-BR")}</Text>
    {meta && <Text style={ui.kickerMeta}>{meta}</Text>}
  </View>
}

export function Prose({ children, tone = "primary" }: { children: ReactNode; tone?: "primary" | "secondary" | "warning" | "danger" }) {
  return <Text style={[ui.prose, tone === "secondary" && ui.secondary, tone === "warning" && ui.warning, tone === "danger" && ui.danger]}>{children}</Text>
}

/** Ação como linha: verbo e custo. O motivo aparece quando a ação não está disponível. */
export function ActionRow({ label, meta, command, disabled = false, reason, onPress }: {
  label: string; meta?: string; command?: Command; disabled?: boolean; reason?: string | null; onPress?: () => void
}) {
  const { busy, dispatch, world } = useGame()
  const blocked = disabled || (!!command && !!world?.events.pending && command.type !== "decide")
  const off = busy || blocked
  return <View>
    <Pressable accessibilityRole="button" accessibilityLabel={meta ? `${label}, ${meta}` : label} accessibilityState={{ disabled: off }} disabled={off}
      onPress={() => { if (onPress) onPress(); else if (command) void dispatch(command) }}
      style={({ pressed }) => [ui.action, pressed && ui.actionPressed]}>
      <Text style={[ui.actionLabel, off && ui.actionOff]}>{label}</Text>
      {meta && <Text style={[ui.actionMeta, off && ui.actionOff]}>{meta}</Text>}
    </Pressable>
    {blocked && reason && <Text style={ui.reason}>{reason}</Text>}
  </View>
}

/** Divide "Descansar · 2 horas" em verbo e custo. */
export const splitLabel = (text: string): [string, string | undefined] => {
  const i = text.indexOf(" · ")
  return i < 0 ? [text, undefined] : [text.slice(0, i), text.slice(i + 3)]
}

/** Fato objetivo: rótulo à esquerda, valor alinhado à direita. */
export function FactRow({ label, value, tone }: { label: string; value: string; tone?: "positive" | "negative" | "muted" }) {
  return <View style={ui.fact}>
    <Text style={ui.factLabel}>{label}</Text>
    <Text style={[ui.factValue, tone === "positive" && ui.positive, tone === "negative" && ui.danger, tone === "muted" && ui.secondary]}>{value}</Text>
  </View>
}

/** Linha com coluna de tempo à esquerda (horário ou data curta). */
export function TimeRow({ time, children, emphasis = false }: { time: string; children: ReactNode; emphasis?: boolean }) {
  return <View style={ui.timeRow}>
    <Text style={ui.timeCol}>{time}</Text>
    <View style={ui.timeBody}>{typeof children === "string" ? <Text style={[ui.entry, emphasis && ui.entryMark]}>{children}</Text> : children}</View>
  </View>
}

export const ui = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space[6], paddingTop: space[4], paddingBottom: space[12], maxWidth: 640, width: "100%", alignSelf: "center" },
  masthead: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", paddingBottom: space[3], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  wordmark: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 3 },
  clock: { color: colors.text, fontFamily: fonts.medium, fontSize: 13, fontVariant: ["tabular-nums"] },
  alert: { color: colors.danger, fontFamily: fonts.body, fontSize: 15, lineHeight: 22, marginTop: space[4] },
  pending: { color: colors.warning, fontFamily: fonts.medium, fontSize: 14, lineHeight: 21, marginTop: space[4] },
  saved: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 12, marginTop: space[8] },
  kicker: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", borderTopColor: colors.rule, borderTopWidth: 1, marginTop: space[8], paddingTop: space[3], marginBottom: space[2] },
  kickerFirst: { marginTop: space[6] },
  kickerText: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6 },
  kickerMeta: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 12, fontVariant: ["tabular-nums"] },
  prose: { color: colors.text, fontFamily: fonts.narrative, fontSize: 18, lineHeight: 27, marginTop: space[2] },
  secondary: { color: colors.textSecondary },
  warning: { color: colors.warning },
  danger: { color: colors.danger },
  positive: { color: colors.accent },
  action: { flexDirection: "row", alignItems: "baseline", justifyContent: "space-between", gap: space[4], minHeight: 52, paddingVertical: space[3], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  actionPressed: { backgroundColor: colors.surface },
  actionLabel: { flex: 1, color: colors.text, fontFamily: fonts.medium, fontSize: 16, lineHeight: 23 },
  actionMeta: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, fontVariant: ["tabular-nums"] },
  actionOff: { color: colors.textMuted },
  reason: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[1], marginBottom: space[2] },
  fact: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", gap: space[4], paddingVertical: space[2] },
  factLabel: { flex: 1, color: colors.textSecondary, fontFamily: fonts.body, fontSize: 15 },
  factValue: { color: colors.text, fontFamily: fonts.medium, fontSize: 15, fontVariant: ["tabular-nums"] },
  timeRow: { flexDirection: "row", gap: space[4], paddingVertical: space[2] },
  timeCol: { width: 48, color: colors.textMuted, fontFamily: fonts.medium, fontSize: 13, lineHeight: 24, fontVariant: ["tabular-nums"] },
  timeBody: { flex: 1, minWidth: 0 },
  entry: { color: colors.text, fontFamily: fonts.body, fontSize: 15, lineHeight: 23 },
  entryMark: { fontFamily: fonts.narrative, fontSize: 18, lineHeight: 26 },
})
