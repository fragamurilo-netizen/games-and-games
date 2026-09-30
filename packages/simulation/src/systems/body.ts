// Corpo e aparência (bíblia §21). O peso nasce do balanço entre o que se come e o que se gasta;
// força e fôlego vêm de prática e se perdem sem ela; barba cresce, cabelo pede corte; cada pessoa
// escolhe a roupa do dia pelo que tem, pelo clima e pelo compromisso. Nada disso vira barra:
// o jogador vê no desenho e lê em frases.
import {
  bodyRules, dressCode, exercises, groomingRules, outfitCatalog, roleCareer, snack, starterWardrobe,
  type ExerciseKind,
} from "@paralelo/content"
import type { PersonId, ScheduleId } from "@paralelo/shared"
import type { PersonBody, ScheduledEvent, Wardrobe, WorldState, WorldStateV7 } from "../domain/world"
import { hashText } from "../rng"
import { ageAt, calendarDate, formatDate } from "../time"
import { appendEntry } from "../timeline"
import { formatMoney, postLedger } from "./finance"
import { changeNeeds } from "./needs"

const clamp = (v: number, lo = 0, hi = 1): number => Math.max(lo, Math.min(hi, v))
const unit = (world: { seed: string }, key: string): number => hashText(`${world.seed}/body/${key}`) / 4294967296
const normal = (world: { seed: string }, key: string): number => {
  const u = Math.max(1e-9, unit(world, `${key}/a`)), v = unit(world, `${key}/b`)
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v)
}
const round1 = (v: number): number => Math.round(v * 10) / 10

export const weightOf = (b: PersonBody): number => b.fatKg + b.leanKg
export const fatShare = (b: PersonBody): number => b.fatKg / weightOf(b)
export const bmiOf = (b: PersonBody): number => weightOf(b) / (b.heightCm / 100) ** 2

/** Metabolismo basal (Mifflin-St Jeor). */
export function basalKcal(b: PersonBody, age: number, sex: "F" | "M"): number {
  return 10 * weightOf(b) + 6.25 * b.heightCm - 5 * Math.max(18, age) + (sex === "M" ? 5 : -161)
}

// ---------------- criação e migração ----------------

function newBody(world: WorldStateV7 | WorldState, id: PersonId): PersonBody {
  const person = world.people[id]!
  const age = ageAt(person.birthDate, world.clock)
  const male = person.sex === "M"
  const grown = Math.min(1, Math.max(.3, age / 18))
  const heightCm = round1(((male ? 175 : 162) + normal(world, `${id}/h`) * 7) * (age >= 18 ? 1 : .55 + grown * .45))
  // IMC distribuído como numa cidade comum: a maioria entre 20 e 30
  const bmi = age < 18 ? 17 + normal(world, `${id}/bmi`) : clamp(24.5 + normal(world, `${id}/bmi`) * 3.6 + Math.max(0, age - 30) * .06, 17, 40)
  const weight = bmi * (heightCm / 100) ** 2
  const fatPct = clamp((male ? .12 : .22) + (bmi - 21) * .012 + Math.max(0, age - 30) * .002 + normal(world, `${id}/fat`) * .025, male ? .07 : .15, .5)
  const leanKg = round1(weight * (1 - fatPct))
  const strength = clamp(.2 + unit(world, `${id}/str`) * .3)
  return { heightCm, fatKg: round1(weight * fatPct), leanKg, baseLeanKg: leanKg, strength, fitness: clamp(.2 + unit(world, `${id}/fit`) * .35),
    lastTrainingDay: null, lastShaveDay: world.clock.day, lastHaircutDay: world.clock.day - Math.floor(unit(world, `${id}/hair`) * 30),
    kcalIn: 0, kcalOut: 0, activity: unit(world, `${id}/act`), appetite: unit(world, `${id}/app`), weightLog: [{ day: world.clock.day, kg: round1(weight) }] }
}

