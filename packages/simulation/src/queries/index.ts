import { contactAvailability } from "../commands"
import type { WorldState } from "../domain/world"
import { ageAt, formatDate, formatTime } from "../time"

// Read model novo a cada consulta; nada retornado compartilha objetos mutáveis do mundo.
export function queryLife(world: WorldState) {
  const player = world.people[world.playerId]!
  return {
    name: player.name, age: ageAt(player.birthDate, world.clock), city: world.city,
    date: formatDate(world.clock), time: formatTime(world.clock),
    energy: player.needs.energy < 20 ? "Você precisa descansar." : player.needs.energy < 50 ? "O cansaço começa a pesar." : "Você ainda tem disposição.",
    stress: player.needs.stress > 65 ? "Está difícil desligar a cabeça." : "A mudança ainda ocupa seus pensamentos.",
    timeline: world.timeline.slice(-80).reverse().map(entry => ({ id: entry.id, date: formatDate(entry.at), time: formatTime(entry.at), text: entry.text, kind: entry.kind })),
    people: Object.values(world.relationships).filter(r => r.a === player.id || r.b === player.id).map(r => {
      const person = world.people[r.a === player.id ? r.b : r.a]!
      const unavailable = contactAvailability(world, person.id)
      return { id: person.id, name: person.name, age: ageAt(person.birthDate, world.clock),
        description: r.tags.includes("family") ? "Sua mãe" : "Amizade de antes da mudança",
        state: r.lastInteractionAt ? "Vocês conversaram recentemente." : r.trust > 65 ? "Existe confiança entre vocês." : "Vocês ainda têm muito para conversar.",
        canContact: !unavailable, unavailableReason: unavailable?.message ?? null }
    }),
    agenda: [...world.scheduled].map(item => ({ id: item.id, date: formatDate(item.at), time: formatTime(item.at), label: "Mensagem da família" })),
  }
}
