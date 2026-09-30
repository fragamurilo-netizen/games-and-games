// Corpo e aparência (bíblia §21): peso por balanço de energia, força e condicionamento por
// prática, cuidado pessoal e roupa do dia. Valores de jogo inspirados em fisiologia comum
// (Mifflin-St Jeor, ~7.700 kcal por kg); não são recomendação de saúde.

export const bodyRules = {
  kcalPerKg: 7700,
  /** gasto do dia a dia sem exercício, sobre o metabolismo basal */
  baseActivity: 1.3,
  dailyMinute: 180,
  /** a partir daqui a falta de treino começa a desfazer o ganho */
  detrainingDays: 14,
  weightLogWeeks: 26,
  /** calorias por ponto de fome saciado, quando a comida vem de uma escolha */
  kcalPerHunger: 15,
  gym: { priceCents: 8900, label: "Academia do bairro" },
  shiftKcal: { atendimento: 220, operacao: 380, escritorio: 90 } as Readonly<Record<string, number>>,
} as const

export type ExerciseKind = "walk" | "run" | "home" | "gym"
export const exercises: Readonly<Record<ExerciseKind, Readonly<{
  label: string; minutes: number; met: number; energy: number; stress: number
  /** ganho de condicionamento e de força por sessão, antes do retorno decrescente */
  fitness: number; strength: number; leanKg: number; needsGym?: boolean; minFitness?: number
}>>> = {
  walk: { label: "Caminhar pelo bairro", minutes: 45, met: 3.5, energy: -6, stress: -7, fitness: .012, strength: 0, leanKg: 0 },
  run: { label: "Correr", minutes: 40, met: 9, energy: -16, stress: -9, fitness: .025, strength: .003, leanKg: 0, minFitness: .15 },
  home: { label: "Treinar em casa", minutes: 40, met: 4.5, energy: -11, stress: -5, fitness: .006, strength: .012, leanKg: .02 },
  gym: { label: "Treinar na academia", minutes: 90, met: 5.5, energy: -15, stress: -6, fitness: .01, strength: .022, leanKg: .045, needsGym: true },
}

export const groomingRules = {
  shave: { label: "Fazer a barba", minutes: 15 },
  haircut: { label: "Cortar o cabelo", minutes: 60, priceCents: { F: 6000, M: 3500 } as Readonly<Record<"F" | "M", number>> },
  /** a partir daqui o cabelo pede corte */
  haircutDays: 45,
} as const

export const snack = { label: "Comer algo rápido na rua", minutes: 15, priceCents: 1400, kcal: 1100, hunger: -55, energy: 4, stress: -2 } as const

/** Catálogo de roupas (ids do renderizador). formalidade 0 casual · 1 arrumado · 2 social; calor −1 roupa fresca · 1 roupa quente. */
export const outfitCatalog: readonly Readonly<{ id: string; label: string; formality: 0 | 1 | 2; warmth: -1 | 0 | 1; sexes: readonly ("F" | "M")[]; priceCents: number }>[] = [
  { id: "casual", label: "Camiseta e jeans", formality: 0, warmth: 0, sexes: ["F", "M"], priceCents: 9000 },
  { id: "shorts", label: "Camiseta e bermuda", formality: 0, warmth: -1, sexes: ["F", "M"], priceCents: 7000 },
  { id: "tank", label: "Regata e calça", formality: 0, warmth: -1, sexes: ["F", "M"], priceCents: 6000 },
  { id: "sport", label: "Conjunto esportivo", formality: 0, warmth: 0, sexes: ["F", "M"], priceCents: 12000 },
  { id: "sweatshirt", label: "Moletom", formality: 0, warmth: 1, sexes: ["F", "M"], priceCents: 11000 },
  { id: "jacket", label: "Jaqueta e camiseta", formality: 0, warmth: 1, sexes: ["F", "M"], priceCents: 18000 },
  { id: "polo", label: "Polo e calça", formality: 1, warmth: 0, sexes: ["F", "M"], priceCents: 10000 },
  { id: "knit", label: "Suéter de tricô", formality: 1, warmth: 1, sexes: ["F", "M"], priceCents: 14000 },
  { id: "cardigan", label: "Cardigã", formality: 1, warmth: 1, sexes: ["F", "M"], priceCents: 13000 },
  { id: "linen", label: "Camisa de linho", formality: 1, warmth: -1, sexes: ["F", "M"], priceCents: 15000 },
  { id: "blouse", label: "Blusa com gola V", formality: 1, warmth: -1, sexes: ["F"], priceCents: 9000 },
  { id: "blouse34", label: "Blusa de manga ¾", formality: 1, warmth: 0, sexes: ["F"], priceCents: 10000 },
  { id: "skirt", label: "Blusa e saia", formality: 1, warmth: -1, sexes: ["F"], priceCents: 12000 },
  { id: "dress", label: "Vestido acinturado", formality: 1, warmth: -1, sexes: ["F"], priceCents: 16000 },
  { id: "tunic", label: "Túnica e calça", formality: 1, warmth: 0, sexes: ["F"], priceCents: 13000 },
  { id: "shirt", label: "Camisa social aberta", formality: 2, warmth: 0, sexes: ["F", "M"], priceCents: 14000 },
  { id: "formal", label: "Camisa e gravata", formality: 2, warmth: 0, sexes: ["M"], priceCents: 20000 },
  { id: "blazer", label: "Blazer e calça", formality: 2, warmth: 1, sexes: ["F", "M"], priceCents: 28000 },
  { id: "dresslong", label: "Vestido midi", formality: 2, warmth: -1, sexes: ["F"], priceCents: 22000 },
]

/** Formalidade que cada família de função espera no trabalho. */
export const dressCode: Readonly<Record<string, 0 | 1 | 2>> = { operacao: 0, atendimento: 1, escritorio: 2 }

/** Guarda-roupa inicial: o básico de quem acabou de se mudar. */
export const starterWardrobe: Readonly<Record<"F" | "M", readonly string[]>> = {
  F: ["casual", "shorts", "sweatshirt", "blouse", "polo"],
  M: ["casual", "shorts", "sweatshirt", "polo", "sport"],
}

export function validateBodyContent(): string[] {
  const errors: string[] = []
  const ids = new Set(outfitCatalog.map(o => o.id))
  if (ids.size !== outfitCatalog.length) errors.push("Roupa duplicada no catálogo.")
  for (const list of Object.values(starterWardrobe)) for (const id of list) if (!ids.has(id)) errors.push(`Guarda-roupa inicial com roupa inexistente: ${id}.`)
  for (const [sex, list] of Object.entries(starterWardrobe)) for (const id of list) if (!outfitCatalog.find(o => o.id === id)!.sexes.includes(sex as "F" | "M")) errors.push(`Roupa ${id} fora do guarda-roupa ${sex}.`)
  for (const e of Object.values(exercises)) if (e.minutes <= 0 || e.met <= 0) errors.push(`Exercício inválido: ${e.label}.`)
  return errors
}