function newWardrobe(world: WorldStateV7 | WorldState, id: PersonId): Wardrobe {
  const person = world.people[id]!
  const owned = [...starterWardrobe[person.sex]]
  if (id !== world.playerId) {
    // quem já mora na cidade tem mais roupa; quem trabalha em escritório, roupa social
    const pool = outfitCatalog.filter(o => o.sexes.includes(person.sex) && !owned.includes(o.id))
    const extra = 2 + Math.floor(unit(world, `${id}/wardrobe`) * 4)
    for (let i = 0; i < extra && pool.length; i++) owned.push(pool.splice(hashText(`${world.seed}/${id}/outfit/${i}`) % pool.length, 1)[0]!.id)
    const job = "residents" in world ? world.residents[id]?.job : null
    if (job && roleCareer[job.roleId]?.family === "escritorio" && !owned.some(o => outfitCatalog.find(x => x.id === o)!.formality === 2))
      owned.push(person.sex === "M" ? "formal" : "shirt")
  }
  return { owned, today: null }
}

/** v7 -> v8: corpo e guarda-roupa para cada pessoa, rotina diária do corpo. */
export function upgradeWorldV7(base: WorldStateV7): WorldState {
  const bodies: Record<string, PersonBody> = {}, wardrobes: Record<string, Wardrobe> = {}
  for (const id of Object.keys(base.people).sort() as PersonId[]) { bodies[id] = newBody(base, id); wardrobes[id] = newWardrobe(base, id) }
  const day = base.clock.minute < bodyRules.dailyMinute ? base.clock.day : base.clock.day + 1
  const event: ScheduledEvent = { id: "schedule:daily-body" as ScheduleId, kind: "daily-body", at: { day, minute: bodyRules.dailyMinute }, personId: base.playerId, interrupts: false }
  return { ...base, schemaVersion: 8, bodies, wardrobes, gym: null, scheduled: [...base.scheduled, event] }
}

/** Corpo e guarda-roupa refeitos para quem mudou de sexo ou idade antes do primeiro dia (começo da campanha). */
export function resetBody(world: WorldState, id: PersonId): WorldState {
  return { ...world, bodies: { ...world.bodies, [id]: newBody(world, id) }, wardrobes: { ...world.wardrobes, [id]: newWardrobe(world, id) } }
}

// ---------------- balanço diário ----------------

const withBody = (world: WorldState, id: string, patch: Partial<PersonBody>): WorldState =>
  ({ ...world, bodies: { ...world.bodies, [id]: { ...world.bodies[id]!, ...patch } } })

/** Comer soma calorias ao dia do jogador. */
export const eat = (world: WorldState, kcal: number): WorldState => {
  const b = world.bodies[world.playerId]
  return b ? withBody(world, world.playerId, { kcalIn: b.kcalIn + Math.max(0, Math.round(kcal)) }) : world
}
export const burn = (world: WorldState, kcal: number): WorldState => {
  const b = world.bodies[world.playerId]
  return b ? withBody(world, world.playerId, { kcalOut: b.kcalOut + Math.max(0, Math.round(kcal)) }) : world
}

