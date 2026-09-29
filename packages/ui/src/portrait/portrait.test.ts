import { BEARD_STYLES, HAIR_STYLES, createAppearance, inheritAppearance } from "@paralelo/simulation"
import { describe, expect, it } from "vitest"
import { buildPortrait, portraitSvg, renderPortrait, toSvg } from "."

const noNaN = (svg: string): boolean => !/NaN|Infinity/.test(svg)

describe("retrato 2,5D", () => {
  it("é determinístico para a mesma seed, idade e ângulo", () => {
    const a = portraitSvg(createAppearance("rua-das-flores-12"), { age: 34, yaw: 0.7 })
    const b = portraitSvg(createAppearance("rua-das-flores-12"), { age: 34, yaw: 0.7 })
    expect(a).toBe(b)
  })

  it("desenha qualquer ângulo de 0 a 360° sem valores inválidos", () => {
    const m = buildPortrait(createAppearance("giro", { sex: "M" }), { age: 40 })
    for (let deg = 0; deg < 360; deg += 15) {
      const svg = toSvg(renderPortrait(m, (deg * Math.PI) / 180))
      expect(noNaN(svg), `${deg}°`).toBe(true)
    }
  })

  it("cobre todas as idades de 0 a 110 anos", () => {
    const app = createAppearance("vida-inteira")
    for (const age of [0, 1, 3, 8, 14, 18, 30, 50, 70, 90, 110]) {
      expect(noNaN(portraitSvg(app, { age, yaw: 0.4 })), `${age} anos`).toBe(true)
    }
  })

  it("desenha todos os cabelos e barbas do catálogo", () => {
    const f = createAppearance("catalogo-f", { sex: "F" })
    const m = createAppearance("catalogo-m", { sex: "M" })
    for (const h of HAIR_STYLES) expect(noNaN(portraitSvg(f, { age: 28, hair: h.id, yaw: 0.5 })), h.id).toBe(true)
    for (const b of BEARD_STYLES) expect(noNaN(portraitSvg(m, { age: 38, beard: b.id, yaw: -0.4 })), b.id).toBe(true)
  })

  it("filhos herdam de forma determinística", () => {
    const mae = createAppearance("mae", { sex: "F" }).genome
    const pai = createAppearance("pai", { sex: "M" }).genome
    expect(inheritAppearance(mae, pai, "filho-1")).toEqual(inheritAppearance(mae, pai, "filho-1"))
  })
})
