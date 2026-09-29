// CLI de desenvolvimento (bíblia §80): gerar mundo, avançar tempo,
// inspecionar pessoas e rodar benchmarks sem UI.
import { readFileSync, writeFileSync } from "node:fs"
import { performance } from "node:perf_hooks"
import { createWorld, executeCommand, queryLife, validateWorld, worldHash, type Command } from "@paralelo/simulation"
import { decodeSnapshot, encodeSnapshot } from "@paralelo/persistence"

function option(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`)
  if (index < 0) return undefined
  const value = process.argv[index + 1]
  if (!value || value.startsWith("--")) throw new Error(`Informe um valor para --${name}.`)
  return value
}
function main() {
  if (process.argv.includes("--help")) {
    console.log("npm run sim -- --seed flores --days 7 --save campanha.json\nOpções: --load arquivo --inspect person:player --benchmark 1000 --rest --contact person:mother")
    return
  }
  const loadedFile = option("load")
  let world = createWorld(option("seed") ?? "vila-das-flores")
  if (loadedFile) {
    const result = decodeSnapshot(readFileSync(loadedFile, "utf8"))
    if (!result.ok) throw new Error(result.error.message)
    world = result.value
  }
  const apply = (command: Command) => {
    const result = executeCommand(world, command)
    if (!result.ok) throw new Error(result.error.message)
    world = result.value
  }
  if (process.argv.includes("--rest")) apply({ type: "rest" })
  const contact = option("contact")
  if (contact) {
    const person = world.people[contact]
    if (!person) throw new Error("Pessoa não encontrada.")
    apply({ type: "contact", personId: person.id })
  }
  const days = Number(option("days") ?? "0")
  if (!Number.isSafeInteger(days) || days < 0 || days > 7305) throw new Error("--days deve estar entre 0 e 7305.")
  // Fast-forward continua após pausas narrativas, sem pular eventos vencidos.
  const target = world.clock.day * 1440 + world.clock.minute + days * 1440
  while (world.clock.day * 1440 + world.clock.minute < target) apply({ type: "wait", minutes: Math.min(10080, target - (world.clock.day * 1440 + world.clock.minute)) })
  const benchmark = Number(option("benchmark") ?? "0")
  if (!Number.isSafeInteger(benchmark) || benchmark < 0 || benchmark > 100000) throw new Error("--benchmark deve estar entre 0 e 100000.")
  if (benchmark) {
    const start = performance.now()
    for (let i = 0; i < benchmark; i++) createWorld(`benchmark:${i}`)
    console.log(JSON.stringify({ worlds: benchmark, milliseconds: +(performance.now() - start).toFixed(2) }))
  }
  const valid = validateWorld(world)
  if (!valid.ok) throw new Error(valid.error.join(" "))
  const inspected = option("inspect")
  if (inspected) {
    if (!world.people[inspected]) throw new Error("Pessoa não encontrada.")
    console.log(JSON.stringify(world.people[inspected], null, 2))
  }
  const life = queryLife(world)
  console.log(`${life.name}, ${life.age} anos · ${life.city}\n${life.date}, ${life.time}\nSeed: ${world.seed} · Revisão: ${world.revision} · Hash: ${worldHash(world)}`)
  for (const entry of [...life.timeline].reverse()) console.log(`${entry.date} ${entry.time} · ${entry.text}`)
  const saveFile = option("save")
  if (saveFile) writeFileSync(saveFile, encodeSnapshot(world), "utf8")
}
try { main() } catch (error) { console.error(error instanceof Error ? error.message : error); process.exitCode = 1 }
