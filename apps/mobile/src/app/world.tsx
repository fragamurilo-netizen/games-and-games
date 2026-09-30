import { useMemo, useState } from "react"
import { StyleSheet, Text, View } from "react-native"
import { queryLife, queryWorld } from "@paralelo/simulation"
import { ActionRow, Kicker, Page } from "../components/editorial"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

// MUNDO: jornal da cidade feito de fatos simulados; o que toca a sua vida vem marcado
// (bíblia §20, §63, §75). Empresas aparecem pelo clima, não por números.
export default function WorldScreen() {
  const { world } = useGame()
  const city = useMemo(() => world ? queryWorld(world) : null, [world])
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const [visible, setVisible] = useState(12)
  const [stories, setStories] = useState(8)
  if (!city || !life) return null
  const hiring = city.companies.filter(c => c.vacancies > 0)
  const [lead, ...rest] = city.news
  return <Page time={life.time}>
    <Text style={styles.label}>{city.district.toLocaleUpperCase("pt-BR")} · {life.dayTitle.toLocaleUpperCase("pt-BR")}</Text>
    <Text accessibilityRole="header" style={styles.title}>{city.city}</Text>
    <Text style={styles.lede}>{city.population} moradores, {city.companies.length} empresas, {hiring.length} contratando.</Text>

    <Kicker>Jornal da cidade</Kicker>
    {!lead && <Text style={styles.quiet}>Semana sem manchete. A cidade segue no ritmo de sempre.</Text>}
    {lead && <View style={[styles.story, styles.lead]}>
      <Text style={styles.storyDate}>{lead.section.toLocaleUpperCase("pt-BR")} · {lead.day}</Text>
      <Text style={styles.leadText}>{lead.headline}</Text>
      <Text style={styles.leadBody}>{lead.body}</Text>
      {lead.relevance && <Text style={styles.relevance}>{lead.relevance}</Text>}
    </View>}
    {rest.slice(0, stories).map(item => <View key={item.id} style={styles.story}>
      <Text style={styles.storyDate}>{item.section.toLocaleUpperCase("pt-BR")} · {item.day}</Text>
      <Text style={styles.headline}>{item.headline}</Text>
      <Text style={styles.storyText}>{item.body}</Text>
      {item.relevance && <Text style={styles.relevance}>{item.relevance}</Text>}
    </View>)}
    {rest.length > stories && <ActionRow label="Edições anteriores" meta={`${rest.length - stories}`} onPress={() => setStories(s => s + 8)} />}

    {!!city.facts.length && <>
      <Kicker>Na sua vida</Kicker>
      {city.facts.map(fact => <View key={fact.id} style={styles.story}>
        <Text style={styles.storyDate}>{fact.date}</Text>
        <Text style={styles.storyText}>{fact.text}</Text>
      </View>)}
    </>}

    <Kicker meta={`${hiring.length} com vagas`}>Empresas</Kicker>
    {city.companies.map(c => <View key={c.id} style={styles.company}>
      <View style={styles.row}>
        <Text style={styles.rowTitle}>{c.name}{c.yours ? <Text style={styles.yours}>  ·  onde você trabalha</Text> : null}</Text>
        <Text style={[styles.rowValue, !c.vacancies && styles.muted]}>{c.vacancies ? `${c.vacancies} ${c.vacancies === 1 ? "vaga" : "vagas"}` : "sem vagas"}</Text>
      </View>
      <Text style={styles.rowMeta}>{c.district} · {c.staff} {c.staff === 1 ? "pessoa" : "pessoas"} · {c.mood}</Text>
    </View>)}

    <Kicker meta={`${city.residents.length}`}>Moradores</Kicker>
    {city.residents.slice(0, visible).map(p => <View key={p.id} style={[styles.row, styles.resident]}>
      <Text style={styles.rowTitle}>{p.name}</Text>
      <Text style={styles.rowMetaInline}>{p.district}</Text>
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
  lead: { paddingTop: space[2], paddingBottom: space[4] },
  storyDate: { color: colors.textMuted, fontFamily: fonts.label, fontSize: 10, letterSpacing: 1.4, fontVariant: ["tabular-nums"] },
  leadText: { color: colors.text, fontFamily: fonts.title, fontSize: 26, lineHeight: 32, marginTop: space[1] },
  leadBody: { color: colors.text, fontFamily: fonts.narrative, fontSize: 18, lineHeight: 27, marginTop: space[2] },
  headline: { color: colors.text, fontFamily: fonts.title, fontSize: 19, lineHeight: 24, marginTop: space[1] },
  storyText: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 15, lineHeight: 22, marginTop: space[1] },
  relevance: { color: colors.accent, fontFamily: fonts.medium, fontSize: 12, lineHeight: 18, marginTop: space[2] },
  company: { paddingVertical: space[2], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  row: { flexDirection: "row", alignItems: "baseline", gap: space[3], paddingVertical: space[1] },
  rowTitle: { flex: 1, minWidth: 0, color: colors.text, fontFamily: fonts.medium, fontSize: 15 },
  resident: { paddingVertical: space[2], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  yours: { color: colors.accent, fontFamily: fonts.body, fontSize: 13 },
  rowMeta: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19 },
  rowMetaInline: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13 },
  rowValue: { width: 72, textAlign: "right", color: colors.text, fontFamily: fonts.medium, fontSize: 13, fontVariant: ["tabular-nums"] },
  muted: { color: colors.textMuted },
})
