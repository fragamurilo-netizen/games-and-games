export const RNG_STREAMS = ["world", "ai", "event", "career", "health", "relationship"] as const
export type RngStream = (typeof RNG_STREAMS)[number]
export type RngState = Readonly<Record<RngStream, number>>
export const createRng = (): RngState => ({ world: 0, ai: 0, event: 0, career: 0, health: 0, relationship: 0 })

export function hashText(text: string): number {
  let value = 2166136261
  for (let i = 0; i < text.length; i++) value = Math.imul(value ^ text.charCodeAt(i), 16777619)
  value ^= value >>> 16
  value = Math.imul(value, 0x7feb352d)
  value ^= value >>> 15
  value = Math.imul(value, 0x846ca68b)
  return (value ^ (value >>> 16)) >>> 0
}

// Estado explícito e serializável. Um sorteio de saúde nunca consome a stream social.
export function draw(seed: string, state: RngState, stream: RngStream): Readonly<{ value: number; state: RngState }> {
  const counter = state[stream]
  return { value: hashText(JSON.stringify([seed, stream, counter])) / 4294967296, state: { ...state, [stream]: counter + 1 } }
}
