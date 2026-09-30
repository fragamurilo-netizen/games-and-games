// Presença (bíblia §33): o tempo anda na régua, cada ação deixa uma consequência visível,
// a virada de dia é um capítulo e uma decisão toma a tela com a pessoa envolvida.
import { useEffect, useMemo, useRef, useState } from "react"
import { Animated, Easing, Modal, Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from "react-native"
import * as Haptics from "expo-haptics"
import { queryDecision, queryLife, queryPeriod, queryWorkScene } from "@paralelo/simulation"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"
import { ActionRow } from "./editorial"
import { Portrait } from "./portrait"
import { LifeScene } from "./scene"

const buzz = (kind: "light" | "success" | "warning"): void => {
  const p = kind === "light" ? Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)
    : Haptics.notificationAsync(kind === "success" ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning)
  p.catch(() => undefined)
}

// ---------------- régua do dia ----------------
const START = 360, END = 1440
export function DayBar({ minute, marks, width }: { minute: number; marks: readonly { id: string; minute: number; label: string }[]; width: number }) {
  const x = (m: number): number => ((Math.min(Math.max(m, START), END) - START) / (END - START)) * width
  const pos = useRef(new Animated.Value(x(minute))).current
  const last = useRef(minute)
  useEffect(() => {
    const forward = minute > last.current
    last.current = minute
    if (forward) Animated.timing(pos, { toValue: x(minute), duration: 900, easing: Easing.inOut(Easing.cubic), useNativeDriver: true }).start()
    else pos.setValue(x(minute))
  }, [minute, width]) // eslint-disable-line react-hooks/exhaustive-deps
  return <View style={{ width, height: 46 }} accessibilityLabel={`Hora do dia: ${Math.floor(minute / 60)}h`}>
    <View style={[bar.track, { width }]} />
    <View style={[bar.past, { width: x(minute) }]} />
    {[6, 9, 12, 15, 18, 21, 24].map(h => <View key={h} style={[bar.tick, { left: x(h * 60) }]}>
      <Text style={[bar.hour, h === 24 && { transform: [{ translateX: -14 }] }]}>{h === 24 ? "0h" : `${h}h`}</Text>
    </View>)}
    {marks.filter(m => m.minute >= START).map(m => <View key={m.id} style={[bar.mark, { left: x(m.minute) }]} accessibilityLabel={`${m.label} às ${Math.floor(m.minute / 60)}h`} />)}
    <Animated.View style={[bar.needle, { transform: [{ translateX: pos }] }]} />
  </View>
}
const bar = StyleSheet.create({
  track: { position: "absolute", top: 8, height: 2, backgroundColor: colors.rule },
  past: { position: "absolute", top: 8, height: 2, backgroundColor: colors.textMuted },
  tick: { position: "absolute", top: 4, width: 1, height: 10, backgroundColor: colors.rule },
  hour: { position: "absolute", top: 14, left: -6, color: colors.textMuted, fontFamily: fonts.medium, fontSize: 11, fontVariant: ["tabular-nums"], width: 30 },
  mark: { position: "absolute", top: 3, width: 3, height: 12, marginLeft: -1, backgroundColor: colors.warning, borderRadius: 1 },
  needle: { position: "absolute", top: 0, width: 3, height: 18, marginLeft: -1, backgroundColor: colors.accent, borderRadius: 2 },
})

