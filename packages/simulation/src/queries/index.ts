import { contactAvailability } from "../commands"
import type { CompanyId, PersonId } from "@paralelo/shared"
import type { MessageReply, MessageTopic, WorldState } from "../domain/world"
import { replyReason } from "../systems/city"
import { competitionFor, familyOf, internalApplicationReason, interviewChoices, prepareReason, promotionGaps, reviewChoices, reviewEvaluation, riskOf, sceneValues } from "../systems/work"
import { entryWeight, summarizeRoutine, weightRank } from "../timeline"
import { ageAt, calendarDate, formatDate, formatDayHeading, formatTime, relativeDay } from "../time"
import { absoluteMinute } from "../time"
import { courses, fillText, inPlace, interviewTexts, jobRoles, roleCareer, routineRules, workRules, workSituations } from "@paralelo/content"
import { applicationReason, nextWorkTime, workReason } from "../systems/career"
import { formatMoney } from "../systems/finance"
import { groceriesReason, mealReason, type MealSource } from "../systems/routine"

// Resumo do corpo em linguagem: só o que pede atenção entra (bíblia §2.3, §32).
function bodySummary(needs: WorldState["people"][string]["needs"], minute: number): string {
  const parts: string[] = []
  if (needs.energy < 20) parts.push("O corpo pede descanso.")
  else if (needs.energy < 50) parts.push("O cansaço já pesa.")
  if (needs.hunger >= 75) parts.push("A fome tira a concentração.")
  else if (needs.hunger >= 45) parts.push("Já dá fome.")
  if (needs.sleepPressure >= 80) parts.push("O sono atrasado pesa nos olhos.")
  else if (needs.sleepPressure >= 55) parts.push("Bate um sono.")
  if (needs.stress > 65) parts.push("A cabeça não desliga.")
  if (parts.length) return parts.join(" ")
  return minute < 720 ? "Energia em dia e nenhuma fome. O dia está pela frente." : minute < 1080 ? "Tudo em ordem por enquanto." : "O dia foi tranquilo até aqui."
}

/** Expressão do personagem a partir do estado do corpo (sem expor números). */
function expressionFor(needs: WorldState["people"][string]["needs"]): "tired" | "tense" | "warm" | "neutral" {
  if (needs.energy < 30 || needs.sleepPressure >= 70) return "tired"
  if (needs.stress > 60 || needs.hunger >= 75) return "tense"
  if (needs.energy >= 55 && needs.stress < 35 && needs.hunger < 45) return "warm"
  return "neutral"
}
const MARK_LABELS: Partial<Record<WorldState["scheduled"][number]["kind"], string>> = {
  "work-reminder": "Turno", "work-attendance": "Limite do turno", "monthly-finance": "Aluguel e salário", "mother-message": "Mensagem", interview: "Entrevista",
}

/** O que aconteceu entre você e a pessoa, dos fatos que pesam (bíblia §6.4). */
function personHistory(world: WorldState, id: PersonId) {
  const shared = world.timeline.filter(e => e.personIds.includes(id))
  const talks = shared.filter(e => e.kind === "relationship" && entryWeight(e) === "cotidiano").length
  const moments = shared.filter(e => weightRank(entryWeight(e)) >= weightRank("relevante")).slice(-5).reverse()
    .map(e => ({ id: e.id, date: formatDate(e.at), text: e.text }))
  return { talks: talks === 0 ? "Nenhuma conversa no último ano." : talks === 1 ? "Uma conversa no último ano." : `${talks} conversas no último ano.`, moments }
}

/** O que a pessoa faz da vida, do jeito que o jogador saberia (bíblia §11.4). */
function workLine(world: WorldState, id: PersonId): string | null {
  const resident = world.residents[id]
  if (!resident) return null
  if (resident.job) {
    const role = jobRoles.find(item => item.id === resident.job!.roleId)
    return `${role?.title ?? "Trabalha"} ${inPlace(world.companies[resident.job.companyId]!.name)}`
  }
  const age = ageAt(world.people[id]!.birthDate, world.clock)
  if (age >= 65) return "Já se aposentou"
  if (age < 18) return "Ainda estuda"
  return resident.goal?.kind === "find-job" ? "Procurando trabalho" : "Sem emprego fixo"
}

