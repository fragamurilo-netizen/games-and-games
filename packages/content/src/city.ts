// Textos do mundo vivo: mensagens de pessoas e manchetes da cidade (bíblia §12, §20, §26).
// Placeholders: {name} {first} {company} {role} {district}. Sem marcas de gênero, frases curtas,
// comprimentos variados. Cada situação tem variantes para não soar repetida (§26.6).

export const cityRules = {
  /** fração inicial de adultos (18–64) com emprego */
  employedShare: 0.72,
  /** fração de adultos que o mercado sustenta com empresas em saúde média */
  employedTarget: 0.93,
  /** chance semanal de alguém deixar o emprego por conta própria */
  weeklyTurnover: 0.01,
  /** quantas pessoas da vizinhança passam a fazer parte do círculo do jogador */
  neighbors: 7,
  messageHours: 24,
  weeklyEconomyMinute: 420,
  dailyCityMinute: 750,
  newsLimit: 80,
  inboxLimit: 60,
  referralBonus: 0.25,
} as const

export const messageTexts = {
  checkin: {
    family: [
      "Comeu direito hoje?",
      "Me conta como foi a semana quando puder.",
      "Liguei mais cedo e caiu na caixa. Tá tudo bem por aí?",
      "Separei umas coisas suas que ficaram aqui. Quando vier, leva.",
    ],
    friend: [
      "Sumiu, hein. Tudo certo aí?",
      "Tô passando perto da {district} amanhã. Café?",
      "Lembrei de você hoje. Como tá a casa nova?",
      "Vi uma coisa que era a sua cara. Depois te mostro.",
      "Bora marcar alguma coisa no fim de semana?",
    ],
    neighbor: [
      "Oi, aqui é {first}, do prédio. Chegou uma encomenda sua na portaria.",
      "Vou fazer bolo no domingo. Se quiser, passa aqui.",
      "A água vai ser cortada amanhã de manhã, avisaram na portaria.",
      "Oi! Tem uma escada pra emprestar? A minha quebrou.",
    ],
    coworker: [
      "Amanhã chega mais cedo? Vão mudar a escala.",
      "Deixaram um recado pra você na recepção.",
      "Sobrou bolo do aniversário do pessoal. Guardei um pedaço.",
    ],
  },
  hired: [
    "Consegui! Começo na {company} semana que vem.",
    "Fechei como {role} na {company}. Nem acredito.",
    "Adivinha quem tem emprego novo? {company}.",
  ],
  dismissed: [
    "A {company} me dispensou hoje. Ainda tô digerindo.",
    "Cortaram gente na {company}. Eu tava na lista.",
    "Fiquei sem o trabalho na {company}. Depois te conto direito.",
  ],
  jobTip: [
    "Abriu vaga de {role} aqui na {company}. Se quiser, falo de você.",
    "Tão procurando {role} na {company}. Posso te indicar.",
    "Lembrei de você: a {company} precisa de {role}. Topa que eu te indique?",
  ],
  worry: [
    "Clima estranho na {company}. Falaram em corte.",
    "A {company} perdeu um cliente grande. O pessoal tá com medo.",
    "Reunião fechada hoje na {company}. Ninguém explicou nada.",
  ],
} as const

export const replyTexts = {
  answer: {
    checkin: "Você respondeu {first}. A conversa rendeu mais do que parecia.",
    hired: "Você mandou parabéns para {first}, que respondeu com três exclamações.",
    dismissed: "Você mandou apoio para {first} e se ofereceu para ajudar a procurar outra vaga.",
    jobTip: "Você pediu para {first} te indicar na {company}. A indicação fica valendo para essa vaga.",
    worry: "Você ouviu {first} falar do clima na {company}.",
  },
  call: "Você ligou para {first}. Vocês falaram sem pressa.",
  later: "Você deixou para responder {first} mais tarde.",
  ignored: "A mensagem de {first} ficou sem resposta.",
} as const

