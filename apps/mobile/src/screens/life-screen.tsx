import { useMemo } from "react"
import { StyleSheet, Text, useWindowDimensions, View } from "react-native"
import { queryDecision, queryLife, queryRoutine } from "@paralelo/simulation"
import { ActionRow, Kicker, Page, Prose, splitLabel, TimeRow, ui } from "../components/editorial"
import { DayBar } from "../components/game-feel"
import { LifeScene, sceneText } from "../components/scene"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

const shortDate = (date: string): string => {
  const [day, , month] = date.split(" ")
  return `${day} ${(month ?? "").slice(0, 3)}`
}

// VIDA: a data é o título; a timeline com horários é o eixo da tela (bíblia §6, §59, §70).
export default function LifeScreen() {
  const { world, busy, error, notice, retry } = useGame()
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const decision = useMemo(() => world ? queryDecision(world) : null, [world])
  const routine = useMemo(() => world ? queryRoutine(world) : null, [world])
  const { width: screen } = useWindowDimensions()
  const width = Math.min(screen, 640)

  if (!life) return <Page>
    <Text style={styles.day}>{busy ? "Abrindo sua vida…" : "Não foi possível abrir a campanha."}</Text>
    {error && <Text accessibilityRole="alert" style={ui.alert}>{error}</Text>}
    {!busy && <ActionRow label="Tentar novamente" onPress={() => { void retry() }} />}
  </Page>

  const days: { day: string; entries: typeof life.timeline }[] = []
  for (const entry of life.timeline) {
    const last = days[days.length - 1]
    if (last && last.day === entry.day) last.entries.push(entry)
    else days.push({ day: entry.day, entries: [entry] })
  }

  return <Page bare>
    <View style={styles.bleed}>
      <LifeScene width={width} minute={life.minute} city={life.city} seed={life.appearance.seed} sex={life.appearance.sex} age={life.age} expression={life.expression}>
        <View style={styles.sceneTop}>
          <View style={styles.headText}>
            <Text style={sceneText.kicker}>DIA {life.dayNumber} · {life.city.toLocaleUpperCase("pt-BR")}</Text>
            <Text accessibilityRole="header" style={sceneText.day}>{life.dayTitle}</Text>
          </View>
          <Text style={sceneText.time}>{life.time}</Text>
        </View>
      </LifeScene>
    </View>
    <View style={styles.dayBar}><DayBar minute={life.minute} marks={life.marks} width={width - 48} /></View>
    <Text style={styles.who}>{life.name}<Text style={styles.whoMuted}>  ·  {life.age} anos</Text></Text>
    <Text style={styles.state}>{life.body}</Text>
    {notice && <Text accessibilityLiveRegion="polite" style={styles.notice}>{notice}</Text>}

    {decision && <View style={styles.decision}>
      <Kicker meta={decision.date}>Uma escolha</Kicker>
      <Text accessibilityRole="header" style={styles.decisionTitle}>{decision.title}</Text>
      <Prose>{decision.text}</Prose>
      <View style={styles.choices}>
        {decision.choices.map(choice => <ActionRow key={choice.id} label={choice.label} disabled={!choice.canChoose} reason={choice.reason}
          command={{ type: "decide", decisionId: decision.id, choiceId: choice.id }} />)}
      </View>
    </View>}

    <Kicker meta="o relógio avança">Agora</Kicker>
    <ActionRow label="Descansar" meta="2 h" command={{ type: "rest" }} />
    <ActionRow label="Dormir" meta="8 h" command={{ type: "sleep" }} />
    <ActionRow label="Seguir o dia" meta="4 h" command={{ type: "wait", minutes: 240 }} />
    <Text style={ui.reason}>Avançar para quando uma decisão ou um aviso importante chegar.</Text>

    {routine && <>
      <Kicker meta={routine.pantry}>Comer</Kicker>
      {routine.meals.map(meal => {
        const [label, meta] = splitLabel(meal.label)
        return <ActionRow key={meal.source} label={label} meta={meta} disabled={!meal.canEat} reason={meal.reason} command={{ type: "meal", source: meal.source }} />
      })}
      {(() => {
        const [label, meta] = splitLabel(routine.groceries.label)
        return <ActionRow label={label} meta={meta} disabled={!routine.groceries.canBuy} reason={routine.groceries.reason} command={{ type: "buy-groceries" }} />
      })()}
      {routine.showCommunityWait && <ActionRow label="Esperar o almoço comunitário" meta={`${routine.communityDate}, 11h`} command={{ type: "wait", minutes: routine.communityWait }} />}
    </>}

    {!!life.agenda.length && <>
      <Kicker>Na agenda</Kicker>
      {life.agenda.map(item => <TimeRow key={item.id} time={shortDate(item.date)}>
        <Text style={ui.entry}>{item.label}</Text><Text style={styles.agendaTime}>{item.time}</Text>
      </TimeRow>)}
    </>}

    {days.map(group => <View key={group.day}>
      <Kicker>{group.day}</Kicker>
      {group.entries.map(entry => <TimeRow key={entry.id} time={entry.time} emphasis={entry.kind === "chapter"}>{entry.text}</TimeRow>)}
    </View>)}
  </Page>
}

const styles = StyleSheet.create({
  bleed: { marginHorizontal: -space[6], marginTop: -space[4] },
  sceneTop: { flexDirection: "row", alignItems: "flex-start", gap: space[4], marginTop: space[6] },
  headText: { flex: 1, minWidth: 0 },
  dayBar: { marginTop: space[3] },
  day: { color: colors.text, fontFamily: fonts.title, fontSize: 34, lineHeight: 40, marginTop: space[1] },
  who: { color: colors.text, fontFamily: fonts.medium, fontSize: 14, lineHeight: 21, marginTop: space[2] },
  whoMuted: { color: colors.textSecondary, fontFamily: fonts.body },
  state: { color: colors.text, fontFamily: fonts.narrative, fontSize: 19, lineHeight: 29, marginTop: space[6] },
  notice: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, lineHeight: 21, marginTop: space[3] },
  decision: { marginTop: space[2] },
  decisionTitle: { color: colors.text, fontFamily: fonts.title, fontSize: 24, lineHeight: 30, marginTop: space[2] },
  choices: { marginTop: space[3], borderTopColor: colors.rule, borderTopWidth: StyleSheet.hairlineWidth },
  agendaTime: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 },
})
