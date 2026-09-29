import { useMemo, useState } from "react"
import { StyleSheet, Text, View } from "react-native"
import { queryLife, queryWorld } from "@paralelo/simulation"
import { ActionRow, Kicker, Page } from "../components/editorial"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

// MUNDO: manchetes derivadas de fatos, empresas e moradores (bíblia §20, §63, §75).
export default function WorldScreen() {
  const { world } = useGame()
  const city = useMemo(() => world ? queryWorld(world) : null, [world])
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const [visible, setVisible] = useState(12)
  if (!city || !life) return null
  const hiring = city.companies.filter(c => c.vacancies > 0)
  return <Page time={life.time}>
    <Text style={styles.label}>{city.district.toLocaleUpperCase("pt-BR")} · {life.dayTitle.toLocaleUpperCase("pt-BR")}</Text>
    <Text accessibilityRole="header" style={styles.title}>{city.city}</Text>
    <Text style={styles.lede}>{city.population} moradores, {city.companies.length} empresas, {hiring.length} contratando.</Text>

    <Kicker>O que aconteceu</Kicker>
    {!city.facts.length && <Text style={styles.quiet}>Nada importante mudou desde que você chegou.</Text>}
    {city.facts.map((fact, i) => <View key={fact.id} style={[styles.story, i === 0 && styles.lead]}>
      <Text style={styles.storyDate}>{fact.date}</Text>
      <Text style={[styles.storyText, i === 0 && styles.leadText]}>{fact.text}</Text>
    </View>)}

    <Kicker meta={`${hiring.length} com vagas`}>Empresas</Kicker>
    {city.companies.map(c => <View key={c.id} style={styles.row}>
      <Text style={styles.rowTitle}>{c.name}</Text>
      <Text style={styles.rowMeta}>{c.district}</Text>
      <Text style={[styles.rowValue, !c.vacancies && styles.muted]}>{c.vacancies ? `${c.vacancies} ${c.vacancies === 1 ? "vaga" : "vagas"}` : "sem vagas"}</Text>
    </View>)}

    <Kicker meta={`${city.residents.length}`}>Moradores</Kicker>
    {city.residents.slice(0, visible).map(p => <View key={p.id} style={styles.row}>
      <Text style={styles.rowTitle}>{p.name}</Text>
      <Text style={styles.rowMeta}>{p.district}</Text>
      <Text style={styles.rowValue}>{p.age}</Text>
    </View>)}
    {visible < city.residents.length && <ActionRow label="Ver mais moradores" meta={`${city.residents.length - visible} restantes`} onPress={() => setVisible(v => v + 12)} />}
  </Page>
}

const styles = StyleSheet.create({
  label: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6, marginTop: space[6] },
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 34, lineHeight: 40, marginTop: space[1] },
  lede: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 15, lineHeight: 22, marginTop: space[2] },
  quiet: { color: colors.textSecondary, fontFamily: fonts.narrative, fontSize: 17, lineHeight: 25, marginTop: space[2] },
  story: { paddingVertical: space[3], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  lead: { paddingTop: space[2] },
  storyDate: { color: colors.textMuted, fontFamily: fonts.medium, fontSize: 12, fontVariant: ["tabular-nums"] },
  storyText: { color: colors.text, fontFamily: fonts.body, fontSize: 15, lineHeight: 22, marginTop: space[1] },
  leadText: { fontFamily: fonts.title, fontSize: 22, lineHeight: 28 },
  row: { flexDirection: "row", alignItems: "baseline", gap: space[3], paddingVertical: space[2], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  rowTitle: { flex: 1, minWidth: 0, color: colors.text, fontFamily: fonts.medium, fontSize: 15 },
  rowMeta: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13 },
  rowValue: { width: 64, textAlign: "right", color: colors.text, fontFamily: fonts.medium, fontSize: 13, fontVariant: ["tabular-nums"] },
  muted: { color: colors.textMuted },
})
