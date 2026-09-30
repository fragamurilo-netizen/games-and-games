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

type Genome = Readonly<{ id: string; sex: CharacterSex }>
type BuildResult = Readonly<{ svg: string; width: number; height: number; info: Readonly<{ hair: string; beard: string; height: number; fat: number; age: number }> }>
type Renderer = {
  FaceCore: { makeGenome(seed: string, opts: { sex: CharacterSex }): Genome }
  VectorCharacter: { build(genome: Genome, opts: { age: number; view: CharacterView; bg?: boolean; expression?: CharacterExpression }): BuildResult }
}
const api = globalThis as unknown as Renderer

export type CharacterExpression = "warm" | "curious" | "neutral" | "tired" | "tense"
export type CharacterInput = Readonly<{ seed: string; sex: CharacterSex; age: number; view?: CharacterView; background?: boolean; expression?: CharacterExpression }>
export type CharacterDrawing = Readonly<{ svg: string; width: number; height: number; heightCm: number }>

/** Desenho determinístico de uma pessoa: mesma seed, sexo e idade produzem o mesmo SVG. */
export function drawCharacter({ seed, sex, age, view = "portrait", background = true, expression = "warm" }: CharacterInput): CharacterDrawing {
  const genome = api.FaceCore.makeGenome(seed, { sex })
  const result = api.VectorCharacter.build(genome, { age: Math.max(0, Math.min(110, age)), view, bg: background, expression })
  return { svg: result.svg, width: result.width, height: result.height, heightCm: result.info.height }
}
