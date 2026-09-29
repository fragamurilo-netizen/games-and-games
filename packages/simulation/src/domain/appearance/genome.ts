// Genoma de aparência: traços fixos de nascença, gerados por seed e herdados dos pais.
// O estilo (corte, barba, óculos, roupa) é escolha da pessoa e pode mudar; fica em AppearanceStyle.

import { hashText } from "../../rng"
import { seededRandom, type SeededRandom } from "./random"
import {
  ADULT_HAIR_POOLS,
  BEARD_STYLES,
  CHILD_HAIR_POOLS,
  GLASSES,
  SHIRTS,
  type BeardStyleId,
  type GlassesId,
  type HairStyleId,
  type ShirtKind,
} from "./catalog"

export type Sex = "F" | "M"

// Traços contínuos em z-score (média 0, desvio 1).
export const FACE_TRAITS = [
  "faceW", "faceL", "jawW", "jawSq", "chinL", "chinW", "cheekB", "forehead", "skullH",
  "eyeSize", "eyeSpace", "eyeTilt", "eyeOpen", "eyeY", "lidFold", "hood",
  "browThick", "browArch", "browY", "browLen", "browGap",
  "noseL", "noseW", "noseBridge", "noseTip", "noseHook",
  "mouthW", "lipU", "lipL", "mouthY", "cupid",
  "earSize", "earOut", "neck",
] as const
export type FaceTrait = (typeof FACE_TRAITS)[number]
export type FaceTraits = Record<FaceTrait, number>

/** Par de alelos (um de cada pai). */
export type Alleles = readonly [number, number]

export type AppearanceGenome = {
  readonly version: 1
  readonly seed: string
  readonly sex: Sex
  readonly face: FaceTraits
  /** magnitude da assimetria facial (0 = simétrico) */
  readonly asymmetry: number
  readonly asymmetrySeed: number
  readonly skin: {
    readonly melanin: Alleles
    readonly undertone: number
    readonly rosiness: number
    readonly freckles: Alleles
    readonly quality: number
    readonly agingRate: number
    readonly moles: number
  }
  readonly eyes: { readonly darkness: Alleles; readonly green: Alleles }
  readonly hair: {
    readonly eumelanin: Alleles
    /** variante recessiva do ruivo (MC1R): ruivo só com as duas */
    readonly red: readonly [boolean, boolean]
    /** 0 liso, 1 ondulado, 2 cacheado, 3 crespo */
    readonly texture: Alleles
    readonly density: number
    readonly greyOnset: number
    readonly baldness: number
    readonly baldOnset: number
    readonly beardDensity: number
    readonly beardRed: number
  }
  readonly body: { readonly fatTendency: number; readonly heightZ: number }
}

export type AppearanceStyle = {
  hair: HairStyleId
  beard: BeardStyleId
  glasses: GlassesId | null
  /** 0 sem maquiagem, 1 maquiagem marcada */
  makeup: number
  shirt: ShirtKind
  shirtHue: number
  shirtTone: number
}

export type Appearance = { genome: AppearanceGenome; style: AppearanceStyle }

export const ANCESTRIES = ["euro", "afro", "east", "south", "latin", "mena"] as const
export type Ancestry = (typeof ANCESTRIES)[number]

type AncestryBias = {
  mel: readonly [number, number]
  eye: readonly [number, number]
  hairEu: readonly [number, number]
  red: number
  tex: readonly [number, number]
  lid: number
  nose: number
  lips: number
  noseW: number
}

