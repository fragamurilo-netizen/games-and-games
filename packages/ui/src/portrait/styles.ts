// Parâmetros de desenho por estilo. Record<Id, ...> garante em tempo de compilação
// que todo estilo do catálogo da simulação tem desenho.

import type { BeardStyleId, HairStyleId } from "@paralelo/simulation"

export type Fringe = "straight" | "side" | "curtain" | "spiky" | "swept" | "wisp" | "quiff" | "pomp" | "back"
export type Tie = "ponytail" | "lowtail" | "bun" | "lowbun" | "messybun" | "topknot" | "halfup" | "pigtails" | "braids" | "sidebraid" | "puffs" | "afropuff"
export type HairSpecial = "shaved" | "buzz" | "fuzz" | "flattop" | "mohawk" | "afro" | "twists" | "locs" | "cornrows" | "boxbraids" | "horseshoe" | "thin"

export type HairParams = {
  /** comprimento geral (0 raspado ... 1.7 cintura) */
  len: number
  /** até onde descem as laterais: 0.5 = queixo, 1 = ombro */
  side: number
  back?: number
  volTop: number
  volSide: number
  part?: number
  fringe?: Fringe
  fringeLen?: number
  tie?: Tie
  special?: HairSpecial
  fade?: number
  curlBoost?: number
  wavyBoost?: number
  layered?: boolean
  tucked?: boolean
  slick?: boolean
  sideSwept?: boolean
}

