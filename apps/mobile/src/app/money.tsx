import { useMemo } from "react"
import { StyleSheet, Text, View } from "react-native"
import { queryBody, queryLife, queryMoney } from "@paralelo/simulation"
import { ActionRow, FactRow, Kicker, Page, Prose } from "../components/editorial"
import { useGame } from "../hooks/game-context"
import { colors, fonts, space } from "../theme"

const short = (date: string): string => date.split(" de ").slice(0, 2).map((p, i) => i ? p.slice(0, 3) : p).join(" ")

// DINHEIRO: números exatos, datas e categorias em layout de extrato (bíblia §17, §62, §75).
export default function MoneyScreen() {
  const { world } = useGame()
  const money = useMemo(() => world ? queryMoney(world) : null, [world])
  const life = useMemo(() => world ? queryLife(world) : null, [world])
  const body = useMemo(() => world ? queryBody(world) : null, [world])
  if (!money || !life || !body) return null
  return <Page time={life.time}>
    <Text style={styles.label}>SALDO</Text>
    <Text accessibilityRole="header" style={[styles.balance, money.negative && styles.negative]}>{money.balance}</Text>
    <Prose tone={money.negative ? "danger" : "secondary"}>{money.warning}</Prose>

    <Kicker meta={money.monthName}>Este mês</Kicker>
    <FactRow label="Entradas" value={money.month.incoming} />
    <FactRow label="Saídas" value={money.month.outgoing} />
    <View style={styles.total}><FactRow label="Resultado" value={money.month.result} tone={money.month.positive ? undefined : "negative"} /></View>

    <Kicker meta="dia 1, 8h">Próximo acerto</Kicker>
    <FactRow label="Aluguel" value={`− ${money.rent}`} />
    <FactRow label="Turnos já trabalhados" value={money.accrued} />
    {body.gym.member && <FactRow label={body.gym.label} value={`− ${body.gym.price}`} />}
    <Text style={styles.note}>O salário paga só os turnos cumpridos.</Text>

    <Kicker meta={body.gym.member ? `desde ${body.gym.since}` : `${body.gym.price} por mês`}>Academia</Kicker>
    {body.gym.member
      ? <ActionRow label="Cancelar a matrícula" meta="sem multa" command={{ type: "gym", action: "cancel" }} />
      : <ActionRow label="Fazer matrícula" meta={`${body.gym.price} agora`} disabled={!!body.gym.reason} reason={body.gym.reason} command={{ type: "gym", action: "join" }} />}
    <Text style={styles.note}>{body.gym.member ? "A mensalidade é cobrada todo dia 1º, junto com o aluguel." : "A primeira mensalidade sai na hora; depois, todo dia 1º, junto com o aluguel."}</Text>

    <Kicker meta={money.ledger.length ? `${money.ledger.length} lançamentos` : undefined}>Extrato</Kicker>
    {!money.ledger.length && <Text style={styles.note}>Nenhum lançamento ainda. Você chegou à cidade com {"R$\u00A0800,00"}.</Text>}
    {money.ledger.map(entry => <View key={entry.id} style={styles.entry}>
      <Text style={styles.entryDate}>{short(entry.date)}</Text>
      <Text style={styles.entryText}>{entry.text}</Text>
      <Text style={[styles.entryAmount, entry.incoming && styles.incoming]}>{entry.amount}</Text>
    </View>)}
  </Page>
}

const styles = StyleSheet.create({
  label: { color: colors.textSecondary, fontFamily: fonts.label, fontSize: 11, letterSpacing: 1.6, marginTop: space[6] },
  balance: { color: colors.text, fontFamily: fonts.medium, fontSize: 40, lineHeight: 48, fontVariant: ["tabular-nums"], marginTop: space[1] },
  negative: { color: colors.danger },
  total: { borderTopColor: colors.rule, borderTopWidth: StyleSheet.hairlineWidth, marginTop: space[1] },
  note: { color: colors.textMuted, fontFamily: fonts.body, fontSize: 13, lineHeight: 19, marginTop: space[1] },
  entry: { flexDirection: "row", gap: space[3], alignItems: "baseline", paddingVertical: space[2], borderBottomColor: colors.rule, borderBottomWidth: StyleSheet.hairlineWidth },
  entryDate: { width: 48, color: colors.textMuted, fontFamily: fonts.medium, fontSize: 13, fontVariant: ["tabular-nums"] },
  entryText: { flex: 1, minWidth: 0, color: colors.text, fontFamily: fonts.body, fontSize: 14, lineHeight: 20 },
  entryAmount: { color: colors.text, fontFamily: fonts.medium, fontSize: 14, fontVariant: ["tabular-nums"] },
  incoming: { color: colors.accent },
})
