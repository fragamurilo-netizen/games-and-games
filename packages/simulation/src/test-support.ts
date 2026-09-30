// Ajudantes de teste: jogam como uma pessoa comum, sem atalhos no domínio.
import { workSituations } from "@paralelo/content"
import type { Command, WorldState } from "./domain/world"
import { executeCommand } from "./commands"
import { queryCareer } from "./queries"
import { queryDecision } from "./systems/events"
import { interviewChoices, reviewChoices } from "./systems/work"

export function apply(world: WorldState, command: Command): WorldState {
  const result = executeCommand(world, command)
  if (!result.ok) throw new Error(result.error.message)
  return result.value
}

/** Escolha prudente: sem tempo extra, sem gasto, sem risco quando possível. */
export function safeChoice(world: WorldState): string {
  const scene = world.work.scene!
  if (scene.kind === "shift") {
    const choices = workSituations.find(s => s.id === scene.situationId)!.choices
    const plain = choices.filter(c => !c.minutes && !c.success.effect.moneyCents)
    return (plain.find(c => c.difficulty === undefined) ?? plain[0] ?? choices[0]!).id
  }
  if (scene.kind === "review") return reviewChoices(world).find(c => c.id === "listen")!.id
  const interview = world.work.interviews.find(i => i.id === scene.interviewId)!
  return interviewChoices(world, interview)[0]!.id
}

/** Resolve decisões e cenas pendentes até não sobrar nada esperando resposta. */
export function settle(world: WorldState, pick: (world: WorldState) => string = safeChoice): WorldState {
  for (let guard = 0; guard < 20; guard++) {
    const decision = queryDecision(world)
    if (decision) { world = apply(world, { type: "decide", decisionId: decision.id, choiceId: decision.choices.filter(c => c.canChoose).at(-1)!.id }); continue }
    if (world.work.scene) { world = apply(world, { type: "work-choice", sceneId: world.work.scene.id, choiceId: pick(world) }); continue }
    return world
  }
  throw new Error("Cenas em sequência demais.")
}

/** Um turno inteiro, com o momento do meio resolvido. */
export function workShift(world: WorldState, pick?: (world: WorldState) => string): WorldState {
  return settle(apply(world, { type: "work" }), pick)
}

/** Manda currículos e vai às entrevistas até ser contratado. */
export function hireViaInterviews(start: WorldState, maxDays = 60): WorldState {
  let world = start
  const end = world.clock.day + maxDays
  while (!world.employment && world.clock.day < end) {
    const waiting = world.work.interviews.some(i => i.status === "scheduled" || i.status === "awaiting")
    const vacancy = waiting ? undefined : queryCareer(world).vacancies.find(v => v.canApply)
    if (vacancy) world = apply(world, { type: "apply-job", vacancyId: vacancy.id })
    else world = settle(apply(world, { type: "wait", minutes: 720 }))
  }
  if (!world.employment) throw new Error("Seed de teste não conseguiu emprego pelas entrevistas.")
  return world
}
