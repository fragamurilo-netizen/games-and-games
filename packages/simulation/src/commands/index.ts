import { err, ok, type PersonId, type Result } from "@paralelo/shared"
import type { Command, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, addMinutes } from "../time"
import { advance, appendEntry } from "../scheduling"
import { courses } from "@paralelo/content"
import { applicationReason, applyForJob, completeShift, workReason } from "../systems/career"
import { postLedger } from "../systems/finance"
import { remember } from "../systems/memory"
import { updateRelationship } from "../systems/relationships"

export type CommandError = Readonly<{ code: "invalid-duration" | "unknown-person" | "no-relationship" | "cooldown" | "exhausted" | "invalid-command" | "unavailable" | "insufficient-money"; message: string }>
export function contactAvailability(world: WorldState, personId: PersonId): CommandError | null {
  const person = world.people[personId]
  if (!person || personId === world.playerId) return { code: "unknown-person", message: "Essa pessoa não está disponível." }
  const rel = Object.values(world.relationships).find(r => (r.a === world.playerId && r.b === personId) || (r.b === world.playerId && r.a === personId))
  if (!rel) return { code: "no-relationship", message: "Vocês ainda não se conhecem." }
  if (rel.lastInteractionAt && absoluteMinute(world.clock) - absoluteMinute(rel.lastInteractionAt) < 480)
    return { code: "cooldown", message: "Já houve contato há pouco. Dê um tempo antes de ligar de novo." }
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
    case "sleep": {
      next = advance(world, addMinutes(world.clock, 480), { resting: true })
      next = appendEntry(next, { at: next.clock, kind: "action", text: "Você dormiu oito horas. Ao acordar, a casa parecia menos urgente.", personIds: [world.playerId], cause: "command.sleep" })
      break
    }
    case "meal": {
      if (world.finance.balanceCents < 1800) return err({ code: "insufficient-money", message: "Faltam R$ 18,00 disponíveis para essa refeição." })
      next = advance(world, addMinutes(world.clock, 45))
      next = postLedger(next, { amountCents: -1800, category: "food", text: "Refeição no restaurante do bairro", cause: "command.meal" })
      const player = next.people[next.playerId]!
      next = { ...next, people: { ...next.people, [player.id]: { ...player, needs: { energy: Math.min(100, player.needs.energy + 10), stress: Math.max(0, player.needs.stress - 4) } } } }
      next = appendEntry(next, { at: next.clock, kind: "action", text: "Você almoçou no restaurante da esquina. O prato do dia custou R$ 18,00.", personIds: [world.playerId], cause: "command.meal" })
      break
    }
    case "apply-job": {
      const reason = applicationReason(world, command.vacancyId)
      if (reason) return err({ code: "unavailable", message: reason })
      next = applyForJob(advance(world, addMinutes(world.clock, 30)), command.vacancyId)
      break
    }
    case "work": {
      const reason = workReason(world)
      if (reason) return err({ code: "unavailable", message: reason })
      // Turno iniciado em uma data; o scheduler conserva todos os fatos no intervalo.
      next = completeShift(advance(world, addMinutes(world.clock, 480)), world.clock.day)
      break
    }
    case "study": {
      const course = courses.find(item => `course:${item.id}` === command.courseId)
      const training = world.training[command.courseId]
      if (!course || !training || training.sessions >= course.sessions) return err({ code: "unavailable", message: "Este curso não está disponível ou já foi concluído." })
      if (training.lastStudiedDay === world.clock.day) return err({ code: "cooldown", message: "Você já fez a aula de hoje. Pratique de novo amanhã." })
      if (world.finance.balanceCents < course.priceCents) return err({ code: "insufficient-money", message: "Não há saldo suficiente para esta aula." })
      if (world.people[world.playerId]!.needs.energy < 15) return err({ code: "exhausted", message: "Descanse antes de estudar." })
      next = advance(world, addMinutes(world.clock, 120))
      next = postLedger(next, { amountCents: -course.priceCents, category: "education", text: `Aula · ${course.title}`, cause: `education:${command.courseId}` })
      const skills = next.skills[next.playerId]!, sessions = training.sessions + 1
      next = { ...next, skills: { ...next.skills, [next.playerId]: { ...skills, [course.skill]: Math.min(1, skills[course.skill] + .045) } }, training: { ...next.training, [command.courseId]: { sessions, lastStudiedDay: world.clock.day } } }
      next = appendEntry(next, { at: next.clock, kind: "education", text: sessions === course.sessions ? `Você concluiu ${course.title.toLowerCase()} em ${course.institution}.` : `Você fez uma aula de ${course.title.toLowerCase()}. Restam ${course.sessions - sessions} encontros para concluir o curso.`, personIds: [world.playerId], cause: `education:${command.courseId}` })
      break
    }
    case "contact": {
      const unavailable = contactAvailability(world, command.personId)
      if (unavailable) return err(unavailable)
      const rel = Object.values(world.relationships).find(r => (r.a === world.playerId && r.b === command.personId) || (r.b === world.playerId && r.a === command.personId))!
      const roll = draw(world.seed, world.rng, "relationship")
      const answered = roll.value < .55 + rel.trust / 250
      next = advance({ ...world, rng: roll.state }, addMinutes(world.clock, answered ? 30 : 5))
      next = updateRelationship(next, rel.id, { familiarity: answered ? 1 : 0, affection: answered ? 2 : 0, trust: answered ? 1 : 0 }, next.clock)
      const person = next.people[command.personId]!
      const text = answered ? rel.tags.includes("family")
        ? `${person.name} atendeu. Você contou da mudança; ela pediu para você comer alguma coisa antes de desfazer o resto das caixas.`
        : `${person.name} atendeu. Vocês falaram da mudança e combinaram de se ver quando a semana acalmar.`
        : `${person.name} não atendeu. Você deixou uma mensagem dizendo que já chegou bem.`
      next = appendEntry(next, { at: next.clock, kind: "relationship", text, personIds: [world.playerId, person.id], cause: `command.contact:${rel.id}` })
      next = remember(next, person.id, world.playerId, answered ? "Você ligou e contou como estava a mudança." : "Você deixou uma mensagem dizendo que chegou bem.", `command.contact:${rel.id}`)
      break
    }
    default: return err({ code: "invalid-command", message: "Comando desconhecido." })
  }
  return ok({ ...next, revision: world.revision + 1,
    recentCommands: [...next.recentCommands, { revision: world.revision + 1, at: world.clock, command }].slice(-256) })
}
