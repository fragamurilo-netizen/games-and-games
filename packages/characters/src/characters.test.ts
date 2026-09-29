import { createWorld, queryLife } from "@paralelo/simulation"
import { describe, expect, it } from "vitest"
import { drawCharacter } from "."

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
})