// Viés populacional grosseiro para a amostragem. A herança dos pais sempre prevalece.
const ANCESTRY_BIAS: Record<Ancestry, AncestryBias> = {
  euro: { mel: [0.1, 0.07], eye: [0.45, 0.3], hairEu: [0.5, 0.28], red: 0.12, tex: [0.45, 0.5], lid: 0.8, nose: 0.5, lips: -0.3, noseW: 0 },
  afro: { mel: [0.78, 0.1], eye: [0.93, 0.04], hairEu: [0.95, 0.04], red: 0, tex: [2.6, 0.35], lid: 0.8, nose: -0.2, lips: 0.9, noseW: 0.9 },
  east: { mel: [0.24, 0.06], eye: [0.92, 0.05], hairEu: [0.93, 0.05], red: 0, tex: [0.1, 0.2], lid: -1.4, nose: -0.9, lips: 0, noseW: 0 },
  south: { mel: [0.5, 0.1], eye: [0.88, 0.08], hairEu: [0.9, 0.06], red: 0, tex: [0.7, 0.5], lid: 0.7, nose: 0.4, lips: 0.2, noseW: 0 },
  latin: { mel: [0.36, 0.14], eye: [0.78, 0.18], hairEu: [0.82, 0.12], red: 0.02, tex: [1, 0.7], lid: 0.5, nose: 0.1, lips: 0.3, noseW: 0 },
  mena: { mel: [0.3, 0.08], eye: [0.82, 0.12], hairEu: [0.88, 0.08], red: 0.03, tex: [1.1, 0.6], lid: 0.6, nose: 0.9, lips: 0.1, noseW: 0 },
}

// A atratividade não é um número guardado: emerge de proporção, simetria e pele.
// Estes alvos só enviesam a geração quando alguém pede um rosto bonito ou feio.
const BEAUTY_TARGET: Record<Sex, Partial<FaceTraits>> = {
  F: { eyeSize: 0.9, eyeOpen: 0.4, lipU: 0.7, lipL: 0.9, noseW: -0.6, noseL: -0.4, noseTip: -0.3, jawW: -0.5, jawSq: -0.6, cheekB: 0.9, chinW: -0.4, browThick: -0.2, browArch: 0.5, eyeTilt: 0.5, earSize: -0.3, earOut: -0.6 },
  M: { jawW: 0.8, jawSq: 0.9, cheekB: 0.7, chinL: 0.4, chinW: 0.3, browThick: 0.4, eyeSize: 0.2, noseW: -0.2, lipL: 0.3, eyeTilt: 0.3, earOut: -0.6, faceL: 0.2 },
}
const PLAIN_TARGET: Partial<FaceTraits> = {
  noseL: 1.6, noseW: 1.5, noseTip: 1.4, noseHook: 1.2, eyeSize: -1.4, eyeOpen: -1, earSize: 1.6, earOut: 1.8,
  chinL: -1.6, jawSq: -0.8, lipU: -1.2, lipL: -1, browGap: -1.8, forehead: 1.4, cheekB: -1.2, mouthW: 1.1,
}

const clamp = (x: number, lo = 0, hi = 1): number => (x < lo ? lo : x > hi ? hi : x)
const lerp = (a: number, b: number, t: number): number => a + (b - a) * t
export const smoothstep = (a: number, b: number, x: number): number => {
  const t = clamp((x - a) / (b - a))
  return t * t * (3 - 2 * t)
}

export type GenomeOptions = {
  sex?: Sex
  ancestry?: Ancestry
  /** -1 feio ... 0 comum ... +1 muito bonito */
  beauty?: number
}

