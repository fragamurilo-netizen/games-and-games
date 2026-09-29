import { contactAvailability } from "../commands"
import type { WorldState } from "../domain/world"
import { ageAt, formatDate, formatTime } from "../time"
import { absoluteMinute } from "../time"
import { courses, jobRoles } from "@paralelo/content"
import { applicationReason, nextWorkTime, workReason } from "../systems/career"
import { formatMoney } from "../systems/finance"

// Read model novo a cada consulta; nada retornado compartilha objetos mutáveis do mundo.
export function queryLife(world: WorldState) {
  const player = world.people[world.playerId]!
  return {
    name: player.name, age: ageAt(player.birthDate, world.clock), city: world.city,
    date: formatDate(world.clock), time: formatTime(world.clock),
    energy: player.needs.energy < 20 ? "Você precisa descansar." : player.needs.energy < 50 ? "O cansaço começa a pesar." : "Você ainda tem disposição.",
    stress: player.needs.stress > 65 ? "Está difícil desligar a cabeça." : "A mudança ainda ocupa seus pensamentos.",
    timeline: world.timeline.slice(-80).reverse().map(entry => ({ id: entry.id, date: formatDate(entry.at), time: formatTime(entry.at), text: entry.text, kind: entry.kind })),
    people: Object.values(world.relationships).filter(r => r.a === player.id || r.b === player.id).map(r => {
      const person = world.people[r.a === player.id ? r.b : r.a]!
      const unavailable = contactAvailability(world, person.id)
      return { id: person.id, name: person.name, age: ageAt(person.birthDate, world.clock),
        description: r.tags.includes("family") ? "Sua mãe" : "Amizade de antes da mudança",
        state: r.lastInteractionAt ? "Vocês tiveram contato recentemente." : r.trust > 65 ? "Existe confiança entre vocês." : "Vocês ainda têm muito para conversar.",
        canContact: !unavailable, unavailableReason: unavailable?.message ?? null,
        memories: world.memories.filter(memory => memory.personId === person.id && memory.salience > .1).slice(-3).reverse().map(memory => ({ id: memory.id, text: memory.text, date: formatDate(memory.at) })) }
    }),
    agenda: [...world.scheduled].map(item => ({ id: item.id, date: formatDate(item.at), time: formatTime(item.at), label: item.kind === "mother-message" ? "Mensagem da família" : item.kind === "monthly-finance" ? "Pagamento e aluguel" : "Rotina das pessoas próximas" })),
  }
}

export function queryCareer(world: WorldState) {
  const role = jobRoles.find(item => item.id === world.employment?.roleId)
  const next = nextWorkTime(world)
  const waitMinutes = absoluteMinute(next) - absoluteMinute(world.clock)
  const unavailable = workReason(world)
  return {
    employment: world.employment && role ? { company: world.companies[world.employment.companyId]!.name, title: role.title,
      salary: formatMoney(role.salaryCents), accrued: formatMoney(world.employment.accruedCents), shifts: world.employment.shiftsWorked,
      started: formatDate(world.employment.startedAt), performance: world.employment.performance < 40 ? "O cansaço está afetando seu desempenho." : "Você está dando conta das tarefas." } : null,
    canWork: !unavailable, unavailableReason: unavailable,
    nextWork: { date: formatDate(next), time: formatTime(next), waitMinutes: Math.max(0, Math.min(10080, waitMinutes)) },
    vacancies: Object.values(world.vacancies).filter(v => v.open).map(v => {
      const definition = jobRoles.find(item => item.id === v.roleId)!
      const reason = applicationReason(world, v.id)
      return { id: v.id, title: definition.title, company: world.companies[v.companyId]!.name, salary: formatMoney(definition.salaryCents), canApply: !reason, reason,
        preparation: definition.skill === "organization" ? "Organização" : "Comunicação" }
    }),
    courses: courses.map(course => {
      const id = `course:${course.id}` as keyof WorldState["training"]
      const progress = world.training[id]!
      const reason = progress.sessions >= course.sessions ? "Curso concluído." : progress.lastStudiedDay === world.clock.day ? "A aula de hoje já foi feita." : world.finance.balanceCents < course.priceCents ? "Saldo insuficiente para a aula." : world.people[world.playerId]!.needs.energy < 15 ? "Descanse antes da aula." : null
      return { id, title: course.title, institution: course.institution, price: formatMoney(course.priceCents), progress: `${progress.sessions} de ${course.sessions} aulas`, canStudy: !reason, reason }
    }),
  }
}

export function queryMoney(world: WorldState) {
  return { balance: formatMoney(world.finance.balanceCents), negative: world.finance.balanceCents < 0,
    rent: formatMoney(world.finance.monthlyRentCents), accrued: formatMoney(world.employment?.accruedCents ?? 0),
    warning: world.finance.balanceCents < 0 ? "A conta ficou negativa. Os débitos continuam no extrato; receber salário ajuda a cobrir o saldo." : world.finance.balanceCents < world.finance.monthlyRentCents ? "O saldo disponível ainda não cobre o próximo aluguel." : "O próximo aluguel cabe no saldo disponível.",
    ledger: [...world.finance.ledger].reverse().slice(0, 100).map(entry => ({ id: entry.id, date: formatDate(entry.at), time: formatTime(entry.at), text: entry.text, amount: formatMoney(entry.amountCents), incoming: entry.amountCents > 0, cause: entry.cause })),
  }
}

export function queryWorld(world: WorldState) {
  const residence = world.residences[world.people[world.playerId]!.residenceId]!
  return { city: world.city, district: residence.district, population: Object.keys(world.people).length,
    companies: Object.values(world.companies).map(company => ({ id: company.id, name: company.name, district: company.district, vacancies: Object.values(world.vacancies).filter(v => v.open && v.companyId === company.id).length })),
    residents: Object.values(world.people).filter(person => world.tiers[person.id] === "background").map(person => ({ id: person.id, name: person.name, age: ageAt(person.birthDate, world.clock), district: world.residences[person.residenceId]!.district })),
    facts: world.timeline.filter(entry => ["career", "finance", "education"].includes(entry.kind)).slice(-12).reverse().map(entry => ({ id: entry.id, date: formatDate(entry.at), text: entry.text })),
  }
}
