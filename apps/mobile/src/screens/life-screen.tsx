import { useMemo } from "react"
import { ScrollView, StyleSheet, Text, View, Pressable } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import { queryLife, type Command } from "@paralelo/simulation"
import { useGame } from "../hooks/game-context"
import { colors, space } from "../theme"

export default function LifeScreen() {
  const { world, busy, error, notice, dispatch, retry } = useGame()
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const action = (label: string, command: Command, disabled = false) => <Pressable
    accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled: busy || disabled }}
    disabled={busy || disabled} onPress={() => { void dispatch(command) }}
    style={({ pressed }) => [styles.action, (busy || disabled) && styles.disabled, pressed && styles.pressed]}>
    <Text style={styles.actionText}>{label}</Text>
  </Pressable>
  return <SafeAreaView style={styles.root}>
    <ScrollView contentContainerStyle={styles.content}>
      <Text style={styles.wordmark}>PARALELO</Text>
      {!life ? <View style={styles.section}>
        <Text style={styles.title}>{busy ? "Abrindo sua vida…" : "Sua campanha precisa de atenção."}</Text>
        {error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}
        {!busy && <Pressable accessibilityRole="button" onPress={() => { void retry() }} style={styles.action}><Text style={styles.actionText}>Tentar novamente</Text></Pressable>}
      </View> : <>
        <View style={styles.header}>
          <Text style={styles.eyebrow}>VIDA · {life.city.toLocaleUpperCase("pt-BR")}</Text>
          <Text accessibilityRole="header" style={styles.title}>{life.name}</Text>
          <Text style={styles.body}>{life.age} anos · Morando por conta própria</Text>
          <Text style={styles.date}>{life.date}</Text>
          <Text style={styles.time}>{life.time}</Text>
        </View>
        <Text style={styles.body}>{life.energy}</Text>
        <Text style={styles.secondary}>{life.stress}</Text>
        {error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}
        {notice && <Text accessibilityLiveRegion="polite" style={styles.secondary}>{notice}</Text>}
        <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>Agora</Text>
          <View style={styles.actions}>{action("Descansar · 2 horas", { type: "rest" })}{action("Seguir o dia · 4 horas", { type: "wait", minutes: 240 })}</View>
          <Text style={styles.secondary}>O tempo para quando chega uma mensagem importante.</Text>
        </View>
        <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>Pessoas próximas</Text>
          {life.people.map(person => <View key={person.id} style={styles.person}>
            <Text style={styles.personName}>{person.name}</Text><Text style={styles.secondary}>{person.description} · {person.age} anos</Text>
            <Text style={styles.body}>{person.state}</Text>
            {action(`Ligar para ${person.name.split(" ")[0]}`, { type: "contact", personId: person.id }, !person.canContact)}
            {person.unavailableReason && <Text style={styles.secondary}>{person.unavailableReason}</Text>}
          </View>)}
        </View>
        <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>O que ficou do dia</Text>
          {life.timeline.map(entry => <View key={entry.id} style={styles.entry}>
            <Text style={styles.entryTime}>{entry.time}<Text style={styles.secondary}> · {entry.date}</Text></Text>
            <Text style={[styles.story, entry.kind === "chapter" && styles.chapter]}>{entry.text}</Text>
          </View>)}
        </View>
        <Text style={styles.footer}>{busy ? "Guardando sua campanha…" : "Sua campanha é salva a cada ação."}</Text>
      </>}
    </ScrollView>
  </SafeAreaView>
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space[6], paddingTop: space[6], paddingBottom: space[12], maxWidth: 680, width: "100%", alignSelf: "center" },
  wordmark: { color: colors.text, fontSize: 14, letterSpacing: 4, fontWeight: "700", paddingBottom: space[8], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  header: { paddingVertical: space[8] },
  eyebrow: { color: colors.textSecondary, fontSize: 11, letterSpacing: 2, marginBottom: space[3] },
  title: { color: colors.text, fontSize: 34, lineHeight: 42, fontFamily: "serif", marginBottom: space[2] },
  body: { color: colors.text, fontSize: 16, lineHeight: 24 },
  secondary: { color: colors.textSecondary, fontSize: 14, lineHeight: 21 },
  date: { color: colors.text, fontSize: 18, marginTop: space[6] },
  time: { color: colors.accent, fontSize: 38, marginTop: space[1], fontVariant: ["tabular-nums"] },
  section: { borderTopColor: colors.rule, borderTopWidth: 1, paddingTop: space[6], marginTop: space[8] },
  sectionTitle: { color: colors.text, fontSize: 20, fontFamily: "serif", marginBottom: space[4] },
  actions: { gap: space[2], marginBottom: space[3] },
  action: { borderColor: colors.rule, borderWidth: 1, paddingHorizontal: space[4], paddingVertical: space[3], minHeight: 48, justifyContent: "center", marginVertical: space[2] },
  actionText: { color: colors.text, fontSize: 15 },
  disabled: { opacity: .45 }, pressed: { backgroundColor: colors.surfaceRaised },
  person: { paddingVertical: space[4], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  personName: { color: colors.text, fontSize: 19, marginBottom: space[1] },
  entry: { borderBottomColor: colors.rule, borderBottomWidth: 1, paddingVertical: space[6] },
  entryTime: { color: colors.textSecondary, fontSize: 12, marginBottom: space[3] },
  story: { color: colors.text, fontSize: 17, lineHeight: 27 },
  chapter: { fontFamily: "serif", fontSize: 22, lineHeight: 32 },
  error: { color: colors.danger, marginVertical: space[4], fontSize: 15, lineHeight: 23 },
  footer: { color: colors.textSecondary, fontSize: 12, marginTop: space[8] },
})
