import { describe, expect, it } from "vitest"
import { ageAt, beginLife, createWorld, queryCareer, validateProfile, validateWorld, worldHash } from "."

describe("começo da campanha (bíblia §47, §48)", () => {
  it("aplica nome, sexo e idade sem mexer no resto do mundo", () => {
    const base = createWorld("comeco")
    const result = beginLife(base, { firstName: "  Tainá ", sex: "F", age: 19, start: "job-search" })
    if (!result.ok) throw new Error(result.error)
    const player = result.value.people[result.value.playerId]!
    expect(player.name).toBe("Tainá Ferreira")
    expect(player.sex).toBe("F")
    expect(ageAt(player.birthDate, result.value.clock)).toBe(19)
    expect(result.value.employment).toBeNull()
    expect(result.value.companies).toEqual(base.companies)
    expect(validateWorld(result.value).ok).toBe(true)
  })

  it("com emprego simples, começa contratado com agenda e colegas", () => {
    const result = beginLife(createWorld("contratado"), { firstName: "Otávio", sex: "M", age: 26, start: "simple-job" })
    if (!result.ok) throw new Error(result.error)
    const world = result.value
    expect(world.employment).not.toBeNull()
    expect(world.scheduled.filter(s => s.employmentId === world.employment!.id)).toHaveLength(2)
    expect(Object.values(world.relationships).some(r => r.tags.includes("coworker"))).toBe(true)
    expect(queryCareer(world).employment?.company).toBe(world.companies[world.employment!.companyId]!.name)
    expect(world.timeline.at(-1)?.text).toContain("primeiro turno")
    expect(validateWorld(world).ok).toBe(true)
  })

  it("é determinístico e recusa perfis inválidos", () => {
    const profile = { firstName: "Iara", sex: "F", age: 22, start: "simple-job" } as const
    const a = beginLife(createWorld("igual"), profile), b = beginLife(createWorld("igual"), profile)
    expect(a.ok && b.ok && worldHash(a.value) === worldHash(b.value)).toBe(true)
    expect(validateProfile({ ...profile, firstName: "A" }).ok).toBe(false)
    expect(validateProfile({ ...profile, firstName: "R2D2" }).ok).toBe(false)
    expect(validateProfile({ ...profile, age: 17 }).ok).toBe(false)
    expect(validateProfile({ ...profile, age: 31 }).ok).toBe(false)
  })
})