export const HAIR_PARAMS: Record<HairStyleId, HairParams> = {
  "raspado-zero": { len: 0, side: 0.02, volTop: 0, volSide: 0, special: "shaved" },
  "maquina-2": { len: 0.05, side: 0.05, volTop: 0.01, volSide: 0.005, special: "buzz" },
  militar: { len: 0.1, side: 0.04, volTop: 0.03, volSide: 0.005, fade: 1 },
  "social-curto": { len: 0.22, side: 0.12, volTop: 0.05, volSide: 0.02, part: 0.35, fringe: "swept" },
  "risca-lado": { len: 0.3, side: 0.14, volTop: 0.07, volSide: 0.025, part: 0.45, fringe: "swept" },
  topete: { len: 0.4, side: 0.08, volTop: 0.16, volSide: 0.015, fringe: "quiff", fade: 0.6 },
  pompadour: { len: 0.5, side: 0.1, volTop: 0.22, volSide: 0.025, fringe: "pomp" },
  cesar: { len: 0.18, side: 0.08, volTop: 0.04, volSide: 0.015, fringe: "straight", fringeLen: 0.12 },
  "crop-texturizado": { len: 0.25, side: 0.05, volTop: 0.08, volSide: 0.01, fringe: "spiky", fringeLen: 0.18, fade: 0.9 },
  "degrade-navalhado": { len: 0.28, side: 0.02, volTop: 0.1, volSide: 0.004, fade: 1.2, fringe: "swept" },
  "flat-top": { len: 0.3, side: 0.03, volTop: 0.22, volSide: 0.01, special: "flattop", fade: 0.8 },
  espetado: { len: 0.3, side: 0.06, volTop: 0.14, volSide: 0.02, fringe: "spiky", fringeLen: 0.1 },
  lambido: { len: 0.35, side: 0.12, volTop: 0.06, volSide: 0.02, fringe: "back" },
  moicano: { len: 0.4, side: 0, volTop: 0.26, volSide: 0, special: "mohawk" },
  undercut: { len: 0.45, side: 0.02, volTop: 0.12, volSide: 0.004, fade: 1.5, fringe: "side", fringeLen: 0.25 },
  "cacheado-curto": { len: 0.25, side: 0.1, volTop: 0.1, volSide: 0.04, curlBoost: 1.5 },
  "black-power-curto": { len: 0.2, side: 0.1, volTop: 0.1, volSide: 0.06, special: "afro", curlBoost: 3 },
  "twists-curtos": { len: 0.28, side: 0.12, volTop: 0.1, volSide: 0.05, special: "twists" },
  pixie: { len: 0.25, side: 0.14, volTop: 0.06, volSide: 0.03, fringe: "side", fringeLen: 0.32, part: 0.4 },
  joaozinho: { len: 0.2, side: 0.1, volTop: 0.05, volSide: 0.02, fringe: "wisp", fringeLen: 0.2 },
  tigela: { len: 0.5, side: 0.42, volTop: 0.06, volSide: 0.05, fringe: "straight", fringeLen: 0.42 },
  cortina: { len: 0.55, side: 0.45, volTop: 0.05, volSide: 0.04, fringe: "curtain", fringeLen: 0.5, part: 0 },
  chanel: { len: 0.6, side: 0.62, volTop: 0.05, volSide: 0.06, part: 0.35 },
  "chanel-franja": { len: 0.6, side: 0.6, volTop: 0.05, volSide: 0.06, fringe: "straight", fringeLen: 0.45 },
  "long-bob": { len: 0.75, side: 0.82, volTop: 0.05, volSide: 0.06, part: 0.3 },
  shag: { len: 0.7, side: 0.8, volTop: 0.09, volSide: 0.09, fringe: "curtain", fringeLen: 0.45, layered: true },
  mullet: { len: 0.8, side: 0.25, back: 1, volTop: 0.08, volSide: 0.03, fringe: "spiky", fringeLen: 0.2 },
  surfista: { len: 0.65, side: 0.6, volTop: 0.07, volSide: 0.05, part: 0.1, fringe: "curtain", fringeLen: 0.55, wavyBoost: 1 },
  "medio-cacheado": { len: 0.6, side: 0.62, volTop: 0.12, volSide: 0.12, curlBoost: 1.5, part: 0.2 },
  "atras-orelha": { len: 0.55, side: 0.45, volTop: 0.06, volSide: 0.02, part: 0.4, tucked: true },
  "longo-liso": { len: 1.3, side: 1.35, volTop: 0.04, volSide: 0.05, part: 0.2 },
  "longo-repartido": { len: 1.2, side: 1.25, volTop: 0.03, volSide: 0.05, part: 0 },
  "longo-ondulado": { len: 1.2, side: 1.25, volTop: 0.07, volSide: 0.12, part: 0.3, wavyBoost: 1.2 },
  "longo-franja": { len: 1.2, side: 1.2, volTop: 0.05, volSide: 0.06, fringe: "straight", fringeLen: 0.45 },
  "longo-camadas": { len: 1.25, side: 1.2, volTop: 0.07, volSide: 0.1, fringe: "curtain", fringeLen: 0.6, layered: true },
  "longo-cacheado": { len: 1.05, side: 1.05, volTop: 0.16, volSide: 0.2, curlBoost: 1.5, part: 0.2 },
  "muito-longo": { len: 1.7, side: 1.75, volTop: 0.04, volSide: 0.05, part: 0.1 },
  "longo-de-lado": { len: 1.1, side: 1, volTop: 0.05, volSide: 0.06, part: 0.55, sideSwept: true },
  "black-power": { len: 0.7, side: 0.55, volTop: 0.34, volSide: 0.34, special: "afro", curlBoost: 3 },
  "black-power-grande": { len: 1, side: 0.7, volTop: 0.5, volSide: 0.5, special: "afro", curlBoost: 3 },
  "dreads-curtos": { len: 0.5, side: 0.5, volTop: 0.08, volSide: 0.06, special: "locs" },
  "dreads-longos": { len: 1.35, side: 1.35, volTop: 0.08, volSide: 0.08, special: "locs" },
  "trancas-nago": { len: 0.1, side: 0.05, volTop: 0.02, volSide: 0.01, special: "cornrows" },
  "box-braids": { len: 1.4, side: 1.45, volTop: 0.06, volSide: 0.08, special: "boxbraids" },
  "rabo-de-cavalo": { len: 1.1, side: 0.12, volTop: 0.03, volSide: 0.01, tie: "ponytail", slick: true },
  "rabo-baixo": { len: 1, side: 0.2, volTop: 0.03, volSide: 0.02, tie: "lowtail", part: 0 },
  "coque-alto": { len: 1, side: 0.1, volTop: 0.03, volSide: 0.01, tie: "bun", slick: true },
  "coque-baixo": { len: 1, side: 0.18, volTop: 0.03, volSide: 0.02, tie: "lowbun", part: 0.3 },
  "coque-baguncado": { len: 1, side: 0.2, volTop: 0.05, volSide: 0.03, tie: "messybun" },
  "coque-masculino": { len: 0.9, side: 0.03, volTop: 0.04, volSide: 0.005, tie: "topknot", fade: 1.2, slick: true },
  "meio-preso": { len: 1.15, side: 1.15, volTop: 0.06, volSide: 0.05, tie: "halfup", part: 0 },
  "maria-chiquinha": { len: 0.8, side: 0.12, volTop: 0.03, volSide: 0.01, tie: "pigtails", part: 0 },
  "duas-trancas": { len: 1.2, side: 0.12, volTop: 0.03, volSide: 0.02, tie: "braids", part: 0 },
  "tranca-lateral": { len: 1.2, side: 0.2, volTop: 0.04, volSide: 0.03, tie: "sidebraid", part: 0.4 },
  puffs: { len: 0.6, side: 0.05, volTop: 0.03, volSide: 0.01, tie: "puffs", part: 0, curlBoost: 3 },
  "afro-puff": { len: 0.7, side: 0.05, volTop: 0.03, volSide: 0.01, tie: "afropuff", curlBoost: 3 },
  calvo: { len: 0.12, side: 0.1, volTop: 0.02, volSide: 0.02, special: "horseshoe" },
  "coroa-rala": { len: 0.18, side: 0.12, volTop: 0.02, volSide: 0.02, special: "thin" },
  bebe: { len: 0.04, side: 0.03, volTop: 0.01, volSide: 0.005, special: "fuzz" },
  "infantil-franjinha": { len: 0.3, side: 0.28, volTop: 0.05, volSide: 0.04, fringe: "straight", fringeLen: 0.38 },
  "infantil-arrepiado": { len: 0.2, side: 0.1, volTop: 0.08, volSide: 0.03, fringe: "spiky", fringeLen: 0.1 },
}