const REPLY_META: Record<MessageReply, string> = { answer: "15 min", call: "30 min", later: "adia 24 h" }
const REPLY_LABEL: Record<MessageTopic, string> = { checkin: "Responder", hired: "Dar parabéns", dismissed: "Mandar apoio", "job-tip": "Pedir a indicação", worry: "Perguntar como está" }

/** Mensagens que ainda esperam resposta, com o prazo dito em horas (bíblia §12.2: silêncio também é ação). */
export function queryInbox(world: WorldState) {
  const now = absoluteMinute(world.clock)
  return world.inbox.filter(m => m.status === "unread" && absoluteMinute(m.expiresAt) > now).slice().reverse().map(m => {
    const from = world.people[m.fromId]!
    const hoursLeft = Math.max(1, Math.ceil((absoluteMinute(m.expiresAt) - now) / 60))
    const callBlocked = contactAvailability(world, m.fromId)
    return { id: m.id, from: { id: from.id, name: from.name, age: ageAt(from.birthDate, world.clock), appearance: { seed: from.appearanceSeed, sex: from.sex } },
      text: m.text, time: formatTime(m.at), day: relativeDay(m.at, world.clock),
      deadline: hoursLeft <= 3 ? "A mensagem está esfriando." : `Sem resposta, ela esfria em ${hoursLeft} h.`, urgent: hoursLeft <= 3,
      replies: (["answer", "call", "later"] as const).map(reply => {
        const reason = replyReason(world, m.id, reply) ?? (reply === "call" ? callBlocked?.message ?? null : null)
        return { reply, label: reply === "answer" ? REPLY_LABEL[m.topic] : reply === "call" ? "Ligar" : "Depois", meta: REPLY_META[reply], canReply: !reason, reason }
      }) }
  })
}

/**
 * Timeline por dia (bíblia §6.2–6.3): hoje aparece inteiro; nos dias anteriores a rotina vira
 * uma frase feita dos fatos do dia e só o que pesa aparece em linha própria.
 */
function timelineDays(world: WorldState, limit = 10) {
  const groups: { key: number; entries: WorldState["timeline"][number][] }[] = []
  for (let i = world.timeline.length - 1; i >= 0 && groups.length <= limit; i--) {
    const entry = world.timeline[i]!
    const last = groups.at(-1)
    if (last && last.key === entry.at.day) last.entries.push(entry)
    else groups.push({ key: entry.at.day, entries: [entry] })
  }
  return groups.slice(0, limit).map(group => {
    const today = group.key === world.clock.day
    const shown = today ? group.entries : group.entries.filter(e => weightRank(entryWeight(e)) >= weightRank("relevante"))
    const rest = today ? [] : group.entries.filter(e => weightRank(entryWeight(e)) < weightRank("relevante"))
    return { day: relativeDay(group.entries[0]!.at, world.clock), summary: rest.length ? summarizeRoutine(world, [...rest].reverse()) : null,
      entries: shown.map(entry => ({ id: entry.id, time: formatTime(entry.at), text: entry.text, kind: entry.kind, weight: entryWeight(entry) })) }
  })
}

/** O que aconteceu desde um instante: o fato de maior peso e o resumo da rotina (bíblia §6.3, §33). */
export function queryPeriod(world: WorldState, fromMinute: number) {
  const entries = world.timeline.filter(e => absoluteMinute(e.at) >= fromMinute)
  const top = [...entries].sort((a, b) => weightRank(entryWeight(b)) - weightRank(entryWeight(a)) || absoluteMinute(b.at) - absoluteMinute(a.at))[0] ?? null
  const minutes = absoluteMinute(world.clock) - fromMinute
  const days = Math.floor((minutes + 60) / 1440)
  const span = days >= 2 ? `${["", "", "Dois", "Três", "Quatro", "Cinco", "Seis", "Sete"][days] ?? days} dias depois.` : days === 1 ? "Um dia depois." : minutes >= 120 ? `${Math.round(minutes / 60)} horas depois.` : minutes >= 60 ? "Uma hora depois." : null
  return { span, count: entries.length, top: top && weightRank(entryWeight(top)) >= weightRank("relevante") ? { time: formatTime(top.at), text: top.text } : null,
    routine: summarizeRoutine(world, entries), minutes }
}

