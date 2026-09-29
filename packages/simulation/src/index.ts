// Núcleo de simulação em TypeScript puro.
// Regra: este pacote NUNCA importa React / React Native (bíblia §35–36).
// Sem Math.random(): usar RNG determinístico com streams nomeados (§38).
export * from "./domain/world"
export * from "./world"
export * from "./rng"
export * from "./time"
export * from "./commands"
export * from "./queries"
export * from "./validation"
export * from "./hash"
export * from "./systems/slice"
export * from "./systems/finance"
export * from "./systems/career"
export * from "./systems/events"
export * from "./systems/routine"
export * from "./systems/appearance"
