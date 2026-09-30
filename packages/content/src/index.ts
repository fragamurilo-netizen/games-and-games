// Conteúdo data-driven: eventos, empregos, cursos, traços, textos (bíblia §41).
// Conteúdo inicial da fundação, sem lógica de simulação.
export * from "./events"
export * from "./routine"
export * from "./work"
export * from "./body"
export const starterContent = {
  city: "Santa Aurora",
  district: "Vila das Flores",
  playerNames: ["Alex Ferreira", "Joana Almeida", "Rafael Costa", "Marina Santos"],
  friendNames: ["Bia Ramos", "Caio Duarte", "Lia Nunes", "André Melo"],
  opening: "As caixas da mudança ainda estão no corredor. É sua primeira semana morando por conta própria.",
  motherName: "Helena Ferreira",
  reminder: "Sua mãe mandou uma mensagem: \"Quando der, me liga. Quero saber como foi o primeiro dia.\"",
} as const

export const cityNames = {
  first: ["Ana", "Bruno", "Carolina", "Daniel", "Elisa", "Felipe", "Gabriela", "Hugo", "Isabela", "João", "Karina", "Lucas", "Marta", "Nicolas", "Olívia", "Paulo", "Renata", "Samuel", "Teresa", "Vinícius"],
  last: ["Almeida", "Barros", "Campos", "Dias", "Esteves", "Freitas", "Gomes", "Henrique", "Lima", "Moraes", "Nunes", "Oliveira", "Pires", "Ramos", "Santos", "Teixeira", "Vieira", "Costa", "Duarte", "Melo"],
} as const
// Sexo usado pela aparência dos personagens criados a partir destas listas.
export const firstNameSex: Readonly<Record<string, "F" | "M">> = {
  Alex: "M", Joana: "F", Rafael: "M", Marina: "F", Helena: "F", Bia: "F", Caio: "M", Lia: "F", "André": "M",
  Ana: "F", Bruno: "M", Carolina: "F", Daniel: "M", Elisa: "F", Felipe: "M", Gabriela: "F", Hugo: "M", Isabela: "F", "João": "M",
  Karina: "F", Lucas: "M", Marta: "F", Nicolas: "M", "Olívia": "F", Paulo: "M", Renata: "F", Samuel: "M", Teresa: "F", "Vinícius": "M",
}

export const socialTexts = {
  family: [
    "{person} ligou para saber como você está. A conversa foi parar nas pequenas coisas da semana.",
    "{person} perguntou se você está conseguindo comer e descansar direito. Você contou como os dias têm sido.",
    "{person} puxou conversa sobre a casa e ouviu o que ainda falta resolver.",
    "{person} procurou você sem um assunto urgente. Vocês conversaram um pouco antes de voltar ao dia.",
  ],
  arrival: [
    "{person} perguntou das caixas da mudança. Você contou o que já conseguiu arrumar.",
    "{person} quis saber como é o bairro novo. Vocês conversaram sobre as ruas perto da sua casa.",
    "{person} mandou mensagem para saber se você já se sente em casa.",
    "{person} procurou você para saber como está sendo morar por conta própria.",
  ],
  employed: [
    "{person} perguntou como está o trabalho em {company}. Você contou um pouco da rotina.",
    "{person} quis saber se os turnos têm deixado algum tempo livre. Vocês falaram de como a semana mudou.",
    "{person} procurou você e a conversa acabou passando pelo expediente de hoje.",
    "{person} perguntou se você está conseguindo separar o trabalho do resto da vida.",
  ],
  everyday: [
    "{person} perguntou como foi sua semana. Vocês acabaram conversando mais do que esperavam.",
    "{person} procurou você no fim da tarde. Não havia nada urgente; só fazia um tempo que não se falavam.",
    "{person} mandou mensagem perguntando da casa. Você contou uma coisa pequena do dia.",
    "{person} puxou conversa para saber como você está levando a rotina.",
  ],
} as const
export const companies = ["Mercado do Bairro", "Padaria Aurora", "Clínica São Bento", "Oficina Central", "Livraria Travessa", "Logística Horizonte", "Café da Praça", "Escritório Mendonça", "Hotel Primavera", "Tecidos Flores"] as const
export const jobRoles = [
  { id: "stock", title: "Auxiliar de estoque", salaryCents: 180000, skill: "organization", required: .1 },
  { id: "counter", title: "Atendente de balcão", salaryCents: 190000, skill: "communication", required: .1 },
  { id: "reception", title: "Recepcionista", salaryCents: 220000, skill: "communication", required: .25 },
  { id: "assistant", title: "Auxiliar administrativo", salaryCents: 240000, skill: "organization", required: .3 },
  { id: "sales", title: "Assistente de vendas", salaryCents: 210000, skill: "communication", required: .2 },
  { id: "dispatch", title: "Auxiliar de expedição", salaryCents: 200000, skill: "organization", required: .15 },
  { id: "barista", title: "Atendente de café", salaryCents: 200000, skill: "communication", required: .15 },
  { id: "office", title: "Assistente de escritório", salaryCents: 260000, skill: "organization", required: .4 },
  { id: "hotel", title: "Assistente de hospedagem", salaryCents: 230000, skill: "communication", required: .3 },
  { id: "inventory", title: "Assistente de inventário", salaryCents: 250000, skill: "organization", required: .35 },
  { id: "accounts", title: "Assistente financeiro", salaryCents: 310000, skill: "organization", required: .6 },
  { id: "support", title: "Atendimento ao cliente", salaryCents: 280000, skill: "communication", required: .5 },
] as const
export const courses = [
  { id: "office", title: "Organização de escritório", institution: "Centro Comunitário Vila das Flores", skill: "organization", priceCents: 1200, sessions: 10 },
  { id: "communication", title: "Comunicação no trabalho", institution: "Escola Municipal de Formação", skill: "communication", priceCents: 1000, sessions: 10 },
  { id: "service", title: "Atendimento e escuta", institution: "Instituto Aurora", skill: "communication", priceCents: 1600, sessions: 12 },
] as const

export function validateStarterContent(): readonly string[] {
  const errors: string[] = []
  for (const list of [jobRoles, courses]) {
    if (new Set(list.map(item => item.id)).size !== list.length) errors.push("IDs duplicados no conteúdo.")
  }
  for (const role of jobRoles) if (!Number.isSafeInteger(role.salaryCents) || role.salaryCents <= 0 || role.required < 0 || role.required > 1) errors.push(`Função inválida: ${role.id}.`)
  for (const course of courses) if (!Number.isSafeInteger(course.priceCents) || course.priceCents <= 0 || !Number.isSafeInteger(course.sessions) || course.sessions <= 0) errors.push(`Curso inválido: ${course.id}.`)
  return errors
}
export * from "./city"