// Read model novo a cada consulta; nada retornado compartilha objetos mutáveis do mundo.
export function queryLife(world: WorldState) {
  const player = world.people[world.playerId]!
  return {
    name: player.name, age: ageAt(player.birthDate, world.clock), city: world.city,
    appearance: { seed: player.appearanceSeed, sex: player.sex }, body: bodySummary(player.needs, world.clock.minute),
    minute: world.clock.minute, dayNumber: world.clock.day + 1, expression: expressionFor(player.needs),
    marks: world.scheduled.filter(item => item.at.day === world.clock.day && MARK_LABELS[item.kind]).map(item => ({ id: item.id, minute: item.at.minute, label: MARK_LABELS[item.kind]! })),
    date: formatDate(world.clock), time: formatTime(world.clock), dayTitle: formatDayHeading(world.clock), year: formatDate(world.clock).slice(-4),
    energy: player.needs.energy < 20 ? "Você precisa descansar." : player.needs.energy < 50 ? "O cansaço começa a pesar." : "Você ainda tem disposição.",
    stress: player.needs.stress > 65 ? "Está difícil desligar a cabeça." : player.needs.stress < 20 ? "Hoje a cabeça está mais tranquila." : "Você está conseguindo lidar com as preocupações do dia.",
    hunger: player.needs.hunger >= 75 ? "A fome está tirando sua disposição. Reserve tempo para comer." : player.needs.hunger >= 45 ? "Já está na hora de pensar na próxima refeição." : "Você está sem fome por enquanto.",
    sleep: player.needs.sleepPressure >= 80 ? "O sono acumulado está atrapalhando. Uma pausa não substitui dormir." : player.needs.sleepPressure >= 55 ? "Você começa a sentir sono." : "Você está conseguindo se manter desperto.",
    timeline: world.timeline.slice(-80).reverse().map(entry => ({ id: entry.id, date: formatDate(entry.at), day: relativeDay(entry.at, world.clock), time: formatTime(entry.at), text: entry.text, kind: entry.kind, weight: entryWeight(entry) })),
    days: timelineDays(world),
    inbox: queryInbox(world),
    people: Object.values(world.relationships).filter(r => r.a === player.id || r.b === player.id).map(r => {
      const person = world.people[r.a === player.id ? r.b : r.a]!
      const unavailable = contactAvailability(world, person.id)
      const tag = r.tags[0] ?? "friend"
      return { id: person.id, name: person.name, age: ageAt(person.birthDate, world.clock), appearance: { seed: person.appearanceSeed, sex: person.sex },
        group: tag, closeness: r.affection + r.trust + r.familiarity,
        description: tag === "family" ? "Sua mãe" : tag === "friend" ? "Amizade de antes da mudança" : tag === "neighbor" ? `Mora perto, ${inPlace(world.residences[person.residenceId]!.district)}` : "Colega de trabalho",
        work: workLine(world, person.id),
        since: tag === "family" ? "A vida inteira" : r.since ? `${tag === "neighbor" ? "Vizinhança desde" : "Vocês se conheceram em"} ${formatDate(r.since)}` : "Desde antes da mudança",
        history: personHistory(world, person.id),
        state: r.lastInteractionAt && absoluteMinute(world.clock) - absoluteMinute(r.lastInteractionAt) < 10080 ? "Vocês tiveram contato recentemente." : r.lastInteractionAt ? "Faz um tempo que vocês não se falam." : r.trust > 65 ? "Existe confiança entre vocês." : "Vocês ainda têm muito para conversar.",
        canContact: !unavailable, unavailableReason: unavailable?.message ?? null,
        memories: world.memories.filter(memory => memory.personId === person.id && memory.salience > .1).slice(-3).reverse().map(memory => ({ id: memory.id, text: memory.text, date: formatDate(memory.at) })) }
    }),
    agenda: world.scheduled.filter(item => item.kind === "work-attendance" || item.kind === "monthly-finance" || item.kind === "interview")
      .sort((a, b) => absoluteMinute(a.at) - absoluteMinute(b.at)).slice(0, 4).map(item => {
        const interview = item.kind === "interview" ? world.work.interviews.find(i => i.id === item.interviewId) : undefined
        return { id: item.id, date: formatDate(item.at),
          time: item.kind === "work-attendance" ? "Chegar até 8h30" : formatTime(item.at),
          label: interview ? `${interview.internal ? "Processo interno" : "Entrevista"} · ${world.companies[interview.companyId]!.name}`
            : item.kind === "work-attendance" && world.employment ? `Expediente · ${world.companies[world.employment.companyId]!.name}` : "Pagamento e aluguel" }
      }),
    work: world.employment ? { canWork: !workReason(world), reason: workReason(world), late: world.clock.minute > workRules.onTimeMinute } : null,
  }
}