// ---------------- consequência da última ação ----------------
export function Consequence() {
  const { world } = useGame()
  const head = useMemo(() => world ? queryLife(world).timeline[0] ?? null : null, [world])
  const clock = world ? world.clock.day * 1440 + world.clock.minute : null
  const lastClock = useRef<number | null>(null)
  const seen = useRef<string | null>(null)
  const [shown, setShown] = useState<{ time: string; text: string } | null>(null)
  const y = useRef(new Animated.Value(40)).current, o = useRef(new Animated.Value(0)).current
  useEffect(() => {
    if (!head || clock === null) return
    const before = lastClock.current
    lastClock.current = clock
    if (seen.current === null) { seen.current = head.id; return }
    if (before !== null && clock - before >= 720 && world) {
      // salto grande: um resumo feito dos fatos do período, não uma enxurrada (bíblia §6.3)
      seen.current = head.id
      const period = queryPeriod(world, before + 1)
      const text = [period.span, period.top?.text, period.routine].filter(Boolean).join(" ")
      setShown({ time: head.time, text: text || "O tempo passou sem novidade." })
    } else if (head.id === seen.current) {
      // o tempo passou sem acontecimento: ainda assim o jogo responde
      if (before === null || clock - before < 60) return
      const hours = Math.round((clock - before) / 60)
      const now = `${String(Math.floor((clock % 1440) / 60)).padStart(2, "0")}:${String(clock % 60).padStart(2, "0")}`
      setShown({ time: now, text: hours === 1 ? "Uma hora depois. Nada mudou por aqui." : `${hours} horas depois. O dia seguiu sem novidade.` })
    } else {
      seen.current = head.id
      setShown({ time: head.time, text: head.text })
    }
    buzz("light")
    y.setValue(40); o.setValue(0)
    Animated.parallel([Animated.timing(y, { toValue: 0, duration: 320, easing: Easing.out(Easing.cubic), useNativeDriver: true }), Animated.timing(o, { toValue: 1, duration: 260, useNativeDriver: true })]).start()
    const timer = setTimeout(() => Animated.timing(o, { toValue: 0, duration: 400, useNativeDriver: true }).start(() => setShown(null)), 4200)
    return () => clearTimeout(timer)
  }, [head, clock, o, y])
  if (!shown) return null
  return <Animated.View pointerEvents="box-none" style={[toast.wrap, { opacity: o, transform: [{ translateY: y }] }]}>
    <Pressable accessibilityRole="alert" onPress={() => setShown(null)} style={toast.card}>
      <Text style={toast.time}>{shown.time}</Text>
      <Text style={toast.text}>{shown.text}</Text>
    </Pressable>
  </Animated.View>
}
const toast = StyleSheet.create({
  wrap: { position: "absolute", left: space[4], right: space[4], bottom: space[4] },
  card: { flexDirection: "row", gap: space[3], backgroundColor: colors.surfaceRaised, borderLeftColor: colors.accent, borderLeftWidth: 3, paddingVertical: space[3], paddingHorizontal: space[4], maxWidth: 600, alignSelf: "center", width: "100%" },
  time: { color: colors.accent, fontFamily: fonts.medium, fontSize: 13, lineHeight: 22, fontVariant: ["tabular-nums"] },
  text: { flex: 1, color: colors.text, fontFamily: fonts.narrative, fontSize: 16, lineHeight: 22 },
})

// ---------------- virada de dia ----------------
export function DayTurn() {
  const { world } = useGame()
  const day = world?.clock.day ?? null
  const last = useRef<number | null>(null)
  const [card, setCard] = useState<{ title: string; number: number } | null>(null)
  const o = useRef(new Animated.Value(0)).current
  useEffect(() => {
    if (day === null || !world) return
    if (last.current === null || day <= last.current) { last.current = day; return }
    last.current = day
    const life = queryLife(world)
    setCard({ title: life.dayTitle, number: life.dayNumber })
    buzz("success")
    o.setValue(0)
    Animated.sequence([
      Animated.timing(o, { toValue: 1, duration: 450, useNativeDriver: true }),
      Animated.delay(1300),
      Animated.timing(o, { toValue: 0, duration: 550, useNativeDriver: true }),
    ]).start(() => setCard(null))
  }, [day]) // eslint-disable-line react-hooks/exhaustive-deps
  if (!card) return null
  return <Animated.View style={[turn.root, { opacity: o }]}>
    <Pressable style={turn.fill} accessibilityRole="button" accessibilityLabel={`Novo dia: ${card.title}`} onPress={() => { o.stopAnimation(); setCard(null) }}>
      <Text style={turn.kicker}>DIA {card.number}</Text>
      <Text style={turn.title}>{card.title}</Text>
    </Pressable>
  </Animated.View>
}
const turn = StyleSheet.create({
  root: { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: colors.bg },
  fill: { flex: 1, justifyContent: "center", paddingHorizontal: space[8] },
  kicker: { color: colors.accent, fontFamily: fonts.label, fontSize: 12, letterSpacing: 2.4 },
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 40, lineHeight: 46, marginTop: space[2] },
})

