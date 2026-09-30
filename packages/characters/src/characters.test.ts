import { createWorld, queryLife } from "@paralelo/simulation"
import { describe, expect, it } from "vitest"
import { beardAfter, drawCharacter } from "."

describe("personagens do mundo", () => {
  it("desenha cada pessoa próxima de forma determinística", () => {
    const life = queryLife(createWorld("personagens"))
    for (const person of [{ ...life.appearance, age: life.age }, ...life.people.map(p => ({ ...p.appearance, age: p.age }))]) {
      const a = drawCharacter(person), b = drawCharacter(person)
      expect(a.svg).toBe(b.svg)
      expect(a.svg).not.toMatch(/NaN|Infinity|undefined/)
    }
  })
  it("respeita o sexo guardado na pessoa", () => {
    const f = drawCharacter({ seed: "mesma-seed", sex: "F", age: 30 }), m = drawCharacter({ seed: "mesma-seed", sex: "M", age: 30 })
    expect(f.svg).not.toBe(m.svg)
  })
  it("envelhece a mesma pessoa sem trocar de identidade", () => {
    const young = drawCharacter({ seed: "vida", sex: "F", age: 20 }), old = drawCharacter({ seed: "vida", sex: "F", age: 80 })
    expect(young.svg).not.toBe(old.svg)
    expect(drawCharacter({ seed: "vida", sex: "F", age: 20, view: "body" }).heightCm).toBeGreaterThan(140)
  })
  it("barba por fazer cresce em quem costuma andar barbeado", () => {
    expect([0, 1, 2, 6, 15].map(beardAfter)).toEqual([undefined, undefined, "por-fazer", "curta", "cheia"])
    // procura um genoma barbeado para comparar
    const seed = Array.from({ length: 40 }, (_, i) => `barba-${i}`).find(s => drawCharacter({ seed: s, sex: "M", age: 30, look: { stubbleDays: 20 } }).svg !== drawCharacter({ seed: s, sex: "M", age: 30 }).svg)
    expect(seed).toBeDefined()
    const clean = drawCharacter({ seed: seed!, sex: "M", age: 30, look: { stubbleDays: 0 } }).svg
    expect(clean).toBe(drawCharacter({ seed: seed!, sex: "M", age: 30 }).svg)
    expect(drawCharacter({ seed: seed!, sex: "M", age: 30, look: { stubbleDays: 3 } }).svg).not.toBe(clean)
    // mulheres não ganham barba
    expect(drawCharacter({ seed: seed!, sex: "F", age: 30, look: { stubbleDays: 20 } }).svg).toBe(drawCharacter({ seed: seed!, sex: "F", age: 30 }).svg)
  })
  it("corpo e roupa mudam o desenho", () => {
    const base = { seed: "corpo", sex: "F" as const, age: 30, view: "body" as const }
    expect(drawCharacter({ ...base, look: { fat: .8 } }).svg).not.toBe(drawCharacter({ ...base, look: { fat: .1 } }).svg)
    expect(drawCharacter({ ...base, look: { outfit: "blazer" } }).svg).not.toBe(drawCharacter({ ...base, look: { outfit: "shorts" } }).svg)
  })
})