export function createGenome(seed: string, opts: GenomeOptions = {}): AppearanceGenome {
  const r = seededRandom(seed)
  const sex: Sex = opts.sex ?? (r.chance(0.5) ? "F" : "M")
  const anc = ANCESTRY_BIAS[opts.ancestry ?? r.pick(ANCESTRIES)]
  const face = {} as FaceTraits
  for (const k of FACE_TRAITS) face[k] = r.z()
  face.lidFold = clamp(anc.lid + r.z(0.6), -2.6, 2.6)
  face.noseBridge = clamp(anc.nose + r.z(0.8), -2.6, 2.6)
  face.lipU = clamp(face.lipU * 0.8 + anc.lips, -2.6, 2.6)
  face.lipL = clamp(face.lipL * 0.8 + anc.lips, -2.6, 2.6)
  face.noseW = clamp(face.noseW * (anc.noseW ? 0.7 : 1) + anc.noseW, -2.6, 2.6)

  const beauty = opts.beauty ?? 0
  if (beauty > 0) {
    const target = BEAUTY_TARGET[sex]
    for (const k of FACE_TRAITS) face[k] = lerp(face[k], target[k] ?? 0, beauty * 0.75)
  } else if (beauty < 0) {
    for (const k of FACE_TRAITS) {
      const t = PLAIN_TARGET[k]
      if (t !== undefined && r.chance(0.6)) face[k] = clamp(lerp(face[k], t * (1.1 + r.next() * 0.9), -beauty), -3.8, 3.8)
    }
  }

  const allele = (mean: number, sd: number): number => clamp(mean + r.normal() * sd)
  const pair = (mean: number, sd: number): Alleles => [allele(mean, sd), allele(mean, sd)]
  return {
    version: 1,
    seed,
    sex,
    face,
    asymmetry: clamp(Math.abs(r.normal()) * 0.35 + (beauty < 0 ? -beauty * 0.9 : 0) - (beauty > 0 ? beauty * 0.3 : 0), 0.02, 1.4),
    asymmetrySeed: Math.floor(r.next() * 1e9),
    skin: {
      melanin: pair(anc.mel[0], anc.mel[1]),
      undertone: r.z(0.8),
      rosiness: clamp(0.3 + r.normal() * 0.2),
      freckles: [r.next() < 0.25 ? r.next() : 0, r.next() < 0.25 ? r.next() : 0],
      quality: clamp(0.75 + r.normal() * 0.15 + beauty * 0.25),
      agingRate: clamp(1 + r.normal() * 0.15, 0.7, 1.4),
      moles: Math.floor(r.next() * 6 + (r.next() < 0.2 ? 6 : 0)),
    },
    eyes: { darkness: pair(anc.eye[0], anc.eye[1]), green: [r.next(), r.next()] },
    hair: {
      eumelanin: pair(anc.hairEu[0], anc.hairEu[1]),
      red: [r.chance(anc.red * 2.2), r.chance(anc.red * 2.2)],
      texture: [clamp(anc.tex[0] + r.normal() * anc.tex[1], 0, 3), clamp(anc.tex[0] + r.normal() * anc.tex[1], 0, 3)],
      density: clamp(0.85 + r.normal() * 0.12, 0.45, 1),
      greyOnset: clamp(38 + r.normal() * 8, 22, 65),
      baldness: sex === "M" ? clamp(r.next() * 1.1 - 0.1) : clamp(r.next() * 0.25 - 0.1),
      baldOnset: clamp(30 + r.normal() * 8, 19, 60),
      beardDensity: clamp(0.72 + r.normal() * 0.2, 0.15, 1),
      beardRed: clamp(r.next() * 0.35),
    },
    body: { fatTendency: clamp(0.35 + r.normal() * 0.2), heightZ: r.z() },
  }
}

