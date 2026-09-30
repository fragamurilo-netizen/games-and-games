import { useMemo, useState } from "react"
import { Pressable, StyleSheet, Text, View } from "react-native"
import { queryLife } from "@paralelo/simulation"
import { ActionRow, Kicker, Page, TimeRow, ui } from "../components/editorial"
import { Portrait } from "../components/portrait"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

const shortDate = (date: string): string => date.split(" de ").slice(0, 2).map((p, i) => i ? p.slice(0, 3) : p).join(" ")

// Círculos na ordem em que pesam na vida de quem acabou de se mudar (bíblia §11.4).
const GROUPS = [["family", "Família"], ["friend", "Amizades"], ["coworker", "Trabalho"], ["neighbor", "Vizinhança"]] as const

// PESSOAS: nomes, contexto, tempo e memória; nada de medidores de afeto (bíblia §8.1, §60, §75).
export default function PeopleScreen() {
  const { world } = useGame()
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const [open, setOpen] = useState<string | null>(null)
  if (!life) return null
  return <Page time={life.time}>
    <Text accessibilityRole="header" style={styles.title}>Pessoas</Text>
    <Text style={styles.lede}>{life.people.length} pessoas acompanham sua vida em {life.city}.</Text>
    {GROUPS.map(([group, title]) => {
      const members = life.people.filter(p => p.group === group).sort((a, b) => b.closeness - a.closeness)
      if (!members.length) return null
      return <View key={group}>
        <Kicker meta={`${members.length}`}>{title}</Kicker>
        {members.map(person => {
          const expanded = open === person.id
          const first = person.name.split(" ")[0]
          return <View key={person.id} style={styles.person}>
            <Pressable accessibilityRole="button" accessibilityState={{ expanded }} accessibilityLabel={`${person.name}, ${person.description}`}
              onPress={() => setOpen(expanded ? null : person.id)} style={({ pressed }) => [styles.row, pressed && ui.actionPressed]}>
              <Portrait seed={person.appearance.seed} sex={person.appearance.sex} look={person.appearance.look} age={person.age} size={expanded ? 112 : 56}
                accessibilityLabel={`Retrato de ${person.name}`} />
              <View style={styles.rowText}>
                <Text style={styles.name}>{person.name}</Text>
                <Text style={styles.relation}>{person.description} · {person.age} anos</Text>
                {person.work && <Text style={styles.relation}>{person.work}</Text>}
                <Text style={styles.state}>{person.state}</Text>
              </View>
            </Pressable>
            {expanded && <View style={styles.detail}>
              <Text style={styles.since}>{person.since} · {person.history.talks}</Text>
              {!!person.history.moments.length && <>
                <Text style={styles.label}>ENTRE VOCÊS</Text>
                {person.history.moments.map(m => <TimeRow key={m.id} time={shortDate(m.date)}>{m.text}</TimeRow>)}
              </>}
              {!!person.memories.length && <>
                <Text style={styles.label}>MOMENTOS QUE FICARAM</Text>
                {person.memories.map(memory => <TimeRow key={memory.id} time={shortDate(memory.date)}>{memory.text}</TimeRow>)}
              </>}
              <ActionRow label={`Ligar para ${first}`} meta="até 30 min" disabled={!person.canContact} reason={person.unavailableReason} command={{ type: "contact", personId: person.id }} />
            </View>}
          </View>
        })}
      </View>
    })}
  </Page>
}

const styles = StyleSheet.create({
  title: { color: colors.text, fontFamily: fonts.title, fontSize: 34, lineHeight: 40, marginTop: space[6] },
  lede: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 15, lineHeight: 22, marginTop: space[2] },
  person: { borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  row: { flexDirection: "row", gap: space[4], alignItems: "flex-end", paddingVertical: space[3] },
  rowText: { flex: 1, minWidth: 0, paddingBottom: space[1] },
  name: { color: colors.text, fontFamily: fonts.title, fontSize: 20, lineHeight: 25 },
  relation: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: 2 },
  state: { color: colors.text, fontFamily: fonts.narrative, fontSize: 16, lineHeight: 23, marginTop: space[2] },
  detail: { paddingBottom: space[3] },
  since: { color: colors.textSecondary, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginBottom: space[1] },
  label: { color: colors.textMuted, fontFamily: fonts.label, fontSize: 10, letterSpacing: 1.6, marginTop: space[2], marginBottom: space[1] },
})