/** Uma vez por dia, de madrugada: o que entrou e o que saiu vira gordura ou massa magra. */
export function processDailyBody(world: WorldState, event: ScheduledEvent): WorldState {
  const day = world.clock.day
  const bodies: Record<string, PersonBody> = { ...world.bodies }
  const weekly = day % 7 === 0
  const ids = weekly ? Object.keys(world.bodies) : [world.playerId]
  for (const id of ids) {
    const b = world.bodies[id]
    if (!b) continue
    const person = world.people[id]
    if (!person) continue
    const player = id === world.playerId
    // nível de detalhe (bíblia §39, §44): o jogador todo dia; os outros em lote semanal
    const step = player ? 1 : 7
    const age = ageAt(person.birthDate, world.clock)
    if (age < 16) { bodies[id] = { ...b, kcalIn: 0, kcalOut: 0 }; continue }
    const basal = basalKcal(b, age, person.sex)
    const trained = b.lastTrainingDay !== null && day - b.lastTrainingDay <= 7
    let intake: number, spent: number
    if (player) {
      intake = b.kcalIn
      spent = basal * bodyRules.baseActivity + b.kcalOut
    } else {
      // hábitos: quem se mexe mais gasta mais; quem come mais, come mais. Desemprego pesa no apetite.
      const unemployed = world.residents[id]?.job === null && age >= 18 && age <= 64
      spent = basal * (bodyRules.baseActivity + b.activity * .25) * step
      intake = spent * (1 + (b.appetite - .5) * .05 + (unemployed ? .015 : 0) + (unit(world, `${id}/${day}`) - .5) * .05)
    }
    const deltaKg = (intake - spent) / bodyRules.kcalPerKg
    const leanPart = deltaKg < 0 ? (trained ? .1 : .25) : (trained ? .35 : .15)
    let fatKg = b.fatKg + deltaKg * (1 - leanPart), leanKg = b.leanKg + deltaKg * leanPart
    let strength = b.strength, fitness = b.fitness
    // sem treino, o ganho se desfaz aos poucos; com a idade, a massa magra cai devagar
    const idle = b.lastTrainingDay === null ? 999 : day - b.lastTrainingDay
    if (idle > bodyRules.detrainingDays) {
      strength = Math.max(clamp(.2 + b.activity * .15), strength - .002 * step)
      fitness = Math.max(clamp(.2 + b.activity * .2), fitness - .002 * step)
      if (leanKg > b.baseLeanKg) leanKg = Math.max(b.baseLeanKg, leanKg - .012 * step)
    }
    let baseLeanKg = b.baseLeanKg
    if (age > 35) baseLeanKg -= baseLeanKg * .0025 * step / 365
    if (!player && b.activity > .75) { strength = clamp(strength + .01); fitness = clamp(fitness + .01) }
    // piso fisiológico provisório: sem sistema de saúde (§21) ainda não há consequência para fome prolongada
    fatKg = Math.max(2, weightOf(b) * .03, fatKg)
    leanKg = Math.max(b.baseLeanKg * .6, leanKg)
    const kg = round1(fatKg + leanKg)
    const weightLog = weekly ? [...b.weightLog, { day, kg }].slice(-bodyRules.weightLogWeeks) : b.weightLog
    bodies[id] = { ...b, fatKg: +fatKg.toFixed(3), leanKg: +leanKg.toFixed(3), baseLeanKg: +baseLeanKg.toFixed(3), strength: +strength.toFixed(4), fitness: +fitness.toFixed(4), kcalIn: 0, kcalOut: 0, weightLog }
  }
  // o dia sem nenhuma refeição também conta: a fome vira fraqueza
  return { ...world, bodies, scheduled: [...world.scheduled, { ...event, at: { day: day + 1, minute: bodyRules.dailyMinute } }] }
}

// ---------------- exercício e cuidado ----------------

export function exerciseReason(world: WorldState, kind: ExerciseKind): string | null {
  const e = exercises[kind], b = world.bodies[world.playerId]!, needs = world.people[world.playerId]!.needs
  if (e.needsGym && !world.gym) return "Você não tem matrícula na academia."
  if (e.needsGym && (world.clock.minute < 360 || world.clock.minute > 1320)) return "A academia abre das 6h às 22h."
  if (needs.energy < 25) return "Sem energia para treinar agora."
  if (needs.hunger >= 80) return "Com essa fome, o treino não rende. Coma antes."
  if (e.strength && b.lastTrainingDay === world.clock.day && (kind === "home" || kind === "gym")) return "Você já treinou força hoje. O músculo cresce no descanso."
  return null
}

