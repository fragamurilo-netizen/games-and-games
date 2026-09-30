// Personagens 2D do PARALELO (renderizador vetorial do laboratório em prototypes/faces).
// Os scripts em ./renderer são puros (sem DOM no caminho de build) e se registram em globalThis;
// este módulo é a única porta de entrada tipada para o app e os testes.
import "./renderer/faces-core.js"
import "./renderer/character-catalog.js"
import "./renderer/vector-body.js"
import "./renderer/vector-wardrobe.js"
import "./renderer/vector-character.js"

export type CharacterSex = "F" | "M"
export type CharacterView = "portrait" | "body"

type Genome = Readonly<{ id: string; sex: CharacterSex; pref: Readonly<{ beard: string }> }>
type BuildResult = Readonly<{ svg: string; width: number; height: number; info: Readonly<{ hair: string; beard: string; height: number; fat: number; age: number }> }>
type Renderer = {
  FaceCore: { makeGenome(seed: string, opts: { sex: CharacterSex }): Genome }
  VectorCharacter: { build(genome: Genome, opts: { age: number; view: CharacterView; bg?: boolean; expression?: CharacterExpression; fat?: number; muscle?: number; outfit?: string; beard?: string; shirtHue?: number; pantsTone?: number }): BuildResult }
}
const api = globalThis as unknown as Renderer

export type CharacterExpression = "warm" | "curious" | "neutral" | "tired" | "tense"
/** Como a pessoa está hoje: corpo, roupa e barba vêm da simulação (bíblia §21). */
export type CharacterLook = Readonly<{ fat?: number; muscle?: number; outfit?: string; beard?: string; shirtHue?: number; pantsTone?: number
  /** dias sem fazer a barba; só pesa em quem não usa barba por estilo */
  stubbleDays?: number }>
export type CharacterInput = Readonly<{ seed: string; sex: CharacterSex; age: number; view?: CharacterView; background?: boolean; expression?: CharacterExpression; look?: CharacterLook }>
export type CharacterDrawing = Readonly<{ svg: string; width: number; height: number; heightCm: number }>

/** Desenho determinístico de uma pessoa: mesma seed, sexo e idade produzem o mesmo SVG. */
export function drawCharacter({ seed, sex, age, view = "portrait", background = true, expression = "warm", look }: CharacterInput): CharacterDrawing {
  const genome = api.FaceCore.makeGenome(seed, { sex })
  const { stubbleDays, ...rest } = look ?? {}
  const beard = rest.beard ?? (genome.pref.beard === "nenhuma" && stubbleDays !== undefined ? beardAfter(stubbleDays) : undefined)
  const result = api.VectorCharacter.build(genome, { age: Math.max(0, Math.min(110, age)), view, bg: background, expression, ...rest, ...(beard ? { beard } : {}) })
  return { svg: result.svg, width: result.width, height: result.height, heightCm: result.info.height }
}

/** Barba de quem costuma andar barbeado, pelos dias sem lâmina. */
export function beardAfter(days: number): string | undefined {
  return days >= 15 ? "cheia" : days >= 6 ? "curta" : days >= 2 ? "por-fazer" : undefined
}