/** Filho de dois genomas: metade de cada pai + mutação; alelos sorteados como em genética real. */
export function inheritGenome(mother: AppearanceGenome, father: AppearanceGenome, seed: string, opts: { sex?: Sex } = {}): AppearanceGenome {
  const r = seededRandom(seed)
  const sex: Sex = opts.sex ?? (r.chance(0.5) ? "F" : "M")
  const face = {} as FaceTraits
  for (const k of FACE_TRAITS) face[k] = clamp((mother.face[k] + father.face[k]) / 2 + r.normal() * 0.62, -2.6, 2.6)
  const one = <T>(p: readonly [T, T]): T => (r.chance(0.5) ? p[0] : p[1])
  const pick = <T>(m: readonly [T, T], f: readonly [T, T]): readonly [T, T] => [one(m), one(f)]
  const mut = (x: number, s = 0.04): number => clamp(x + r.normal() * s)
  const avg = (a: number, b: number): number => (a + b) / 2
  const mh = mother.hair, fh = father.hair
  return {
    version: 1,
    seed,
    sex,
    face,
    asymmetry: clamp(avg(mother.asymmetry, father.asymmetry) + r.normal() * 0.15, 0.02, 1.4),
    asymmetrySeed: Math.floor(r.next() * 1e9),
    skin: {
      melanin: pick(mother.skin.melanin, father.skin.melanin).map((x) => mut(x)) as unknown as Alleles,
      undertone: avg(mother.skin.undertone, father.skin.undertone) + r.normal() * 0.3,
      rosiness: mut(avg(mother.skin.rosiness, father.skin.rosiness), 0.08),
      freckles: pick(mother.skin.freckles, father.skin.freckles),
      quality: mut(avg(mother.skin.quality, father.skin.quality), 0.1),
      agingRate: clamp(avg(mother.skin.agingRate, father.skin.agingRate) + r.normal() * 0.08, 0.7, 1.4),
      moles: Math.floor(avg(mother.skin.moles, father.skin.moles) + r.next() * 3),
    },
    eyes: { darkness: pick(mother.eyes.darkness, father.eyes.darkness), green: pick(mother.eyes.green, father.eyes.green) },
    hair: {
      eumelanin: pick(mh.eumelanin, fh.eumelanin).map((x) => mut(x, 0.05)) as unknown as Alleles,
      red: pick(mh.red, fh.red),
      texture: pick(mh.texture, fh.texture),
      density: mut(avg(mh.density, fh.density), 0.06),
      greyOnset: clamp(avg(mh.greyOnset, fh.greyOnset) + r.normal() * 4, 22, 65),
      // calvície masculina: componente ligado ao X vem da mãe
      baldness: sex === "M" ? clamp(mh.baldness * 0.3 + (r.chance(0.5) ? 0.9 : 0.2) * r.next() + fh.baldness * 0.25) : clamp(r.next() * 0.2 - 0.08),
      baldOnset: clamp(avg(mh.baldOnset, fh.baldOnset) + r.normal() * 5, 19, 60),
      beardDensity: mut(avg(mh.beardDensity, fh.beardDensity), 0.1),
      beardRed: mut(avg(mh.beardRed, fh.beardRed), 0.05),
    },
    body: {
      fatTendency: mut(avg(mother.body.fatTendency, father.body.fatTendency), 0.1),
      heightZ: clamp(avg(mother.body.heightZ, father.body.heightZ) + r.normal() * 0.7, -2.6, 2.6),
    },
  }
}

export function defaultStyle(g: AppearanceGenome, rng?: SeededRandom): AppearanceStyle {
  const r = rng ?? seededRandom(hashText(g.seed + ":style"))
  const coily = hairTexture(g) > 2
  const pools = ADULT_HAIR_POOLS[g.sex]
  const female = g.sex === "F"
  return {
    hair: r.pick(coily ? pools.coily : pools.other),
    beard: female || r.chance(0.35) ? "nenhuma" : r.pick(BEARD_STYLES.slice(1)).id,
    glasses: r.chance(0.22) ? r.pick(GLASSES) : null,
    makeup: female ? clamp(r.next() * 1.2 - 0.2) : 0,
    shirt: r.pick(SHIRTS),
    shirtHue: r.next(),
    shirtTone: r.next(),
  }
}

export function createAppearance(seed: string, opts: GenomeOptions = {}): Appearance {
  const genome = createGenome(seed, opts)
  return { genome, style: defaultStyle(genome) }
}

export function inheritAppearance(mother: AppearanceGenome, father: AppearanceGenome, seed: string, opts: { sex?: Sex } = {}): Appearance {
  const genome = inheritGenome(mother, father, seed, opts)
  return { genome, style: defaultStyle(genome) }
}

