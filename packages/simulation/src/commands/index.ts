import { err, ok, type PersonId, type Result } from "@paralelo/shared"
import type { Command, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, addMinutes } from "../time"
import { advance, appendEntry } from "../scheduling"

export type CommandError = Readonly<{ code: "invalid-duration" | "unknown-person" | "no-relationship" | "cooldown" | "exhausted" | "invalid-command"; message: string }>
export function contactAvailability(world: WorldState, personId: PersonId): CommandError | null {
  const person = world.people[personId]
  if (!person || personId === world.playerId) return { code: "unknown-person", message: "Essa pessoa não está disponível." }
  const rel = Object.values(world.relationships).find(r => (r.a === world.playerId && r.b === personId) || (r.b === world.playerId && r.a === personId))
  if (!rel) return { code: "no-relationship", message: "Vocês ainda não se conhecem." }
  if (rel.lastInteractionAt && absoluteMinute(world.clock) - absoluteMinute(rel.lastInteractionAt) < 480)
    return { code: "cooldown", message: "Vocês acabaram de conversar. Dê um tempo antes de ligar de novo." }
  if (world.people[world.playerId]!.needs.energy < 10) return { code: "exhausted", message: "Você está sem energia. Descanse um pouco." }
  return null
}
export function executeCommand(world: WorldState, command: Command): Result<WorldState, CommandError> {
  let next: WorldState
  switch (command.type) {
    case "wait": {
      if (!Number.isSafeInteger(command.minutes) || command.minutes < 1 || command.minutes > 10080)
        return err({ code: "invalid-duration", message: "Avance entre 1 minuto e 7 dias por vez." })
      next = advance(world, addMinutes(world.clock, command.minutes), { interruptible: true })
      break
    }
    case "rest": {
      next = advance(world, addMinutes(world.clock, 120), { resting: true })
      next = appendEntry(next, { at: next.clock, kind: "action", text: "Você desligou o celular e descansou por duas horas. As caixas podem esperar.", personIds: [world.playerId], cause: "command.rest" })
      break
    }
    case "contact": {
      const unavailable = contactAvailability(world, command.personId)
      if (unavailable) return err(unavailable)
      const rel = Object.values(world.relationships).find(r => (r.a === world.playerId && r.b === command.personId) || (r.b === world.playerId && r.a === command.personId))!
      const roll = draw(world.seed, world.rng, "relationship")
      const answered = roll.value < .55 + rel.trust / 250
      next = advance({ ...world, rng: roll.state }, addMinutes(world.clock, answered ? 30 : 5))
      next = { ...next, relationships: { ...next.relationships, [rel.id]: { ...rel,
        familiarity: Math.min(100, rel.familiarity + (answered ? 1 : 0)), affection: Math.min(100, rel.affection + (answered ? 2 : 0)),
        trust: Math.min(100, rel.trust + (answered ? 1 : 0)), lastInteractionAt: next.clock } } }
      const person = next.people[command.personId]!
      const text = answered ? rel.tags.includes("family")
        ? `${person.name} atendeu. Você contou da mudança; ela pediu para você comer alguma coisa antes de desfazer o resto das caixas.`
        : `${person.name} atendeu. Vocês falaram da mudança e combinaram de se ver quando a semana acalmar.`
        : `${person.name} não atendeu. Você deixou uma mensagem dizendo que já chegou bem.`
      next = appendEntry(next, { at: next.clock, kind: "relationship", text, personIds: [world.playerId, person.id], cause: `command.contact:${rel.id}` })
      break
    }
    default: return err({ code: "invalid-command", message: "Comando desconhecido." })
  }
  return ok({ ...next, revision: world.revision + 1,
    recentCommands: [...next.recentCommands, { revision: world.revision + 1, at: world.clock, command }].slice(-256) })
}
