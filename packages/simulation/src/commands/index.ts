import { err, ok, type PersonId, type Result } from "@paralelo/shared"
import type { Command, WorldState } from "../domain/world"
import { draw } from "../rng"
import { absoluteMinute, addMinutes } from "../time"
import { advance, appendEntry } from "../scheduling"
import { courses, exercises, groomingRules, lifeEvents, routineRules, snack, workRules, workSituations } from "@paralelo/content"
import { choiceReason, resolveDecision } from "../systems/events"
import { applicationReason, applyForJob, workReason } from "../systems/career"
import { appointmentConflict, applyInternal, checkIn, finishShift, interviewChoices, internalApplicationReason, openShiftScene, prepare, prepareReason, resolveInterviewChoice, resolveReview, resolveShiftChoice, reviewChoices } from "../systems/work"
import { postLedger } from "../systems/finance"
import { remember } from "../systems/memory"
import { updateRelationship } from "../systems/relationships"
import { finishGroceries, finishMeal, groceriesReason, mealReason } from "../systems/routine"
import { replyReason, resolveReply } from "../systems/city"
import { buyClothes, buyClothesReason, dress, dressReason, eatSnack, exercise, exerciseReason, groom, groomReason, gym, gymReason, snackReason } from "../systems/body"

export type CommandError = Readonly<{ code: "invalid-duration" | "unknown-person" | "no-relationship" | "cooldown" | "exhausted" | "invalid-command" | "unavailable" | "insufficient-money" | "pending-decision"; message: string }>
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
  if (world.events.pending && command.type !== "decide") return err({ code: "pending-decision", message: "Uma decisão espera sua resposta na área VIDA." })
  if (!world.events.pending && world.work.scene && command.type !== "work-choice") return err({ code: "pending-decision", message: "Uma situação no trabalho espera sua resposta." })
  // compromissos marcados não são atravessados por ações longas (a espera para neles)
  const busyFor = (minutes: number): Result<never, CommandError> | null => {
    const conflict = appointmentConflict(world, minutes)
    return conflict ? err({ code: "unavailable", message: conflict }) : null
  }
  let next: WorldState
  switch (command.type) {
    case "decide": {
      const pending = world.events.pending
      if (!pending || pending.id !== command.decisionId) return err({ code: "unavailable", message: "Essa decisão já foi respondida ou não está mais disponível." })
      const option = lifeEvents.find(event => event.id === pending.definitionId)?.choices.find(option => option.id === command.choiceId)
      if (!option) return err({ code: "unavailable", message: "Esta escolha não existe." })
      const reason = choiceReason(world, option)
      if (reason) return err({ code: "insufficient-money", message: reason })
      next = resolveDecision(world, option)
      break
    }
    case "wait": {
      if (!Number.isSafeInteger(command.minutes) || command.minutes < 1 || command.minutes > 10080)
        return err({ code: "invalid-duration", message: "Avance entre 1 minuto e 7 dias por vez." })
      next = advance(world, addMinutes(world.clock, command.minutes), { interruptible: true })
      break
    }
    case "rest": {
      { const b = busyFor(120); if (b) return b }
      next = advance(world, addMinutes(world.clock, 120), { activity: "rest" })
      next = appendEntry(next, { at: next.clock, kind: "action", text: "Você deixou as tarefas de lado e descansou por duas horas.", personIds: [world.playerId], cause: "command.rest" })
      break
    }
    case "sleep": {
      { const b = busyFor(480); if (b) return b }
      next = advance(world, addMinutes(world.clock, 480), { activity: "sleep" })
      next = appendEntry(next, { at: next.clock, kind: "action", text: "Você dormiu oito horas e retomou o dia depois de acordar.", personIds: [world.playerId], cause: "command.sleep" })
      break
    }
    case "meal": {
      const source = command.source ?? "restaurant"
      const reason = mealReason(world, source)
      if (reason) return err({ code: source === "restaurant" && world.finance.balanceCents < 1800 ? "insufficient-money" : "unavailable", message: reason })
      { const b = busyFor(routineRules.meals[source].minutes); if (b) return b }
      next = finishMeal(advance(world, addMinutes(world.clock, routineRules.meals[source].minutes)), source, world.clock.day)
      break
    }
    case "buy-groceries": {
      const reason = groceriesReason(world)
      if (reason) return err({ code: world.finance.balanceCents < routineRules.groceries.priceCents ? "insufficient-money" : "unavailable", message: reason })
      { const b = busyFor(routineRules.groceries.minutes); if (b) return b }
      next = finishGroceries(advance(world, addMinutes(world.clock, routineRules.groceries.minutes)))
      break
    }
    case "apply-job": {
      const reason = applicationReason(world, command.vacancyId)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(30); if (b) return b }
      next = applyForJob(advance(world, addMinutes(world.clock, 30)), command.vacancyId)
      break
    }
    case "work": {
      const reason = workReason(world)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(routineRules.work.shiftMinutes); if (b) return b }
      // Presença registrada na chegada: a cobrança das 14h01 pode ocorrer durante o turno.
      // No meio do turno acontece um momento em que você decide como agir (bíblia §7, §46).
      const shiftDay = world.clock.day
      next = advance(checkIn(world), addMinutes(world.clock, workRules.momentAfterMinutes))
      if (next.employment?.lastWorkedDay === shiftDay && !next.work.scene)
        next = openShiftScene(next, routineRules.work.shiftMinutes - workRules.momentAfterMinutes, shiftDay)
      break
    }
    case "work-choice": {
      const scene = world.work.scene
      if (!scene || scene.id !== command.sceneId) return err({ code: "unavailable", message: "Essa situação já passou." })
      if (scene.kind === "shift") {
        const choice = workSituations.find(s => s.id === scene.situationId)?.choices.find(c => c.id === command.choiceId)
        if (!choice) return err({ code: "unavailable", message: "Esta escolha não existe." })
        const cost = -(choice.success.effect.moneyCents ?? 0)
        if (cost > 0 && world.finance.balanceCents < cost) return err({ code: "insufficient-money", message: "Não há saldo para isso agora." })
        const resolved = resolveShiftChoice(world, choice)
        next = advance(resolved.world, addMinutes(world.clock, resolved.minutes))
        if (next.employment && scene.shiftDay !== null && next.employment.lastWorkedDay === scene.shiftDay) next = finishShift(next, scene.shiftDay)
      } else if (scene.kind === "review") {
        const choice = reviewChoices(world).find(c => c.id === command.choiceId)
        if (!choice) return err({ code: "unavailable", message: "Esta escolha não existe." })
        if (!choice.available) return err({ code: "unavailable", message: choice.reason ?? "Isso não cabe nesta conversa." })
        next = advance(resolveReview(world, choice.id), addMinutes(world.clock, 20))
      } else {
        const interview = world.work.interviews.find(i => i.id === scene.interviewId)
        const choice = interview ? interviewChoices(world, interview).find(c => c.id === command.choiceId) : undefined
        if (!choice) return err({ code: "unavailable", message: "Esta escolha não existe." })
        next = advance(resolveInterviewChoice(world, choice.id), addMinutes(world.clock, scene.remainingMinutes))
      }
      break
    }
    case "prepare": {
      const interviewId = command.target === "interview" ? command.interviewId : undefined
      const reason = prepareReason(world, command.target, interviewId)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(workRules.prepareMinutes); if (b) return b }
      next = prepare(advance(world, addMinutes(world.clock, workRules.prepareMinutes)), command.target, interviewId)
      break
    }
    case "apply-internal": {
      const reason = internalApplicationReason(world)
      if (reason) return err({ code: "unavailable", message: reason })
      next = applyInternal(advance(world, addMinutes(world.clock, 15)))
      break
    }
    case "study": {
      const course = courses.find(item => `course:${item.id}` === command.courseId)
      const training = world.training[command.courseId]
      if (!course || !training || training.sessions >= course.sessions) return err({ code: "unavailable", message: "Este curso não está disponível ou já foi concluído." })
      if (training.lastStudiedDay === world.clock.day) return err({ code: "cooldown", message: "Você já fez a aula de hoje. Pratique de novo amanhã." })
      if (world.finance.balanceCents < course.priceCents) return err({ code: "insufficient-money", message: "Não há saldo suficiente para esta aula." })
      if (world.people[world.playerId]!.needs.energy < 15) return err({ code: "exhausted", message: "Descanse antes de estudar." })
      { const b = busyFor(120); if (b) return b }
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
      { const b = busyFor(30); if (b) return b }
      const rel = Object.values(world.relationships).find(r => (r.a === world.playerId && r.b === command.personId) || (r.b === world.playerId && r.a === command.personId))!
      const roll = draw(world.seed, world.rng, "relationship")
      const answered = roll.value < .55 + rel.trust / 250
      next = advance({ ...world, rng: roll.state }, addMinutes(world.clock, answered ? 30 : 5))
      next = updateRelationship(next, rel.id, { familiarity: answered ? 1 : 0, affection: answered ? 2 : 0, trust: answered ? 1 : 0 }, next.clock)
      const person = next.people[command.personId]!
      const text = world.clock.day >= 14 ? answered ? rel.tags.includes("family")
        ? `${person.name} atendeu. Vocês conversaram sobre a semana e sobre como você está cuidando da casa.`
        : world.employment ? `${person.name} atendeu. Você comentou como estão os turnos em ${world.companies[world.employment.companyId]!.name}.`
        : `${person.name} atendeu. Vocês falaram da semana e de como a rotina tem andado.`
        : `${person.name} não atendeu. Você deixou uma mensagem perguntando como está a semana.`
        : answered ? rel.tags.includes("family")
        ? `${person.name} atendeu. Você contou da mudança; ela pediu para você comer alguma coisa antes de desfazer o resto das caixas.`
        : `${person.name} atendeu. Vocês falaram da mudança e combinaram de se ver quando a semana acalmar.`
        : `${person.name} não atendeu. Você deixou uma mensagem dizendo que já chegou bem.`
      next = appendEntry(next, { at: next.clock, kind: "relationship", text, personIds: [world.playerId, person.id], cause: `command.contact:${rel.id}` })
      next = remember(next, person.id, world.playerId, text, `command.contact:${rel.id}`)
      break
    }
    case "reply": {
      const reason = replyReason(world, command.messageId, command.reply)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(command.reply === "call" ? 30 : 15); if (b) return b }
      const from = world.inbox.find(m => m.id === command.messageId)!.fromId
      if (command.reply === "call") {
        const unavailable = contactAvailability(world, from)
        if (unavailable) return err(unavailable)
      }
      const replied = resolveReply(world, command.messageId, command.reply)
      next = advance(replied.world, addMinutes(world.clock, replied.minutes))
      break
    }
    case "exercise": {
      const e = exercises[command.kind]
      if (!e) return err({ code: "invalid-command", message: "Exercício desconhecido." })
      const reason = exerciseReason(world, command.kind)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(e.minutes); if (b) return b }
      next = exercise(advance(world, addMinutes(world.clock, e.minutes)), command.kind)
      break
    }
    case "groom": {
      const reason = groomReason(world, command.kind)
      if (reason) return err({ code: "unavailable", message: reason })
      const minutes = groomingRules[command.kind].minutes
      { const b = busyFor(minutes); if (b) return b }
      next = groom(advance(world, addMinutes(world.clock, minutes)), command.kind)
      break
    }
    case "dress": {
      const reason = dressReason(world, command.outfit)
      if (reason) return err({ code: "unavailable", message: reason })
      next = dress(world, command.outfit)
      break
    }
    case "buy-clothes": {
      const reason = buyClothesReason(world, command.outfit)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(60); if (b) return b }
      next = buyClothes(advance(world, addMinutes(world.clock, 60)), command.outfit)
      break
    }
    case "gym": {
      const reason = gymReason(world, command.action)
      if (reason) return err({ code: "unavailable", message: reason })
      next = gym(world, command.action)
      break
    }
    case "snack": {
      const reason = snackReason(world)
      if (reason) return err({ code: "unavailable", message: reason })
      { const b = busyFor(snack.minutes); if (b) return b }
      next = eatSnack(advance(world, addMinutes(world.clock, snack.minutes)))
      break
    }
    default: return err({ code: "invalid-command", message: "Comando desconhecido." })
  }
  return ok({ ...next, revision: world.revision + 1,
    recentCommands: [...next.recentCommands, { revision: world.revision + 1, at: world.clock, command }].slice(-256) })
}
