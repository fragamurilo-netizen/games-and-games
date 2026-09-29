import { Text, View } from "react-native"
import { queryMoney } from "@paralelo/simulation"
import { ScreenFrame, Section, pageStyles as s } from "../components/screen-frame"
import { useGame } from "../hooks/game-context"

export default function MoneyScreen() {
  const { world } = useGame()
  if (!world) return null
  const money = queryMoney(world)
  return <ScreenFrame title="O que entra e o que fica" subtitle="DINHEIRO">
    <Text style={s.secondary}>Saldo disponível</Text><Text style={[s.accent, money.negative && s.error]}>{money.balance}</Text>
    <Text style={s.body}>{money.warning}</Text>
    <Section title="Próximo mês"><Text style={s.body}>Aluguel: {money.rent}</Text><Text style={s.body}>Turnos já trabalhados: {money.accrued}</Text><Text style={s.secondary}>Pagamento e aluguel são processados no dia 1, às 8h. O salário inclui apenas os turnos cumpridos.</Text></Section>
    <Section title="Extrato">
      {!money.ledger.length && <Text style={s.body}>Você chegou à cidade com R$ 800,00. Os próximos gastos e pagamentos aparecerão aqui.</Text>}
      {money.ledger.map(entry => <View style={s.row} key={entry.id}><Text style={s.secondary}>{entry.date} · {entry.time}</Text><Text style={s.body}>{entry.text}</Text><Text style={[s.heading, entry.incoming && { color: "#B8E986" }]}>{entry.amount}</Text></View>)}
    </Section>
  </ScreenFrame>
}
