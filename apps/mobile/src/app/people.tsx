import { Text, View } from "react-native"
import { queryLife } from "@paralelo/simulation"
import { ScreenFrame, Section, ActionButton, pageStyles as s } from "../components/screen-frame"
import { useGame } from "../hooks/game-context"

export default function PeopleScreen() {
  const { world } = useGame()
  if (!world) return null
  const people = queryLife(world).people
  return <ScreenFrame title="Quem está por perto" subtitle="PESSOAS">
    <Text style={s.body}>Sua vida na cidade também depende das pessoas que lembram de você.</Text>
    {people.map(person => <Section key={person.id} title={person.name}>
      <Text style={s.secondary}>{person.description} · {person.age} anos</Text><Text style={s.body}>{person.state}</Text>
      <ActionButton label={`Ligar para ${person.name.split(" ")[0]}`} command={{ type: "contact", personId: person.id }} disabled={!person.canContact} />
      {person.unavailableReason && <Text style={s.secondary}>{person.unavailableReason}</Text>}
      {person.memories.map(memory => <View style={s.row} key={memory.id}><Text style={s.secondary}>{memory.date}</Text><Text style={s.body}>{memory.text}</Text></View>)}
    </Section>)}
  </ScreenFrame>
}
