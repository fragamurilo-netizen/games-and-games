// Catálogo de estilos de aparência. Só IDs e nomes: os parâmetros de desenho
// ficam em @paralelo/ui (portrait/styles.ts), que precisa cobrir todos estes IDs.

export const HAIR_STYLES = [
  { id: "raspado-zero", name: "Raspado na zero" },
  { id: "maquina-2", name: "Máquina 2" },
  { id: "militar", name: "Corte militar" },
  { id: "social-curto", name: "Social curto" },
  { id: "risca-lado", name: "Risca lateral" },
  { id: "topete", name: "Topete" },
  { id: "pompadour", name: "Pompadour" },
  { id: "cesar", name: "Corte César" },
  { id: "crop-texturizado", name: "Crop texturizado" },
  { id: "degrade-navalhado", name: "Degradê navalhado" },
  { id: "flat-top", name: "Flat top" },
  { id: "espetado", name: "Espetado" },
  { id: "lambido", name: "Penteado para trás" },
  { id: "moicano", name: "Moicano" },
  { id: "undercut", name: "Undercut" },
  { id: "cacheado-curto", name: "Cacheado curto" },
  { id: "black-power-curto", name: "Black curto" },
  { id: "twists-curtos", name: "Twists curtos" },
  { id: "pixie", name: "Pixie" },
  { id: "joaozinho", name: "Joãozinho" },
  { id: "tigela", name: "Tigela" },
  { id: "cortina", name: "Franja cortina (anos 90)" },
  { id: "chanel", name: "Chanel" },
  { id: "chanel-franja", name: "Chanel com franja" },
  { id: "long-bob", name: "Long bob" },
  { id: "shag", name: "Shag repicado" },
  { id: "mullet", name: "Mullet" },
  { id: "surfista", name: "Surfista" },
  { id: "medio-cacheado", name: "Médio cacheado" },
  { id: "atras-orelha", name: "Médio atrás da orelha" },
  { id: "longo-liso", name: "Longo liso" },
  { id: "longo-repartido", name: "Longo repartido ao meio" },
  { id: "longo-ondulado", name: "Longo ondulado" },
  { id: "longo-franja", name: "Longo com franja" },
  { id: "longo-camadas", name: "Longo em camadas" },
  { id: "longo-cacheado", name: "Longo cacheado" },
  { id: "muito-longo", name: "Muito longo" },
  { id: "longo-de-lado", name: "Longo solto de lado" },
  { id: "black-power", name: "Black power" },
  { id: "black-power-grande", name: "Black power volumoso" },
  { id: "dreads-curtos", name: "Dreads curtos" },
  { id: "dreads-longos", name: "Dreads longos" },
  { id: "trancas-nago", name: "Tranças nagô" },
  { id: "box-braids", name: "Box braids" },
  { id: "rabo-de-cavalo", name: "Rabo de cavalo" },
  { id: "rabo-baixo", name: "Rabo baixo" },
  { id: "coque-alto", name: "Coque alto" },
  { id: "coque-baixo", name: "Coque baixo" },
  { id: "coque-baguncado", name: "Coque bagunçado" },
  { id: "coque-masculino", name: "Coque masculino (man bun)" },
  { id: "meio-preso", name: "Meio preso" },
  { id: "maria-chiquinha", name: "Maria-chiquinha" },
  { id: "duas-trancas", name: "Duas tranças" },
  { id: "tranca-lateral", name: "Trança lateral" },
  { id: "puffs", name: "Dois puffs" },
  { id: "afro-puff", name: "Afro puff alto" },
  { id: "calvo", name: "Calvo (natural)" },
  { id: "coroa-rala", name: "Coroa rala" },
  { id: "bebe", name: "Penugem de bebê" },
  { id: "infantil-franjinha", name: "Franjinha infantil" },
  { id: "infantil-arrepiado", name: "Arrepiado infantil" },
] as const