export function exercise(world: WorldState, kind: ExerciseKind): WorldState {
  const e = exercises[kind], b = world.bodies[world.playerId]!
  const unfit = e.minFitness !== undefined && b.fitness < e.minFitness
  // retorno decrescente: quem já treina ganha menos a cada sessão (bíblia §16.3: prática, não XP)
  const strength = clamp(b.strength + e.strength * (1 - b.strength) * (unfit ? .5 : 1))
  const fitness = clamp(b.fitness + e.fitness * (1 - b.fitness))
  const cap = b.baseLeanKg * 1.18
  const leanKg = e.leanKg ? Math.min(cap, b.leanKg + e.leanKg * (1 - (b.leanKg - b.baseLeanKg) / (cap - b.baseLeanKg + .001))) : b.leanKg
  const kcal = e.met * weightOf(b) * (e.minutes / 60)
  // caminhada conta como movimento, não como treino
  let next = withBody(world, world.playerId, { strength: +strength.toFixed(4), fitness: +fitness.toFixed(4), leanKg: +leanKg.toFixed(3), kcalOut: b.kcalOut + Math.round(kcal),
    lastTrainingDay: kind === "walk" ? b.lastTrainingDay : world.clock.day })
  next = changeNeeds(next, { energy: e.energy * (unfit ? 1.5 : 1), stress: e.stress, hunger: 12 })
  const text = kind === "walk" ? "Você caminhou pelo bairro sem pressa. Deu para ver o comércio abrindo e fechando."
    : kind === "run" ? (unfit ? "Você correu mais do que o fôlego aguentava. Parou três vezes, mas terminou." : "Você correu pelas ruas do bairro. O corpo reclamou no começo e agradeceu no fim.")
    : kind === "home" ? "Flexões, agachamentos e prancha no chão da sala. Pouco espaço, muito suor."
    : "Treino completo na academia. Alguém no aparelho ao lado ensinou um ajuste na postura."
  return appendEntry(next, { at: next.clock, kind: "action", text, personIds: [world.playerId], cause: `body.exercise:${kind}` })
}

export function groomReason(world: WorldState, kind: "shave" | "haircut"): string | null {
  const b = world.bodies[world.playerId]!, sex = world.people[world.playerId]!.sex
  if (kind === "shave" && world.clock.day - b.lastShaveDay < 1) return "A barba foi feita hoje."
  if (kind === "haircut") {
    if (world.clock.day - b.lastHaircutDay < 14) return "O corte ainda está recente."
    if (world.clock.minute < 540 || world.clock.minute > 1140) return "O salão atende das 9h às 19h."
    if (world.finance.balanceCents < groomingRules.haircut.priceCents[sex]) return "Não há saldo para o corte agora."
  }
  return null
}
export function groom(world: WorldState, kind: "shave" | "haircut"): WorldState {
  const sex = world.people[world.playerId]!.sex
  if (kind === "shave") {
    const next = withBody(world, world.playerId, { lastShaveDay: world.clock.day })
    return appendEntry(changeNeeds(next, { stress: -1 }), { at: next.clock, kind: "action", text: "Você fez a barba com calma na frente do espelho.", personIds: [world.playerId], cause: "body.shave" })
  }
  const price = groomingRules.haircut.priceCents[sex]
  let next = postLedger(withBody(world, world.playerId, { lastHaircutDay: world.clock.day }), { amountCents: -price, category: "event", text: "Corte de cabelo", cause: "body.haircut" })
  next = changeNeeds(next, { stress: -4 })
  return appendEntry(next, { at: next.clock, kind: "action", text: `Você cortou o cabelo no salão da esquina por ${formatMoney(price)}. A cabeça ficou mais leve.`, personIds: [world.playerId], cause: "body.haircut" })
}

export const snackReason = (world: WorldState): string | null =>
  world.finance.balanceCents < snack.priceCents ? "Não há saldo nem para um lanche." : world.people[world.playerId]!.needs.hunger < 15 ? "Você acabou de comer." : null
