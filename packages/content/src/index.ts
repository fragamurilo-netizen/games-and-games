// Conteúdo data-driven: eventos, empregos, cursos, traços, textos (bíblia §41).
// Conteúdo inicial da fundação, sem lógica de simulação.
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
