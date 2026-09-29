import { routineRules } from "@paralelo/content"
import type { WorldState, WorldStateV3, WorldStateV4 } from "../domain/world"
import { nextWeekday, scheduleWorkDay } from "./career"
import { changeNeeds } from "./needs"
import { postLedger } from "./finance"
import { appendEntry } from "../timeline"

// A campanha antiga recebe recursos iniciais, sem inventar necessidades ou faltas passadas.
export function upgradeWorldV3(base: WorldStateV3): WorldStateV4 {
  const world: WorldStateV4 = { ...base, schemaVersion: 4,
    people: Object.fromEntries(Object.entries(base.people).map(([id, person]) => [id, { ...person, needs: { ...person.needs, hunger: 20, sleepPressure: 30 } }])),
    routine: { pantryMeals: routineRules.initialPantryMeals, lastCommunityMealDay: null }, employmentHistory: [],
    employment: base.employment ? { ...base.employment, requiredFromDay: nextWeekday(base.clock.day + 1), consecutiveAbsences: 0, lastAssessedDay: null } : null }
  return world.employment ? scheduleWorkDay(world, world.employment.requiredFromDay) : world
}
export type MealSource = keyof typeof routineRules.meals
export function mealReason(world: WorldState, source: MealSource): string | null {
  if (!Object.hasOwn(routineRules.meals, source)) return "Esta refeição não está disponível."
  const meal = routineRules.meals[source]
  if (!meal) return "Esta refeição não está disponível."
  if (meal.priceCents > 0 && world.finance.balanceCents < meal.priceCents) return "Faltam R$ 18,00 disponíveis para essa refeição."
  if (source === "home" && world.routine.pantryMeals < 1) return "A despensa está vazia. Faça compras ou procure outra refeição."
  if (source === "community" && world.routine.lastCommunityMealDay === world.clock.day) return "Você já recebeu a refeição comunitária de hoje. Amanhã haverá outra."
  if (source === "community" && (world.clock.minute < 660 || world.clock.minute > 840)) return "O almoço comunitário recebe pessoas das 11h às 14h, todos os dias."
  if (world.people[world.playerId]!.needs.hunger < 15) return "Você acabou de comer. Pode deixar a próxima refeição para mais tarde."
  return null
}
export function groceriesReason(world: WorldState): string | null {
  if (world.routine.pantryMeals + routineRules.groceries.portions > routineRules.groceries.capacity) return "Ainda há bastante comida em casa. Use parte dela antes de comprar mais."
  return world.finance.balanceCents < routineRules.groceries.priceCents ? "Você precisa de R$ 48,00 disponíveis para essas compras." : null
}
export function finishMeal(world: WorldState, source: MealSource, startedDay: number): WorldState {
  const meal = routineRules.meals[source]
  let next = changeNeeds(world, meal)
  next = { ...next, routine: { pantryMeals: next.routine.pantryMeals - (source === "home" ? 1 : 0), lastCommunityMealDay: source === "community" ? startedDay : next.routine.lastCommunityMealDay } }
  if (meal.priceCents) next = postLedger(next, { amountCents: -meal.priceCents, category: "food", text: "Refeição no restaurante do bairro", cause: "command.meal:restaurant" })
  const text = source === "home" ? "Você preparou uma refeição com o que tinha em casa e comeu com calma."
    : source === "community" ? "Você almoçou no centro comunitário. A refeição foi gratuita; o atendimento acontece todos os dias, das 11h às 14h."
    : "Você fez uma refeição no restaurante da esquina. O prato do dia custou R$ 18,00."
  return appendEntry(next, { at: next.clock, kind: "action", text, personIds: [next.playerId], cause: `command.meal:${source}` })
}
export function finishGroceries(world: WorldState): WorldState {
  const next = postLedger({ ...world, routine: { ...world.routine, pantryMeals: world.routine.pantryMeals + routineRules.groceries.portions } },
    { amountCents: -routineRules.groceries.priceCents, category: "food", text: "Compras para seis refeições em casa", cause: "command.buy-groceries" })
  return appendEntry(next, { at: next.clock, kind: "action", text: "Você voltou do mercado com ingredientes para seis refeições. As compras custaram R$ 48,00.", personIds: [next.playerId], cause: "command.buy-groceries" })
}
