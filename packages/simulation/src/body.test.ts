import { describe, expect, it } from "vitest"
import { lifeEvents, validateBodyContent } from "@paralelo/content"
import { absoluteMinute, createWorld, lookOf, mirrorText, outfitOf, queryBody, queryLife, validateWorld, weightOf, worldHash, type WorldState } from "."
import { apply } from "./test-support"

const quiet = (seed: string): WorldState => { const w = createWorld(seed); return { ...w, events: { ...w.events, seen: lifeEvents.map(e => e.id) } } }
const fed = (world: WorldState): WorldState => ({ ...world, people: { ...world.people, [world.playerId]: { ...world.people[world.playerId]!, needs: { energy: 90, stress: 20, hunger: 60, sleepPressure: 10 } } } })
const toDay = (world: WorldState, day: number, minute = 600): WorldState => {
  let w = world
  while (absoluteMinute(w.clock) < day * 1440 + minute) w = apply(w, { type: "wait", minutes: Math.min(10080, day * 1440 + minute - absoluteMinute(w.clock)) })
  return w
}

describe("corpo e aparência (bíblia §21)", () => {
  it("tem conteúdo válido e corpo para todo mundo", () => {
    expect(validateBodyContent()).toEqual([])
    const world = createWorld("corpo")
    expect(Object.keys(world.bodies).sort()).toEqual(Object.keys(world.people).sort())
    expect(validateWorld(world).ok).toBe(true)
  })

  it("comer demais engorda; comer pouco emagrece (balanço de energia)", () => {
    let heavy = quiet("peso"), light = quiet("peso")
    const start = weightOf(heavy.bodies[heavy.playerId]!)
    for (let d = 0; d < 14; d++) {
      for (let i = 0; i < 4; i++) heavy = apply(fed(heavy), { type: "snack" })
      heavy = toDay(heavy, d + 1)
      light = toDay(light, d + 1)
    }
    expect(weightOf(heavy.bodies[heavy.playerId]!)).toBeGreaterThan(start + 1)
    expect(weightOf(light.bodies[light.playerId]!)).toBeLessThan(start)
    expect(validateWorld(heavy).ok).toBe(true)
  })

  it("treino dá força com retorno decrescente e some sem prática", () => {
    let world = quiet("forca")
    const s0 = world.bodies[world.playerId]!.strength
    for (let d = 0; d < 20; d++) { world = apply(fed(world), { type: "exercise", kind: "home" }); world = toDay(world, d + 1) }
    const trained = world.bodies[world.playerId]!.strength
    expect(trained).toBeGreaterThan(s0 + .1)
    expect(executeTwice(world)).toBe(false)
    world = toDay(world, 80)
    expect(world.bodies[world.playerId]!.strength).toBeLessThan(trained)
  })

  it("barba cresce e aparece no desenho; fazer a barba zera", () => {
    let world = quiet("barba")
    world = { ...world, people: { ...world.people, [world.playerId]: { ...world.people[world.playerId]!, sex: "M" } } }
    world = toDay(world, 5)
    expect(lookOf(world, world.playerId).stubbleDays).toBe(5)
    world = apply(fed(world), { type: "groom", kind: "shave" })
    expect(lookOf(world, world.playerId).stubbleDays).toBe(0)
  })

  it("roupa do dia muda com o dia, e as outras pessoas também trocam", () => {
    const world = createWorld("roupa")
    const npc = Object.keys(world.people).find(id => id !== world.playerId)!
    const days = Array.from({ length: 14 }, (_, d) => outfitOf(world, npc, d))
    expect(new Set(days).size).toBeGreaterThan(1)
    expect(lookOf(world, npc).shirtHue).not.toBe(lookOf({ ...world, clock: { day: 1, minute: 480 } }, npc).shirtHue)
    const chosen = apply(world, { type: "dress", outfit: world.wardrobes[world.playerId]!.owned.at(-1)! })
    expect(outfitOf(chosen, chosen.playerId)).toBe(chosen.wardrobes[chosen.playerId]!.owned.at(-1))
  })

  it("o espelho fala em frases e mostra a tendência de peso", () => {
    const text = mirrorText(createWorld("espelho"))
    expect(text.lines.length).toBeGreaterThan(0)
    expect(text.weightKg).toBeGreaterThan(30)
  })

  it("é determinístico", () => {
    const run = () => toDay(apply(fed(quiet("det-corpo")), { type: "exercise", kind: "walk" }), 30)
    expect(worldHash(run())).toBe(worldHash(run()))
  })
})

function executeTwice(world: WorldState): boolean {
  try { apply(apply(fed(world), { type: "exercise", kind: "home" }), { type: "exercise", kind: "home" }); return true } catch { return false }
}

describe("corpo nas telas", () => {
  it("mostra frases, ações possíveis e a roupa do dia", () => {
    const world = toDay(quiet("tela-corpo"), 2)
    const body = queryBody(world)
    expect(body.lines.length).toBeGreaterThan(0)
    expect(body.weight).toMatch(/^\d+,\d kg$/)
    // sem matrícula, treino na academia não aparece como ação
    expect(body.actions.map(a => a.key)).toEqual(["walk", "run", "home"])
    expect(body.wardrobe.owned.filter(o => o.wearing)).toHaveLength(1)
    expect(body.wardrobe.shop.every(o => !world.wardrobes[world.playerId]!.owned.includes(o.id))).toBe(true)
    expect(body.gym.member).toBe(false)
    // nenhum número de beleza, força ou fôlego chega à tela (bíblia §8.1)
    expect(JSON.stringify({ lines: body.lines, actions: body.actions, care: body.care })).not.toMatch(/\d+(,\d+)?\s*%|força \d|fôlego \d/)
    const joined = apply({ ...world, clock: { ...world.clock, minute: 600 } }, { type: "gym", action: "join" })
    expect(queryBody(joined).actions.map(a => a.key)).toContain("gym")
    expect(queryBody(joined).gym.member).toBe(true)
  })

  it("quem aparece nas telas leva junto o corpo e a roupa de hoje", () => {
    const life = queryLife(toDay(quiet("olhar"), 3))
    expect(life.appearance.look.outfit).toBeTruthy()
    expect(life.appearance.look.stubbleDays).toBeGreaterThanOrEqual(0)
    for (const person of life.people) expect(person.appearance.look.outfit).toBeTruthy()
  })
})