export function eatSnack(world: WorldState): WorldState {
  let next = eat(changeNeeds(world, { hunger: snack.hunger, energy: snack.energy, stress: snack.stress }), snack.kcal)
  next = postLedger(next, { amountCents: -snack.priceCents, category: "food", text: "Lanche na rua", cause: "command.snack" })
  return appendEntry(next, { at: next.clock, kind: "action", text: "Você comeu um salgado grande e um refrigerante no balcão da lanchonete. Rápido, barato e pesado.", personIds: [world.playerId], cause: "command.snack" })
}

// ---------------- academia ----------------

export function gymReason(world: WorldState, action: "join" | "cancel"): string | null {
  if (action === "join") return world.gym ? "Você já tem matrícula." : world.finance.balanceCents < bodyRules.gym.priceCents ? "Não há saldo para a primeira mensalidade." : null
  return world.gym ? null : "Você não tem matrícula."
}
export function gym(world: WorldState, action: "join" | "cancel"): WorldState {
  if (action === "cancel") return appendEntry({ ...world, gym: null }, { at: world.clock, kind: "finance", text: "Você cancelou a matrícula na academia. A mensalidade para de ser cobrada.", personIds: [world.playerId], cause: "body.gym-cancel" })
  const next = postLedger({ ...world, gym: { since: world.clock } }, { amountCents: -bodyRules.gym.priceCents, category: "event", text: `Mensalidade · ${bodyRules.gym.label}`, cause: "body.gym" })
  return appendEntry(next, { at: next.clock, kind: "finance", text: `Matrícula feita na ${bodyRules.gym.label.toLowerCase()}: ${formatMoney(bodyRules.gym.priceCents)} por mês, cobrados junto com o aluguel.`, personIds: [world.playerId], cause: "body.gym-join" })
}
/** Cobrança mensal junto com o aluguel. */
export function chargeGym(world: WorldState): WorldState {
  return world.gym ? postLedger(world, { amountCents: -bodyRules.gym.priceCents, category: "event", text: `Mensalidade · ${bodyRules.gym.label}`, cause: "body.gym" }) : world
}

// ---------------- roupa do dia ----------------

/** −1 calor, 0 meia-estação, 1 frio (hemisfério sul). */
export function seasonOf(day: number): -1 | 0 | 1 {
  const m = calendarDate(day).month
  return m === 12 || m <= 3 ? -1 : m >= 6 && m <= 8 ? 1 : 0
}
/** Formalidade que o dia pede para a pessoa. */
function occasionOf(world: WorldState, id: string, day: number): 0 | 1 | 2 {
  if (day % 7 >= 5) return 0
  if (id === world.playerId) {
    const e = world.employment
    return e ? dressCode[roleCareer[e.roleId]?.family ?? "operacao"] ?? 0 : 0
  }
  const job = world.residents[id]?.job
  return job ? dressCode[roleCareer[job.roleId]?.family ?? "operacao"] ?? 0 : 0
}
export function outfitOf(world: WorldState, id: string, day = world.clock.day): string {
  const w = world.wardrobes[id]
  if (!w) return "casual"
  if (w.today && w.today.day === day && w.owned.includes(w.today.outfit)) return w.today.outfit
  const target = occasionOf(world, id, day), season = seasonOf(day)
  let best = w.owned[0] ?? "casual", score = -Infinity
  for (const oid of w.owned) {
    const o = outfitCatalog.find(x => x.id === oid)
    if (!o) continue
    const s = -Math.abs(o.formality - target) * 2 - Math.abs(o.warmth - season) * 1.2 + unit(world, `${id}/${day}/${oid}`) * 1.1
    if (s > score) { score = s; best = oid }
  }
  return best
}

