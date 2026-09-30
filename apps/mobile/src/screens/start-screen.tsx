// Começo (bíblia §47): identidade básica e ponto de partida numa só página, com o personagem
// na cena mudando a cada escolha. Nada de tutorial; o resto se aprende vivendo.
import { useMemo, useState } from "react"
import { Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import { startAges, startingPoints, validateProfile, type StartingPoint } from "@paralelo/simulation"
import { LifeScene, sceneText } from "../components/scene"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

const newSeed = (): string => `santa-aurora/${Date.now().toString(36)}`

export default function StartScreen() {
  const { start, busy, error } = useGame()
  const { width: screen } = useWindowDimensions()
  const width = Math.min(screen, 640)
  const [seed, setSeed] = useState(newSeed)
  const [firstName, setFirstName] = useState("")
  const [sex, setSex] = useState<"F" | "M">("F")
  const [age, setAge] = useState(22)
  const [point, setPoint] = useState<StartingPoint>("job-search")
  const profile = { firstName, sex, age, start: point }
  const check = useMemo(() => validateProfile(profile), [firstName, sex, age, point]) // eslint-disable-line react-hooks/exhaustive-deps
  const shown = firstName.trim() || "Você"

  return <SafeAreaView edges={["top", "left", "right", "bottom"]} style={styles.root}>
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <View style={styles.bleed}>
        <LifeScene width={width} height={Math.round(width * 0.9)} minute={450} city="Santa Aurora" seed={`${seed}/person:player`} sex={sex} age={age} expression="curious">
          <Text style={sceneText.kicker}>SANTA AURORA · VILA DAS FLORES</Text>
          <Text accessibilityRole="header" style={sceneText.day}>{shown}, {age} anos</Text>
        </LifeScene>
      </View>
      <Pressable accessibilityRole="button" onPress={() => setSeed(newSeed())} style={styles.reroll}>
        <Text style={styles.rerollText}>Outro rosto</Text>
      </Pressable>

      <Text style={styles.lede}>Primeira semana morando por conta própria. As caixas da mudança ainda estão no corredor.</Text>

      <Text style={styles.label}>NOME</Text>
      <TextInput value={firstName} onChangeText={setFirstName} placeholder="Como você se chama" placeholderTextColor={colors.textMuted}
        autoCapitalize="words" autoCorrect={false} maxLength={24} returnKeyType="done" accessibilityLabel="Nome" style={styles.input} />
      <Text style={styles.hint}>O sobrenome vem da sua mãe, Helena Ferreira.</Text>

      <Text style={styles.label}>CORPO</Text>
      <View style={styles.row}>
        {([["F", "Feminino"], ["M", "Masculino"]] as const).map(([value, label]) =>
          <Pressable key={value} accessibilityRole="radio" accessibilityState={{ selected: sex === value }} onPress={() => setSex(value)} style={styles.choice}>
            <Text style={[styles.choiceText, sex === value && styles.selected]}>{label}</Text>
          </Pressable>)}
      </View>

      <Text style={styles.label}>IDADE</Text>
      <View style={styles.row}>
        <Pressable accessibilityRole="button" accessibilityLabel="Menos um ano" disabled={age <= startAges.min} onPress={() => setAge(a => a - 1)} style={styles.step}>
          <Text style={[styles.stepText, age <= startAges.min && styles.off]}>−</Text>
        </Pressable>
        <Text style={styles.age}>{age} anos</Text>
        <Pressable accessibilityRole="button" accessibilityLabel="Mais um ano" disabled={age >= startAges.max} onPress={() => setAge(a => a + 1)} style={styles.step}>
          <Text style={[styles.stepText, age >= startAges.max && styles.off]}>+</Text>
        </Pressable>
      </View>

      <Text style={styles.label}>PONTO DE PARTIDA</Text>
      {startingPoints.map(p => <Pressable key={p.id} accessibilityRole="radio" accessibilityState={{ selected: point === p.id }} onPress={() => setPoint(p.id)}
        style={[styles.point, point === p.id && styles.pointOn]}>
        <Text style={[styles.pointTitle, point === p.id && styles.selected]}>{p.title}</Text>
        <Text style={styles.pointText}>{p.text}</Text>
      </Pressable>)}

      {error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}
      <Pressable accessibilityRole="button" disabled={busy || !check.ok} onPress={() => { void start(profile, seed) }}
        style={({ pressed }) => [styles.begin, pressed && styles.pressed]}>
        <Text style={[styles.beginText, (busy || !check.ok) && styles.off]}>{busy ? "Abrindo a porta…" : "Começar a vida"}</Text>
        <Text style={styles.beginMeta}>{check.ok ? "segunda, 8h" : firstName.trim() ? check.error : "escreva um nome"}</Text>
      </Pressable>
    </ScrollView>
  </SafeAreaView>
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { paddingHorizontal: space[6], paddingBottom: space[12], maxWidth: 640, width: "100%", alignSelf: "center" },
  bleed: { marginHorizontal: -space[6] },
  reroll: { alignSelf: "flex-end", minHeight: 44, justifyContent: "center" },
  rerollText: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 14 },
  lede: { color: colors.text, fontFamily: fonts.narrative, fontSize: 19, lineHeight: 29, marginTop: space[2] },
  label: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6, marginTop: space[8], marginBottom: space[2] },
  input: { color: colors.text, fontFamily: fonts.title, fontSize: 28, paddingVertical: space[2], borderBottomColor: colors.rule, borderBottomWidth: 1 },
  hint: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[2] },
  row: { flexDirection: "row", alignItems: "center", gap: space[6] },
  choice: { minHeight: 44, justifyContent: "center" },
  choiceText: { color: colors.textSecondary, fontFamily: fonts.medium, fontSize: 17 },
  selected: { color: colors.accent },
  step: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  stepText: { color: colors.text, fontFamily: fonts.medium, fontSize: 24 },
  age: { color: colors.text, fontFamily: fonts.title, fontSize: 24, minWidth: 110, textAlign: "center", fontVariant: ["tabular-nums"] },
  point: { paddingVertical: space[3], paddingLeft: space[3], borderLeftWidth: 2, borderLeftColor: "transparent", marginBottom: space[1] },
  pointOn: { borderLeftColor: colors.accent },
  pointTitle: { color: colors.text, fontFamily: fonts.medium, fontSize: 17, lineHeight: 23 },
  pointText: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 14, lineHeight: 21, marginTop: 2 },
  error: { color: colors.danger, fontFamily: fonts.body, fontSize: 14, marginTop: space[4] },
  begin: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", gap: space[4], marginTop: space[8], paddingVertical: space[4], borderTopColor: colors.rule, borderTopWidth: 1, borderBottomColor: colors.rule, borderBottomWidth: 1 },
  pressed: { backgroundColor: colors.surface },
  beginText: { color: colors.accent, fontFamily: fonts.title, fontSize: 22 },
  beginMeta: { flexShrink: 1, textAlign: "right", color: colors.textMuted, fontFamily: fonts.body, fontSize: 13 },
  off: { color: colors.textMuted },
})
