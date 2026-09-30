// Mensagens de quem você conhece (bíblia §12.2, §33): chegam com prazo, pedem resposta e o
// silêncio também conta. A mensagem é o texto da pessoa; as respostas são verbos com custo.
import { Pressable, StyleSheet, Text, View } from "react-native"
import type { queryInbox } from "@paralelo/simulation"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"
import { Kicker } from "./editorial"
import { Portrait } from "./portrait"

type Inbox = ReturnType<typeof queryInbox>

export function Messages({ inbox }: { inbox: Inbox }) {
  const { busy, dispatch, world } = useGame()
  if (!inbox.length) return null
  const locked = busy || !!world?.events.pending
  return <>
    <Kicker meta={inbox.length === 1 ? "1 sem resposta" : `${inbox.length} sem resposta`}>Mensagens</Kicker>
    {inbox.map(m => {
      const first = m.from.name.split(" ")[0]
      const blocked = m.replies.find(r => !r.canReply && r.reply !== "later")
      return <View key={m.id} style={styles.message}>
        <View style={styles.head}>
          <Portrait seed={m.from.appearance.seed} sex={m.from.appearance.sex} age={m.from.age} size={44} accessibilityLabel={`Retrato de ${m.from.name}`} />
          <View style={styles.headText}>
            <Text style={styles.name}>{m.from.name}</Text>
            <Text style={styles.when}>{m.day === "Hoje" ? m.time : `${m.day}, ${m.time}`}</Text>
          </View>
        </View>
        <Text accessibilityLabel={`${first} escreveu: ${m.text}`} style={styles.text}>“{m.text}”</Text>
        <Text style={[styles.deadline, m.urgent && styles.urgent]}>{m.deadline}</Text>
        <View style={styles.replies}>
          {m.replies.map(r => {
            const off = locked || !r.canReply
            return <Pressable key={r.reply} accessibilityRole="button" accessibilityLabel={`${r.label}, ${r.meta}`} accessibilityState={{ disabled: off }} disabled={off}
              onPress={() => { void dispatch({ type: "reply", messageId: m.id, reply: r.reply }) }}
              style={({ pressed }) => [styles.reply, pressed && styles.pressed]}>
              <Text style={[styles.replyLabel, r.reply === "answer" && styles.primary, off && styles.off]}>{r.label}</Text>
              <Text style={[styles.replyMeta, off && styles.off]}>{r.meta}</Text>
            </Pressable>
          })}
        </View>
        {blocked?.reason && <Text style={styles.reason}>{blocked.reason}</Text>}
      </View>
    })}
  </>
}

const styles = StyleSheet.create({
  message: { paddingVertical: space[3], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  head: { flexDirection: "row", alignItems: "center", gap: space[3] },
  headText: { flex: 1, minWidth: 0 },
  name: { color: colors.text, fontFamily: fonts.medium, fontSize: 15, lineHeight: 21 },
  when: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 12, fontVariant: ["tabular-nums"] },
  text: { color: colors.text, fontFamily: fonts.narrative, fontSize: 18, lineHeight: 27, marginTop: space[3] },
  deadline: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[1] },
  urgent: { color: colors.warning },
  replies: { flexDirection: "row", flexWrap: "wrap", columnGap: space[6], marginTop: space[2] },
  reply: { minHeight: 44, justifyContent: "center", paddingVertical: space[1] },
  pressed: { opacity: 0.6 },
  replyLabel: { color: colors.text, fontFamily: fonts.medium, fontSize: 15, lineHeight: 21 },
  primary: { color: colors.accent },
  replyMeta: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 12, fontVariant: ["tabular-nums"] },
  off: { color: colors.textMuted },
  reason: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[1] },
})