export function dressReason(world: WorldState, outfit: string): string | null {
  return world.wardrobes[world.playerId]?.owned.includes(outfit) ? null : "Essa roupa não está no seu guarda-roupa."
}
export function dress(world: WorldState, outfit: string): WorldState {
  const w = world.wardrobes[world.playerId]!
  return { ...world, wardrobes: { ...world.wardrobes, [world.playerId]: { ...w, today: { day: world.clock.day, outfit } } } }
}
export function buyClothesReason(world: WorldState, outfit: string): string | null {
  const o = outfitCatalog.find(x => x.id === outfit), sex = world.people[world.playerId]!.sex
  if (!o || !o.sexes.includes(sex)) return "Essa peça não está à venda aqui."
  if (world.wardrobes[world.playerId]!.owned.includes(outfit)) return "Você já tem essa roupa."
  if (world.clock.minute < 540 || world.clock.minute > 1200) return "As lojas abrem das 9h às 20h."
  if (world.finance.balanceCents < o.priceCents) return `Faltam ${formatMoney(o.priceCents - world.finance.balanceCents)} para essa compra.`
  return null
}
export function buyClothes(world: WorldState, outfit: string): WorldState {
  const o = outfitCatalog.find(x => x.id === outfit)!, w = world.wardrobes[world.playerId]!
  let next: WorldState = { ...world, wardrobes: { ...world.wardrobes, [world.playerId]: { owned: [...w.owned, outfit].slice(-20), today: { day: world.clock.day, outfit } } } }
  next = postLedger(next, { amountCents: -o.priceCents, category: "event", text: `Roupa · ${o.label}`, cause: `body.clothes:${outfit}` })
  return appendEntry(next, { at: next.clock, kind: "action", text: `Você comprou ${o.label.toLowerCase()} por ${formatMoney(o.priceCents)} e saiu da loja já vestindo.`, personIds: [world.playerId], cause: `body.clothes:${outfit}` })
}

/** Roupa abaixo do que o trabalho espera: quem responde pela equipe percebe. */
export function dressGap(world: WorldState): number {
  const e = world.employment
  if (!e) return 0
  const expected = dressCode[roleCareer[e.roleId]?.family ?? "operacao"] ?? 0
  const worn = outfitCatalog.find(o => o.id === outfitOf(world, world.playerId))?.formality ?? 0
  return Math.max(0, expected - worn)
}

// ---------------- aparência ----------------

/** Como a pessoa aparece hoje para o renderizador; números ficam só no desenho (bíblia §8.1). */
export type PersonLook = Readonly<{ fat?: number; muscle?: number; outfit?: string; stubbleDays?: number; shirtHue?: number; pantsTone?: number }>

/** O que o renderizador precisa para desenhar a pessoa hoje. */
export function lookOf(world: WorldState, id: string): PersonLook {
  const b = world.bodies[id], person = world.people[id]!
  const day = world.clock.day
  if (!b) return {}
  const male = person.sex === "M"
  const fat = clamp((fatShare(b) - (male ? .08 : .17)) / .3)
  const muscle = clamp(.2 + b.strength * .6 + (b.leanKg / b.baseLeanKg - 1) * 2.5)
  const stubbleDays = male ? (id === world.playerId ? day - b.lastShaveDay : hashText(`${world.seed}/${id}/shave/${day}`) % 3) : 0
  return { fat: +fat.toFixed(3), muscle: +muscle.toFixed(3), outfit: outfitOf(world, id), stubbleDays,
    shirtHue: unit(world, `${id}/${day}/hue`), pantsTone: unit(world, `${id}/${day}/pants`) }
}

/** Identidade visual (seed e sexo) e como a pessoa está hoje, para qualquer tela que a desenhe. */
export function appearanceOf(world: WorldState, id: string): Readonly<{ seed: string; sex: "F" | "M"; look: PersonLook }> {
  const person = world.people[id]!
  return { seed: person.appearanceSeed, sex: person.sex, look: lookOf(world, id) }
}