// ---------------- decisão em cena ----------------
export function DecisionScene() {
  const { world } = useGame()
  const decision = useMemo(() => world ? queryDecision(world) : null, [world])
  const [later, setLater] = useState<string | null>(null)
  useEffect(() => { if (decision && decision.id !== later) buzz("warning") }, [decision?.id]) // eslint-disable-line react-hooks/exhaustive-deps
  const open = !!decision && decision.id !== later
  // sem outra pessoa envolvida, a escolha acontece no lugar e na hora em que você está
  const life = useMemo(() => world && decision && !decision.actor ? queryLife(world) : null, [world, decision])
  const { width: screen } = useWindowDimensions()
  const width = Math.min(screen, 600)
  return <Modal visible={open} animationType="slide" transparent={false} onRequestClose={() => decision && setLater(decision.id)}>
    {decision && <View style={scene.root}>
      <ScrollView contentContainerStyle={scene.content}>
        {life && <View style={scene.bleed}>
          <LifeScene width={width} height={Math.round(width * 0.62)} minute={life.minute} city={life.city} seed={life.appearance.seed}
            sex={life.appearance.sex} age={life.age} expression="tense" />
        </View>}
        {decision.actor && <View style={scene.actor}>
          <Portrait seed={decision.actor.appearance.seed} sex={decision.actor.appearance.sex} age={decision.actor.age} size={160} expression="curious"
            accessibilityLabel={`${decision.actor.name}`} />
          <Text style={scene.actorName}>{decision.actor.name}</Text>
        </View>}
        <Text style={scene.kicker}>UMA ESCOLHA · {decision.date.toLocaleUpperCase("pt-BR")}</Text>
        <Text accessibilityRole="header" style={scene.title}>{decision.title}</Text>
        <Text style={scene.text}>{decision.text}</Text>
        <View style={scene.choices}>
          {decision.choices.map(choice => <ActionRow key={choice.id} label={choice.label.split(" · ")[0]!} meta={choice.label.split(" · ")[1]}
            disabled={!choice.canChoose} reason={choice.reason} command={{ type: "decide", decisionId: decision.id, choiceId: choice.id }} />)}
        </View>
        <Pressable accessibilityRole="button" onPress={() => setLater(decision.id)} style={scene.later}><Text style={scene.laterText}>Pensar depois</Text></Pressable>
      </ScrollView>
    </View>}
  </Modal>
}
const scene = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space[6], paddingTop: space[12], paddingBottom: space[12], maxWidth: 600, width: "100%", alignSelf: "center" },
  actor: { alignItems: "flex-start", marginBottom: space[6] },
  bleed: { marginHorizontal: -space[6], marginTop: -space[12], marginBottom: space[6] },
  actorName: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 13, marginTop: space[2] },
  kicker: { color: colors.warning, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6 },
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 30, lineHeight: 36, marginTop: space[2] },
  text: { color: colors.text, fontFamily: fonts.narrative, fontSize: 19, lineHeight: 29, marginTop: space[4] },
  choices: { marginTop: space[6], borderTopColor: colors.rule, borderTopWidth: StyleSheet.hairlineWidth },
  later: { marginTop: space[6], paddingVertical: space[3] },
  laterText: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 14 },
})

