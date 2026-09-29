import { describe, expect, it } from "vitest"
import { absoluteMinute, createWorld, executeCommand, validateWorld, worldHash } from "@paralelo/simulation"
import { decodeSnapshot, encodeSnapshot } from "@paralelo/persistence"

describe("fundação de vida longa", () => {
  it.each([365, 1826, 7305])("mantém integridade e retomada após %i dias", days => {
    let world = createWorld(`long-run:${days}`)
    const end = absoluteMinute(world.clock) + days * 1440
    let reloaded = false
    while (absoluteMinute(world.clock) < end) {
      const result = executeCommand(world, { type: "wait", minutes: Math.min(10080, end - absoluteMinute(world.clock)) })
      expect(result.ok).toBe(true)
      if (!result.ok) return
      world = result.value
      if (!reloaded && world.revision > 30) {
        const decoded = decodeSnapshot(encodeSnapshot(world))
        expect(decoded.ok).toBe(true)
        if (decoded.ok) { expect(worldHash(decoded.value)).toBe(worldHash(world)); world = decoded.value }
        reloaded = true
      }
    }
    expect(absoluteMinute(world.clock)).toBe(end)
    expect(validateWorld(world)).toMatchObject({ ok: true })
    expect(world.recentCommands.length).toBeLessThanOrEqual(256)
    expect(world.timeline.filter(e => e.kind === "message")).toHaveLength(1)
  })
})