// ---------- fenótipo expresso ----------
const avgPair = (p: Alleles): number => (p[0] + p[1]) / 2
/** escuro domina claro */
const dominantDark = (p: Alleles): number => Math.max(p[0], p[1]) * 0.78 + Math.min(p[0], p[1]) * 0.22

export const hairTexture = (g: AppearanceGenome): number => avgPair(g.hair.texture)

export type Phenotype = {
  melanin: number
  eyeDarkness: number
  eyeGreen: number
  hairEumelanin: number
  hairPheomelanin: number
  redHair: boolean
  texture: number
  freckles: number
  /** fração de fios brancos no cabelo e na barba */
  grey: number
  beardGrey: number
  /** 0..1 progressão da calvície */
  baldness: number
}

export function phenotype(g: AppearanceGenome, age: number): Phenotype {
  const redHair = g.hair.red[0] && g.hair.red[1]
  let eu = avgPair(g.hair.eumelanin)
  // cabelo claro de criança escurece até a adolescência
  const kidLight = (1 - smoothstep(1, 14, age)) * (1 - eu) * 0.55
  eu = clamp(eu - kidLight * (eu < 0.85 ? 1 : 0.2))
  const mel = avgPair(g.skin.melanin)
  const baldness = g.sex === "M"
    ? g.hair.baldness * smoothstep(g.hair.baldOnset, g.hair.baldOnset + 28, age)
    : g.hair.baldness * smoothstep(55, 90, age) * 0.6
  return {
    melanin: mel,
    eyeDarkness: dominantDark(g.eyes.darkness),
    eyeGreen: avgPair(g.eyes.green),
    hairEumelanin: eu,
    hairPheomelanin: redHair ? 0.85 : 0.18 + (1 - eu) * 0.2,
    redHair,
    texture: hairTexture(g),
    freckles: Math.max(g.skin.freckles[0], g.skin.freckles[1]) * (redHair ? 1.4 : 1) + (mel < 0.2 && redHair ? 0.3 : 0),
    grey: smoothstep(g.hair.greyOnset, g.hair.greyOnset + 32, age),
    beardGrey: smoothstep(g.hair.greyOnset - 6, g.hair.greyOnset + 24, age),
    baldness,
  }
}

/** Corte apropriado para a idade: bebês têm penugem, crianças usam cortes infantis. */
export function hairStyleForAge(g: AppearanceGenome, style: AppearanceStyle, age: number): HairStyleId {
  if (age < 1.2) return "bebe"
  if (age < 11) {
    const r = seededRandom(hashText(g.seed + ":kid"))
    const pools = CHILD_HAIR_POOLS[g.sex]
    return r.pick(hairTexture(g) > 2 ? pools.coily : pools.other)
  }
  return style.hair
}

/** Gordura corporal atual: tendência genética + fase da vida. */
export function bodyFatAt(g: AppearanceGenome, age: number): number {
  const babyFat = (1 - smoothstep(0, 5, age)) * 0.35
  const midlife = smoothstep(25, 55, age) * 0.15
  return clamp(g.body.fatTendency + babyFat + midlife - smoothstep(80, 100, age) * 0.12)
}

/** Altura em cm, com curva de crescimento aproximada e perda na velhice. */
export function heightCm(g: AppearanceGenome, age: number): number {
  const adult = (g.sex === "F" ? 162 : 175) + g.body.heightZ * 7
  const curve: readonly (readonly [number, number])[] = [[0, 0.29], [1, 0.43], [2, 0.5], [5, 0.62], [10, 0.79], [13, 0.88], [16, 0.97], [19, 1]]
  let f = 1
  for (let i = 1; i < curve.length; i++) {
    const [a0, f0] = curve[i - 1] as readonly [number, number]
    const [a1, f1] = curve[i] as readonly [number, number]
    if (age <= a1) {
      f = lerp(f0, f1, (age - a0) / (a1 - a0))
      break
    }
  }
  return adult * f - smoothstep(60, 100, age) * 5
}