const tenureText = (days: number): string => {
  if (days < 7) return days <= 1 ? "Começou agora" : `${days} dias de casa`
  if (days < 60) return `${Math.floor(days / 7)} ${Math.floor(days / 7) === 1 ? "semana" : "semanas"} de casa`
  const months = Math.floor(days / 30)
  return months < 12 ? `${months} meses de casa` : `${Math.floor(months / 12)} ${Math.floor(months / 12) === 1 ? "ano" : "anos"} e ${months % 12} ${months % 12 === 1 ? "mês" : "meses"} de casa`
}
const trustText = (trust: number): string => trust >= 80 ? "Confia no seu trabalho e já pede sua opinião." : trust >= 60 ? "A relação profissional é boa." : trust >= 40 ? "A relação é correta, mas ainda sem muita confiança." : "Tem cobrado de perto."

// CARREIRA (bíblia §61): empresa, função, gestor, situação, próximos dias e oportunidades.
export function queryCareer(world: WorldState) {
  const e = world.employment
  const role = jobRoles.find(item => item.id === e?.roleId)
  const next = nextWorkTime(world)
  const waitMinutes = absoluteMinute(next) - absoluteMinute(world.clock)
  const unavailable = workReason(world)
  const w = e?.workplace
  const manager = w ? world.people[w.managerId]! : null
  const situation: string[] = []
  if (e && w) {
    if (w.warnings) situation.push("Você está com uma advertência formal. Mais um mês ruim encerra o contrato.")
    if (e.performance < 40) situation.push("O trabalho caiu nas últimas semanas. Presença, preparo e descanso fazem diferença.")
    else if (e.performance >= 70) situation.push("Você está dando conta bem do que a função pede.")
    else situation.push("Você está dando conta das tarefas.")
    if (w.lateThisMonth >= 2) situation.push(`Neste mês você chegou depois do horário ${w.lateThisMonth} vezes.`)
    if (e.consecutiveAbsences === 2) situation.push("Duas faltas seguidas. Outra encerra o contrato.")
    else if (e.consecutiveAbsences === 1) situation.push("Há uma falta registrada. Comparecer ao próximo turno interrompe a sequência.")
    const mood = companyMood(world, e.companyId)
    if (mood.includes("corte") || mood.includes("fraco")) situation.push(`Na empresa: ${mood.charAt(0).toLowerCase()}${mood.slice(1)}`)
  }
  const agenda: { id: string; date: string; time: string; label: string; kind: "interview" | "review" | "assignment"; prepare: { interviewId: string | null; canPrepare: boolean; reason: string | null; prepared: boolean } | null }[] = []
  for (const i of world.work.interviews.filter(i => i.status === "scheduled")) {
    const reason = prepareReason(world, "interview", i.id)
    agenda.push({ id: i.id, date: formatDate(i.at), time: formatTime(i.at), kind: "interview", label: i.internal ? `Processo interno · ${jobRoles.find(r => r.id === i.roleId)!.title}` : `Entrevista · ${world.companies[i.companyId]!.name}`,
      prepare: { interviewId: i.id, canPrepare: !reason, reason: i.prepared ? null : reason, prepared: i.prepared } })
  }
  if (e && w) {
    const reason = prepareReason(world, "review")
    agenda.push({ id: "review", date: formatDate({ day: w.nextReviewDay, minute: 0 }), time: "fim do turno", kind: "review", label: `Conversa do mês com ${manager!.name.split(" ")[0]}`,
      prepare: { interviewId: null, canPrepare: !reason, reason: w.prepared ? null : reason, prepared: w.prepared } })
    if (w.assignment) agenda.push({ id: "assignment", date: formatDate({ day: w.assignment.dueDay, minute: 0 }), time: "prazo", kind: "assignment",
      label: `Entrega: ${w.assignment.title} · ${w.assignment.progress} de ${w.assignment.needed} partes`, prepare: null })
  }
  agenda.sort((a, b) => (a.kind === "interview" ? 0 : 1) - (b.kind === "interview" ? 0 : 1))
  const p = w?.promotion
  const promotionReason = internalApplicationReason(world)
  const nextRoleId = e ? roleCareer[e.roleId]?.next ?? null : null
  return {
    employment: e && role && w && manager ? { company: world.companies[e.companyId]!.name, title: role.title,
      salary: formatMoney(w.salaryCents), accrued: formatMoney(e.accruedCents), shifts: e.shiftsWorked, tenure: tenureText(world.clock.day - e.startedAt.day),
      schedule: "Seg a sex, até 8h30",
      started: formatDate(e.startedAt), performance: situation[0] ?? "", presence: e.consecutiveAbsences === 2 ? "Você recebeu uma advertência. Outra falta seguida encerra o contrato."
        : e.consecutiveAbsences === 1 ? "Há uma falta registrada. Comparecer ao próximo turno interrompe a sequência."
        : `A presença é cobrada a partir de ${formatDate({ day: e.requiredFromDay, minute: 0 })}.`,
      warning: w.warnings > 0 || e.consecutiveAbsences > 0, situation,
      manager: { id: manager.id, name: manager.name, age: ageAt(manager.birthDate, world.clock), appearance: { seed: manager.appearanceSeed, sex: manager.sex }, relation: trustText(w.trust) },
      next: nextRoleId ? { title: jobRoles.find(r => r.id === nextRoleId)!.title, gaps: promotionGaps(world) } : null } : null,
    agenda,
    promotion: p && e ? { title: jobRoles.find(r => r.id === p.roleId)!.title, company: world.companies[e.companyId]!.name, until: formatDate({ day: p.untilDay, minute: 0 }), canApply: !promotionReason, reason: promotionReason } : null,
    history: [...world.employmentHistory].reverse().map(record => ({ id: record.id, company: world.companies[record.companyId]!.name, title: jobRoles.find(role => role.id === record.roleId)!.title,
      ended: formatDate(record.endedAt), settlement: formatMoney(record.settledCents),
      reason: record.reason === "restructure" ? "Posto cortado quando a empresa enfrentou semanas fracas." : record.reason === "performance" ? "Contrato encerrado depois de duas conversas difíceis seguidas." : "Contrato encerrado após três faltas seguidas." })),
    companyMood: e ? companyMood(world, e.companyId) : null,
    canWork: !unavailable, unavailableReason: unavailable,
    nextWork: { date: formatDate(next), time: formatTime(next), waitMinutes: Math.max(0, Math.min(10080, waitMinutes)) },
    vacancies: Object.values(world.vacancies).filter(v => v.open).map(v => {
      const definition = jobRoles.find(item => item.id === v.roleId)!
      const reason = applicationReason(world, v.id)
      const tip = world.inbox.find(m => m.topic === "job-tip" && m.vacancyId === v.id && m.status === "answered")
      const rivals = competitionFor(world, v.roleId)
      return { id: v.id, title: definition.title, company: world.companies[v.companyId]!.name, salary: formatMoney(definition.salaryCents), canApply: !reason, reason,
        referral: tip ? `Com indicação de ${world.people[tip.fromId]!.name.split(" ")[0]}` : null,
        competition: rivals >= 6 ? "Muita gente procurando esse tipo de vaga." : rivals >= 3 ? "Há concorrência." : "Pouca concorrência.",
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

/** A cena de trabalho em curso, pronta para a tela (bíblia §7: situação, pessoas, custos, risco em palavras). */
export function queryWorkScene(world: WorldState) {
  const scene = world.work.scene
  if (!scene) return null
  const values = sceneValues(world, scene)
  const actor = scene.actorId ? world.people[scene.actorId]! : null
  const e = world.employment
  const actorRole = !actor ? null : scene.kind !== "shift" || actor.id === e?.workplace.managerId ? "Responde pela equipe" : "Colega de equipe"
  const base = { id: scene.id, kind: scene.kind, time: formatTime(scene.at), actor: actor ? { id: actor.id, name: actor.name, age: ageAt(actor.birthDate, world.clock), appearance: { seed: actor.appearanceSeed, sex: actor.sex }, role: actorRole } : null }
  if (scene.kind === "shift") {
    const situation = workSituations.find(s => s.id === scene.situationId)!
    const skill = jobRoles.find(r => r.id === e!.roleId)!.skill
    return { ...base, title: values.company, text: [fillText(situation.text, values)],
      choices: situation.choices.map(c => {
        const cost = [c.minutes ? `+${c.minutes} min` : null, c.success.effect.moneyCents ? formatMoney(-c.success.effect.moneyCents) : null].filter(Boolean).join(", ")
        const money = -(c.success.effect.moneyCents ?? 0)
        const reason = money > 0 && world.finance.balanceCents < money ? "Não há saldo para isso agora." : null
        return { id: c.id, label: fillText(c.label, values), meta: cost || null, hint: riskOf(world, c, skill).hint, canChoose: !reason, reason }
      }) }
  }
  if (scene.kind === "review") {
    return { ...base, title: `Com ${values.manager}`, text: reviewEvaluation(world).facts,
      choices: reviewChoices(world).map(c => ({ id: c.id, label: c.label, meta: null, hint: null, canChoose: c.available, reason: c.reason })) }
  }
  const interview = world.work.interviews.find(i => i.id === scene.interviewId)!
  const intro = interview.internal ? interviewTexts.internal : interviewTexts.intro[familyOf(interview.roleId)]
  return { ...base, title: interview.internal ? `Processo interno · ${values.role}` : values.company,
    text: [fillText(intro, values), interview.prepared ? "Você chegou com as respostas ensaiadas." : "Você não teve tempo de se preparar."],
    choices: interviewChoices(world, interview).map(c => ({ id: c.id, label: c.label, meta: null, hint: riskOf(world, c, c.skill).hint, canChoose: true, reason: null })) }
}

export function queryRoutine(world: WorldState) {
  const groceries = groceriesReason(world)
  const communityDay = world.clock.minute > 840 || world.routine.lastCommunityMealDay === world.clock.day ? world.clock.day + 1 : world.clock.day
  const communityWait = Math.max(0, absoluteMinute({ day: communityDay, minute: 660 }) - absoluteMinute(world.clock))
  return { pantry: world.routine.pantryMeals === 0 ? "A despensa está vazia." : `Há ingredientes para ${world.routine.pantryMeals} ${world.routine.pantryMeals === 1 ? "refeição" : "refeições"} em casa.`,
    meals: (Object.keys(routineRules.meals) as MealSource[]).map(source => {
      const meal = routineRules.meals[source], reason = mealReason(world, source)
      return { source, label: `${meal.label} · ${meal.priceCents ? `${formatMoney(meal.priceCents)}, ` : source === "community" ? "gratuito, " : ""}${meal.minutes} min`, canEat: !reason, reason }
    }),
    groceries: { label: `Comprar para seis refeições · ${formatMoney(routineRules.groceries.priceCents)}, 1 hora`, canBuy: !groceries, reason: groceries },
    communityWait, communityDate: formatDate({ day: communityDay, minute: 660 }),
    showCommunityWait: communityWait > 0 && world.finance.balanceCents < routineRules.meals.restaurant.priceCents && world.routine.pantryMeals === 0,
  }
}

export function queryMoney(world: WorldState) {
  const now = calendarDate(world.clock.day)
  const thisMonth = world.finance.ledger.filter(entry => { const c = calendarDate(entry.at.day); return c.year === now.year && c.month === now.month })
  const incoming = thisMonth.filter(e => e.amountCents > 0).reduce((sum, e) => sum + e.amountCents, 0)
  const outgoing = thisMonth.filter(e => e.amountCents < 0).reduce((sum, e) => sum - e.amountCents, 0)
  return { balance: formatMoney(world.finance.balanceCents), negative: world.finance.balanceCents < 0,
    monthName: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"][now.month - 1]!,
    month: { incoming: formatMoney(incoming), outgoing: formatMoney(outgoing), result: formatMoney(incoming - outgoing), positive: incoming >= outgoing },
    rent: formatMoney(world.finance.monthlyRentCents), accrued: formatMoney(world.employment?.accruedCents ?? 0),
    warning: world.finance.balanceCents < 0 ? "A conta ficou negativa. Os débitos continuam no extrato; receber salário ajuda a cobrir o saldo." : world.finance.balanceCents < world.finance.monthlyRentCents ? "O saldo disponível ainda não cobre o próximo aluguel." : "O próximo aluguel cabe no saldo disponível.",
    ledger: [...world.finance.ledger].reverse().slice(0, 100).map(entry => ({ id: entry.id, date: formatDate(entry.at), time: formatTime(entry.at), text: entry.text, amount: formatMoney(entry.amountCents), incoming: entry.amountCents > 0, cause: entry.cause })),
  }
}

/** Saúde da empresa dita como quem trabalha lá perceberia; sem números (bíblia §15, §32). */
function companyMood(world: WorldState, id: CompanyId): string {
  const e = world.economy[id]
  if (!e) return "Sem notícias da empresa."
  if (e.weakWeeks >= 2 || e.health < 0.3) return "Semanas fracas seguidas. Fala-se em corte."
  if (e.health < 0.45) return "O movimento anda fraco."
  if (e.health > 0.7 && e.trend > 0) return "Movimento forte. A empresa está contratando."
  return "Movimento estável."
}

export function queryWorld(world: WorldState) {
  const residence = world.residences[world.people[world.playerId]!.residenceId]!
  const circle = new Set(Object.values(world.relationships).filter(r => r.a === world.playerId || r.b === world.playerId).map(r => (r.a === world.playerId ? r.b : r.a)))
  const mine = world.employment?.companyId ?? null
  return { city: world.city, district: residence.district, population: Object.keys(world.people).length,
    news: world.news.slice(-24).reverse().map(item => {
      const known = item.personIds.find(id => circle.has(id))
      const relevance = item.companyId && item.companyId === mine ? "Onde você trabalha" : known ? `Você conhece ${world.people[known]!.name.split(" ")[0]}` : null
      return { id: item.id, date: formatDate(item.at), day: relativeDay(item.at, world.clock), section: item.section === "negocios" ? "Negócios" : item.section === "trabalho" ? "Trabalho" : "Cidade",
        headline: item.headline, body: item.body, relevance }
    }),
    companies: Object.values(world.companies).map(company => ({ id: company.id, name: company.name, district: company.district, mood: companyMood(world, company.id), yours: company.id === mine,
      staff: Object.values(world.residents).filter(r => r.job?.companyId === company.id).length,
      vacancies: Object.values(world.vacancies).filter(v => v.open && v.companyId === company.id).length })),
    residents: Object.values(world.people).filter(person => world.tiers[person.id] === "background").map(person => ({ id: person.id, name: person.name, age: ageAt(person.birthDate, world.clock), district: world.residences[person.residenceId]!.district })),
    facts: world.timeline.filter(entry => ["career", "finance", "education"].includes(entry.kind)).slice(-12).reverse().map(entry => ({ id: entry.id, date: formatDate(entry.at), text: entry.text })),
  }
}