/** Presença: cuidado, fôlego, roupa adequada, sono. Pesa em entrevistas e primeiras impressões. */
export function presenceOf(world: WorldState, id: string): number {
  const b = world.bodies[id], person = world.people[id]!
  if (!b) return .5
  const bmi = bmiOf(b)
  const groomed = (person.sex === "M" && world.clock.day - b.lastShaveDay > 3 ? -.1 : 0) + (world.clock.day - b.lastHaircutDay > groomingRules.haircutDays ? -.08 : .04)
  const shape = bmi < 18.5 ? -.06 : bmi > 32 ? -.06 : bmi > 27 ? -.02 : .04
  const sleepy = id === world.playerId && person.needs.sleepPressure >= 70 ? -.08 : 0
  const dressed = id === world.playerId ? -dressGap(world) * .05 : 0
  return clamp(.5 + groomed + shape + b.fitness * .12 + b.strength * .06 + sleepy + dressed)
}

/** O espelho: frases sobre o próprio corpo, sem números de beleza (bíblia §8.1). */
export function mirrorText(world: WorldState): { lines: string[]; weightKg: number; trend: string | null } {
  const b = world.bodies[world.playerId]!, person = world.people[world.playerId]!
  const kg = round1(weightOf(b)), bmi = bmiOf(b)
  const lines: string[] = []
  lines.push(bmi < 18.5 ? "O corpo está mais magro do que o comum para a sua altura." : bmi < 25 ? "O peso está dentro do comum para a sua altura." : bmi < 30 ? "Você está acima do peso comum para a sua altura." : "O peso já pesa no dia a dia: escadas e calor cansam mais.")
  if (b.strength >= .65) lines.push("Os braços e as costas estão firmes; carregar compras virou fácil.")
  else if (b.strength >= .45) lines.push("Dá para notar alguma força ganha com os treinos.")
  if (b.fitness >= .6) lines.push("O fôlego está bom.")
  else if (b.fitness < .25) lines.push("Subir uma ladeira tira o fôlego.")
  const days = world.clock.day - b.lastShaveDay
  if (person.sex === "M" && days >= 2) lines.push(days >= 7 ? "A barba cresceu e já muda o rosto." : "A barba está por fazer.")
  if (world.clock.day - b.lastHaircutDay > groomingRules.haircutDays) lines.push("O cabelo está pedindo um corte.")
  const gap = dressGap(world)
  if (gap && world.clock.day % 7 < 5) lines.push("A roupa de hoje está mais simples do que o trabalho costuma pedir.")
  const month = b.weightLog.filter(l => world.clock.day - l.day <= 35)
  const trendKg = month.length ? kg - month[0]!.kg : 0
  const trend = Math.abs(trendKg) >= 1 ? `${trendKg > 0 ? "Mais" : "Menos"} ${Math.abs(Math.round(trendKg))} ${Math.abs(Math.round(trendKg)) === 1 ? "quilo" : "quilos"} desde ${formatDate({ day: month[0]!.day, minute: 0 })}.` : null
  return { lines, weightKg: kg, trend }
}

export function validBody(b: unknown): boolean {
  const o = b as Record<string, unknown>
  const num = (v: unknown, lo: number, hi: number) => typeof v === "number" && Number.isFinite(v) && v >= lo && v <= hi
  return !!o && typeof o === "object" && num(o.heightCm, 40, 230) && num(o.fatKg, 0, 300) && num(o.leanKg, 5, 200) && num(o.baseLeanKg, 5, 200) &&
    num(o.strength, 0, 1) && num(o.fitness, 0, 1) && (o.lastTrainingDay === null || Number.isInteger(o.lastTrainingDay)) && Number.isInteger(o.lastShaveDay) && Number.isInteger(o.lastHaircutDay) &&
    num(o.kcalIn, 0, 50000) && num(o.kcalOut, 0, 50000) && num(o.activity, 0, 1) && num(o.appetite, 0, 1) && Array.isArray(o.weightLog) && o.weightLog.length <= bodyRules.weightLogWeeks + 1
}
