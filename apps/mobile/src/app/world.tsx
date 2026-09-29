import { Pressable, Text, View } from "react-native"
import { useState } from "react"
import { queryWorld } from "@paralelo/simulation"
import { ScreenFrame, Section, pageStyles as s } from "../components/screen-frame"
import { useGame } from "../hooks/game-context"

export default function WorldScreen() {
  const { world } = useGame()
  const [visible, setVisible] = useState(20)
  if (!world) return null
  const city = queryWorld(world)
  return <ScreenFrame title={city.city} subtitle="MUNDO">
    <Text style={s.body}>Sua casa fica em {city.district}. Esta campanha acompanha {city.population} moradores e {city.companies.length} empresas.</Text>
    <Section title="O que mudou por aqui">
      {!city.facts.length && <Text style={s.body}>A semana está começando. Trabalho, estudos e pagamentos vão deixar marcas neste registro.</Text>}
      {city.facts.map(fact => <View style={s.row} key={fact.id}><Text style={s.secondary}>{fact.date}</Text><Text style={s.body}>{fact.text}</Text></View>)}
    </Section>
    <Section title="Empresas do bairro">
      {city.companies.map(company => <View style={s.row} key={company.id}><Text style={s.heading}>{company.name}</Text><Text style={s.secondary}>{company.district} · {company.vacancies} {company.vacancies === 1 ? "vaga aberta" : "vagas abertas"}</Text></View>)}
    </Section>
    <Section title="Moradores da cidade">
      {city.residents.slice(0, visible).map(person => <View style={s.row} key={person.id}><Text style={s.body}>{person.name}</Text><Text style={s.secondary}>{person.age} anos · {person.district}</Text></View>)}
      {visible < city.residents.length && <Pressable accessibilityRole="button" style={s.button} onPress={() => setVisible(count => count + 20)}><Text style={s.buttonText}>Conhecer mais moradores</Text></Pressable>}
    </Section>
  </ScreenFrame>
}