export const BEARD_STYLES = [
  { id: "nenhuma", name: "Barbeado" },
  { id: "sombra", name: "Sombra (5 da tarde)" },
  { id: "por-fazer", name: "Barba por fazer" },
  { id: "rala-jovem", name: "Rala (jovem)" },
  { id: "curta", name: "Barba curta" },
  { id: "cheia", name: "Barba cheia" },
  { id: "longa", name: "Barba longa" },
  { id: "mago", name: "Barba de mago" },
  { id: "lenhador", name: "Lenhador (Bandholz)" },
  { id: "garibaldi", name: "Garibaldi" },
  { id: "verdi", name: "Verdi" },
  { id: "ducktail", name: "Ducktail" },
  { id: "quadrada", name: "Quadrada aparada" },
  { id: "cavanhaque", name: "Cavanhaque" },
  { id: "cavanhaque-longo", name: "Cavanhaque longo" },
  { id: "barbicha", name: "Barbicha (só queixo)" },
  { id: "van-dyke", name: "Van Dyke" },
  { id: "balbo", name: "Balbo" },
  { id: "ancora", name: "Âncora" },
  { id: "circular", name: "Circular" },
  { id: "mosca", name: "Mosca (soul patch)" },
  { id: "queixeira", name: "Queixeira (chin strap)" },
  { id: "amish", name: "Barba sem bigode (Amish)" },
  { id: "costeletas", name: "Costeletas longas" },
  { id: "suicas", name: "Suíças (mutton chops)" },
  { id: "suicas-bigode", name: "Suíças com bigode" },
  { id: "bigode", name: "Bigode clássico" },
  { id: "bigode-lapis", name: "Bigode lápis" },
  { id: "bigode-chevron", name: "Bigode chevron" },
  { id: "bigode-guidao", name: "Bigode guidão" },
  { id: "bigode-ferradura", name: "Bigode ferradura" },
  { id: "bigode-morsa", name: "Bigode morsa" },
  { id: "fu-manchu", name: "Fu Manchu" },
  { id: "bigode-ingles", name: "Bigode inglês" },
  { id: "bigode-barba-rala", name: "Bigode e barba por fazer" },
  { id: "penugem", name: "Penugem de adolescente" },
] as const

export type HairStyleId = (typeof HAIR_STYLES)[number]["id"]
export type BeardStyleId = (typeof BEARD_STYLES)[number]["id"]

export const GLASSES = ["redondo", "retangular", "gatinho", "aviador", "grosso"] as const
export type GlassesId = (typeof GLASSES)[number]

export const SHIRTS = ["gola-redonda", "gola-polo", "decote-v", "sueter", "regata"] as const
export type ShirtKind = (typeof SHIRTS)[number]

const HAIR_IDS: ReadonlySet<string> = new Set(HAIR_STYLES.map((s) => s.id))
const BEARD_IDS: ReadonlySet<string> = new Set(BEARD_STYLES.map((s) => s.id))
export const isHairStyleId = (id: string): id is HairStyleId => HAIR_IDS.has(id)
export const isBeardStyleId = (id: string): id is BeardStyleId => BEARD_IDS.has(id)

export const hairName = (id: HairStyleId): string => HAIR_STYLES.find((s) => s.id === id)?.name ?? id
export const beardName = (id: BeardStyleId): string => BEARD_STYLES.find((s) => s.id === id)?.name ?? id

// Estilos que uma pessoa escolhe como adulta, conforme sexo e textura do cabelo.
export const ADULT_HAIR_POOLS: Record<"F" | "M", { coily: readonly HairStyleId[]; other: readonly HairStyleId[] }> = {
  F: {
    coily: ["black-power", "black-power-grande", "box-braids", "puffs", "afro-puff", "longo-cacheado", "trancas-nago", "twists-curtos", "dreads-longos", "medio-cacheado", "coque-alto"],
    other: ["longo-liso", "longo-ondulado", "longo-franja", "longo-camadas", "chanel", "chanel-franja", "long-bob", "shag", "rabo-de-cavalo", "coque-alto", "coque-baixo", "coque-baguncado", "meio-preso", "pixie", "tranca-lateral", "longo-repartido", "muito-longo", "medio-cacheado"],
  },
  M: {
    coily: ["black-power-curto", "maquina-2", "degrade-navalhado", "twists-curtos", "dreads-curtos", "dreads-longos", "black-power", "raspado-zero", "trancas-nago", "flat-top"],
    other: ["social-curto", "risca-lado", "topete", "militar", "crop-texturizado", "degrade-navalhado", "undercut", "espetado", "lambido", "cesar", "surfista", "cortina", "atras-orelha", "coque-masculino", "maquina-2", "mullet", "pompadour", "longo-liso", "cacheado-curto"],
  },
}

export const CHILD_HAIR_POOLS: Record<"F" | "M", { coily: readonly HairStyleId[]; other: readonly HairStyleId[] }> = {
  F: {
    coily: ["puffs", "maria-chiquinha", "duas-trancas", "trancas-nago", "afro-puff"],
    other: ["maria-chiquinha", "duas-trancas", "chanel-franja", "rabo-de-cavalo", "longo-liso", "infantil-franjinha"],
  },
  M: {
    coily: ["black-power-curto", "maquina-2", "twists-curtos"],
    other: ["infantil-franjinha", "infantil-arrepiado", "tigela", "social-curto", "maquina-2"],
  },
}
