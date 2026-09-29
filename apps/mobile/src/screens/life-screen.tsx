import { useMemo } from "react"
import { ScrollView, StyleSheet, Text, View, Pressable } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import { queryDecision, queryLife, queryRoutine, type Command } from "@paralelo/simulation"
import { ActionButton } from "../components/screen-frame"
import { Portrait } from "../components/portrait"
import { useGame } from "../hooks/game-context"
import { colors, space, fonts } from "../theme"

export default function LifeScreen() {
  const { world, busy, error, notice, dispatch, retry } = useGame()
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const decision = useMemo(() => world ? queryDecision(world) : null, [world])
  const routine = useMemo(() => world ? queryRoutine(world) : null, [world])
  const action = (label: string, command: Command, disabled = false) => <Pressable
    accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled: busy || disabled || !!decision }}
    disabled={busy || disabled || !!decision} onPress={() => { void dispatch(command) }}
    style={({ pressed }) => [styles.action, (busy || disabled || !!decision) && styles.disabled, pressed && styles.pressed]}>
    <Text style={styles.actionText}>{label}</Text>
  </Pressable>
  return <SafeAreaView edges={["top", "left", "right"]} style={styles.root}>
    <ScrollView contentContainerStyle={styles.content}>
      <Text style={styles.wordmark}>PARALELO</Text>
      {!life ? <View style={styles.section}>
        <Text style={styles.title}>{busy ? "Abrindo sua vida…" : "Sua campanha precisa de atenção."}</Text>
        {error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}
        {!busy && <Pressable accessibilityRole="button" onPress={() => { void retry() }} style={styles.action}><Text style={styles.actionText}>Tentar novamente</Text></Pressable>}
      </View> : <>
        <View style={[styles.header, styles.headerRow]}>
          <View style={styles.headerText}>
            <Text style={styles.eyebrow}>VIDA · {life.city.toLocaleUpperCase("pt-BR")}</Text>
            <Text accessibilityRole="header" style={styles.title}>{life.name}</Text>
            <Text style={styles.body}>{life.age} anos · Morando por conta própria</Text>
            <Text style={styles.date}>{life.date}</Text>
            <Text style={styles.time}>{life.time}</Text>
          </View>
          <Portrait seed={life.appearance.seed} sex={life.appearance.sex} age={life.age} size={112} rotatable
            accessibilityLabel={`Retrato de ${life.name}, ${life.age} anos`} />
        </View>
        <Text style={styles.body}>{life.energy}</Text>
        <Text style={styles.secondary}>{life.stress}</Text>
        <Text style={styles.body}>{life.hunger}</Text>
        <Text style={styles.secondary}>{life.sleep}</Text>
        {error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}
        {notice && <Text accessibilityLiveRegion="polite" style={styles.secondary}>{notice}</Text>}
        {decision && <View style={styles.section}>
          <Text style={styles.eyebrow}>{decision.date} · UMA ESCOLHA</Text>
          <Text accessibilityRole="header" style={styles.sectionTitle}>{decision.title}</Text>
          <Text style={styles.story}>{decision.text}</Text>
          {decision.choices.map(choice => <View key={choice.id}><ActionButton label={choice.label} command={{ type: "decide", decisionId: decision.id, choiceId: choice.id }} disabled={!choice.canChoose} />{choice.reason && <Text style={styles.secondary}>{choice.reason}</Text>}</View>)}
        </View>}
        <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>Agora</Text>
          <View style={styles.actions}>{action("Descansar · 2 horas", { type: "rest" })}{action("Dormir · 8 horas", { type: "sleep" })}{action("Seguir o dia · 4 horas", { type: "wait", minutes: 240 })}</View>
          <Text style={styles.secondary}>Avançar pausa em decisões e avisos importantes. Dormir ou fazer uma tarefa consome o tempo inteiro; os compromissos continuam.</Text>
        </View>
        {routine && <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>Refeições e despensa</Text>
          <Text style={styles.body}>{routine.pantry}</Text>
          {routine.meals.map(meal => <View key={meal.source}>
            <ActionButton label={meal.label} command={{ type: "meal", source: meal.source }} disabled={!meal.canEat} />
            {meal.reason && <Text style={styles.secondary}>{meal.reason}</Text>}
          </View>)}
          <ActionButton label={routine.groceries.label} command={{ type: "buy-groceries" }} disabled={!routine.groceries.canBuy} />
          {routine.groceries.reason && <Text style={styles.secondary}>{routine.groceries.reason}</Text>}
          {routine.showCommunityWait && <ActionButton label={`Avançar até o almoço comunitário · ${routine.communityDate}, 11h`} command={{ type: "wait", minutes: routine.communityWait }} />}
        </View>}
        <View style={styles.section}>
          <Text accessibilityRole="header" style={styles.sectionTitle}>Na agenda</Text>
          {life.agenda.map(item => <View key={item.id} style={styles.person}><Text style={styles.secondary}>{item.date} · {item.time}</Text><Text style={styles.body}>{item.label}</Text></View>)}
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
  wordmark: { color: colors.text, fontFamily: fonts.label, fontSize: 14, letterSpacing: 4, paddingBottom: space[8], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  header: { paddingVertical: space[8] },
  headerRow: { flexDirection: "row", alignItems: "flex-end", gap: space[4] },
  headerText: { flex: 1, minWidth: 0 },
  eyebrow: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 2, marginBottom: space[3] },
  title: { color: colors.text, fontSize: 36, lineHeight: 44, fontFamily: fonts.title, marginBottom: space[2] },
  body: { color: colors.text, fontFamily: fonts.body, fontSize: 16, lineHeight: 25 },
  secondary: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, lineHeight: 22 },
  date: { color: colors.text, fontFamily: fonts.medium, fontSize: 18, marginTop: space[6] },
  time: { color: colors.accent, fontFamily: fonts.medium, fontSize: 38, marginTop: space[1], fontVariant: ["tabular-nums"] },
  section: { borderTopColor: colors.rule, borderTopWidth: 1, paddingTop: space[6], marginTop: space[8] },
  sectionTitle: { color: colors.text, fontSize: 24, fontFamily: fonts.title, marginBottom: space[4] },
  actions: { gap: space[2], marginBottom: space[3] },
  action: { borderColor: colors.rule, borderWidth: 1, paddingHorizontal: space[4], paddingVertical: space[3], minHeight: 48, justifyContent: "center", marginVertical: space[2] },
  actionText: { color: colors.text, fontFamily: fonts.medium, fontSize: 15, lineHeight: 23 },
  disabled: { opacity: .45 }, pressed: { backgroundColor: colors.surfaceRaised },
  person: { paddingVertical: space[4], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  personName: { color: colors.text, fontFamily: fonts.medium, fontSize: 19, marginBottom: space[1] },
  entry: { borderBottomColor: colors.rule, borderBottomWidth: 1, paddingVertical: space[6] },
  entryTime: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 12, marginBottom: space[3] },
  story: { color: colors.text, fontFamily: fonts.narrative, fontSize: 21, lineHeight: 29 },
  chapter: { fontFamily: fonts.narrative, fontSize: 25, lineHeight: 34 },
  error: { color: colors.danger, fontFamily: fonts.body, marginVertical: space[4], fontSize: 15, lineHeight: 23 },
  footer: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 12, marginTop: space[8] },
})