// ---------------- trabalho em cena (bíblia §7, §46) ----------------
export function WorkScene() {
  const { world, dispatch, busy } = useGame()
  const scene = useMemo(() => world && !world.events.pending ? queryWorkScene(world) : null, [world])
  const life = useMemo(() => world && scene && !scene.actor ? queryLife(world) : null, [world, scene])
  const { width: screen } = useWindowDimensions()
  const width = Math.min(screen, 600)
  useEffect(() => { if (scene) buzz("warning") }, [scene?.id]) // eslint-disable-line react-hooks/exhaustive-deps
  const kicker = scene ? (scene.kind === "shift" ? "NO TURNO" : scene.kind === "review" ? "CONVERSA DO MÊS" : "ENTREVISTA") : ""
  return <Modal visible={!!scene} animationType="slide" transparent={false} onRequestClose={() => undefined}>
    {scene && <View style={work.root}>
      <ScrollView contentContainerStyle={work.content}>
        {scene.actor ? <View style={work.actor}>
          <Portrait seed={scene.actor.appearance.seed} sex={scene.actor.appearance.sex} age={scene.actor.age} size={150} expression={scene.kind === "review" ? "neutral" : "curious"} accessibilityLabel={scene.actor.name} />
          <View style={work.actorText}>
            <Text style={work.actorName}>{scene.actor.name}</Text>
            {scene.actor.role && <Text style={work.actorRole}>{scene.actor.role}</Text>}
          </View>
        </View> : life && <View style={scene_.bleed}>
          <LifeScene width={width} height={Math.round(width * 0.55)} minute={life.minute} city={life.city} seed={life.appearance.seed} sex={life.appearance.sex} age={life.age} expression="tense" />
        </View>}
        <Text style={work.kicker}>{kicker} · {scene.time}</Text>
        <Text accessibilityRole="header" style={work.title}>{scene.title}</Text>
        {scene.text.map((line, i) => <Text key={i} style={[work.text, i > 0 && work.textMore]}>{line}</Text>)}
        <View style={work.choices}>
          {scene.choices.map(choice => <Pressable key={choice.id} accessibilityRole="button" disabled={busy || !choice.canChoose}
            accessibilityLabel={[choice.label, choice.meta, choice.hint].filter(Boolean).join(", ")} accessibilityState={{ disabled: busy || !choice.canChoose }}
            onPress={() => { void dispatch({ type: "work-choice", sceneId: scene.id, choiceId: choice.id }) }}
            style={({ pressed }) => [work.choice, pressed && work.pressed]}>
            <View style={work.choiceHead}>
              <Text style={[work.choiceLabel, !choice.canChoose && work.off]}>{choice.label}</Text>
              {choice.meta && <Text style={work.meta}>{choice.meta}</Text>}
            </View>
            {choice.hint && <Text style={[work.hint, choice.hint === "arriscado" && work.risky]}>{choice.hint.charAt(0).toUpperCase() + choice.hint.slice(1)}.</Text>}
            {!choice.canChoose && choice.reason && <Text style={work.hint}>{choice.reason}</Text>}
          </Pressable>)}
        </View>
      </ScrollView>
    </View>}
  </Modal>
}
const scene_ = StyleSheet.create({ bleed: { marginHorizontal: -space[6], marginTop: -space[12], marginBottom: space[6] } })
const work = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space[6], paddingTop: space[12], paddingBottom: space[12], maxWidth: 600, width: "100%", alignSelf: "center" },
  actor: { flexDirection: "row", alignItems: "flex-end", gap: space[4], marginBottom: space[6] },
  actorText: { flex: 1, paddingBottom: space[2] },
  actorName: { color: colors.text, fontFamily: fonts.title, fontSize: 20, lineHeight: 25 },
  actorRole: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, marginTop: 2 },
  kicker: { color: colors.accent, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6 },
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 28, lineHeight: 34, marginTop: space[2] },
  text: { color: colors.text, fontFamily: fonts.narrative, fontSize: 19, lineHeight: 29, marginTop: space[4] },
  textMore: { marginTop: space[2], color: colors.textSecondary, fontSize: 17, lineHeight: 26 },
  choices: { marginTop: space[6], borderTopColor: colors.rule, borderTopWidth: StyleSheet.hairlineWidth },
  choice: { paddingVertical: space[4], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth, minHeight: 56 },
  pressed: { backgroundColor: colors.surface },
  choiceHead: { flexDirection: "row", alignItems: "baseline", gap: space[4] },
  choiceLabel: { flex: 1, color: colors.text, fontFamily: fonts.medium, fontSize: 17, lineHeight: 24 },
  meta: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, fontVariant: ["tabular-nums"] },
  hint: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[1] },
  risky: { color: colors.warning },
  off: { color: colors.textMuted },
})
