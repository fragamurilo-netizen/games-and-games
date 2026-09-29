import { describe, expect, it } from "vitest"
import { err, ok } from "."

describe("Result", () => {
  it("cria sucesso e erro", () => {
    expect(ok(1)).toEqual({ ok: true, value: 1 })
    expect(err("x")).toEqual({ ok: false, error: "x" })
  })
})