export const newsTexts = {
  hire: [
    { headline: "{company} contrata {role}", body: "{name} começa na {company} nesta semana." },
    { headline: "Vaga preenchida na {company}", body: "A empresa confirmou {name} como {role}." },
  ],
  opening: [
    { headline: "{company} abre vaga de {role}", body: "Com mais movimento, a empresa procura quem comece logo." },
    { headline: "{company} amplia equipe", body: "A procura é por {role}. O anúncio saiu na vitrine." },
  ],
  replacement: [
    { headline: "{company} procura substituto", body: "{name} deixou a empresa. A vaga de {role} está aberta." },
  ],
  freeze: [
    { headline: "{company} suspende contratação", body: "A vaga de {role} foi retirada enquanto a empresa revê custos." },
  ],
  weak: [
    { headline: "Movimento cai na {company}", body: "Funcionários relatam semanas fracas e pedidos cancelados." },
    { headline: "{company} enfrenta semanas difíceis", body: "A empresa renegocia contas com fornecedores da {district}." },
  ],
  recovery: [
    { headline: "{company} volta a crescer", body: "O movimento melhorou e a empresa voltou a contratar." },
  ],
  layoff: [
    { headline: "{company} corta posto de {role}", body: "Depois de semanas de queda, a empresa dispensou {name}." },
    { headline: "Demissão na {company}", body: "Em corte de custos, a empresa encerrou o contrato de {name}, que trabalhava como {role}." },
  ],
} as const

/** Gênero gramatical de lugares e empresas: decide "na Padaria" ou "no Hotel" (bíblia §32). */
export const placeGender: Readonly<Record<string, "a" | "o">> = {
  "Mercado do Bairro": "o", "Padaria Aurora": "a", "Clínica São Bento": "a", "Oficina Central": "a", "Livraria Travessa": "a",
  "Logística Horizonte": "a", "Café da Praça": "o", "Escritório Mendonça": "o", "Hotel Primavera": "o", "Tecidos Flores": "a",
  "Centro": "o", "Vila das Flores": "a",
}
const MASCULINE: Readonly<Record<string, string>> = { na: "no", a: "o", da: "do", pela: "pelo" }
/** "na Vila das Flores", "no Centro". */
export const inPlace = (name: string): string => `${placeGender[name] === "o" ? "no" : "na"} ${name}`

const PLACEHOLDER = /\{([a-z]+)\}/g
// Concordância: os textos são escritos no feminino ("na {company}") e viram "no" quando o nome pede
const CONTRACTION = /(^|[^\p{L}])(na|Na|a|A|da|Da|pela|Pela) \{(company|district)\}/gu
const KNOWN = new Set(["name", "first", "company", "role", "district"])
export function validateCityContent(): string[] {
  const errors: string[] = []
  const walk = (value: unknown, path: string): void => {
    if (typeof value === "string") {
      for (const m of value.matchAll(PLACEHOLDER)) if (!KNOWN.has(m[1]!)) errors.push(`Placeholder desconhecido {${m[1]}} em ${path}.`)
      if (!value.trim()) errors.push(`Texto vazio em ${path}.`)
    } else if (Array.isArray(value)) {
      if (!value.length) errors.push(`Lista vazia em ${path}.`)
      value.forEach((v, i) => walk(v, `${path}[${i}]`))
    } else if (value && typeof value === "object") for (const [k, v] of Object.entries(value)) walk(v, `${path}.${k}`)
  }
  walk(messageTexts, "messageTexts")
  walk(replyTexts, "replyTexts")
  walk(newsTexts, "newsTexts")
  return errors
}

export function fillText(template: string, values: Readonly<Record<string, string | undefined>>): string {
  const agreed = template.replace(CONTRACTION, (all, before: string, word: string, key: "company" | "district") => {
    const name = values[key]
    if (!name || placeGender[name] !== "o") return all
    const lower = MASCULINE[word.toLowerCase()]!
    return `${before}${word[0] === word[0]!.toUpperCase() ? lower[0]!.toUpperCase() + lower.slice(1) : lower} {${key}}`
  })
  return agreed.replace(PLACEHOLDER, (_, key: string) => values[key as keyof typeof values] ?? `{${key}}`)
}