export type BeardPart =
  | "mus" | "chin" | "cheek" | "cheekLow" | "neck" | "goatee" | "goateeFree" | "goateeWide" | "goateeRound" | "anchor"
  | "soul" | "strap" | "burns" | "chops" | "horseshoe" | "fumanchu"
export type MustacheShape = "standard" | "pencil" | "pencilWide" | "chevron" | "handlebar" | "walrus" | "english"

export type BeardParams = {
  parts: readonly BeardPart[]
  len: number
  stubble?: number
  patchy?: number
  mus?: MustacheShape
  musGap?: boolean
  point?: number
  round?: number
  boxed?: boolean
  wild?: boolean
  fuzz?: boolean
}

const FULL: readonly BeardPart[] = ["mus", "chin", "cheek", "neck"]

export const BEARD_PARAMS: Record<BeardStyleId, BeardParams> = {
  nenhuma: { parts: [], len: 0 },
  sombra: { parts: FULL, len: 0.02, stubble: 0.35 },
  "por-fazer": { parts: FULL, len: 0.05, stubble: 0.8 },
  "rala-jovem": { parts: ["mus", "chin", "cheek"], len: 0.1, stubble: 0.5, patchy: 0.6 },
  curta: { parts: FULL, len: 0.12 },
  cheia: { parts: FULL, len: 0.3 },
  longa: { parts: FULL, len: 0.7 },
  mago: { parts: FULL, len: 1.3, point: 0.6 },
  lenhador: { parts: FULL, len: 0.95, wild: true },
  garibaldi: { parts: FULL, len: 0.55, round: 1 },
  verdi: { parts: FULL, len: 0.4, round: 0.6, mus: "handlebar" },
  ducktail: { parts: FULL, len: 0.45, point: 1 },
  quadrada: { parts: FULL, len: 0.2, boxed: true },
  cavanhaque: { parts: ["mus", "goatee"], len: 0.12 },
  "cavanhaque-longo": { parts: ["mus", "goatee"], len: 0.4, point: 0.7 },
  barbicha: { parts: ["goatee"], len: 0.15 },
  "van-dyke": { parts: ["mus", "goateeFree"], len: 0.2, point: 0.5, mus: "handlebar" },
  balbo: { parts: ["mus", "goateeWide"], len: 0.14, musGap: true },
  ancora: { parts: ["mus", "anchor"], len: 0.14, musGap: true, mus: "pencilWide" },
  circular: { parts: ["mus", "goateeRound"], len: 0.1 },
  mosca: { parts: ["soul"], len: 0.08 },
  queixeira: { parts: ["strap"], len: 0.05 },
  amish: { parts: ["chin", "cheekLow", "neck"], len: 0.45 },
  costeletas: { parts: ["burns"], len: 0.06 },
  suicas: { parts: ["chops"], len: 0.12 },
  "suicas-bigode": { parts: ["chops", "mus"], len: 0.12, mus: "walrus" },
  bigode: { parts: ["mus"], len: 0.08 },
  "bigode-lapis": { parts: ["mus"], len: 0.03, mus: "pencil" },
  "bigode-chevron": { parts: ["mus"], len: 0.1, mus: "chevron" },
  "bigode-guidao": { parts: ["mus"], len: 0.1, mus: "handlebar" },
  "bigode-ferradura": { parts: ["mus", "horseshoe"], len: 0.08 },
  "bigode-morsa": { parts: ["mus"], len: 0.14, mus: "walrus" },
  "fu-manchu": { parts: ["mus", "fumanchu"], len: 0.08, mus: "pencilWide" },
  "bigode-ingles": { parts: ["mus"], len: 0.05, mus: "english" },
  "bigode-barba-rala": { parts: FULL, len: 0.05, stubble: 0.8 },
  penugem: { parts: ["mus"], len: 0.03, stubble: 0.35, fuzz: true },
}
