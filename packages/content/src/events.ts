export type EventCondition =
  | Readonly<{ type: "employed"; value: boolean }>
  | Readonly<{ type: "energy" | "money" | "stress"; min?: number; max?: number }>
export type EventEffect = Readonly<{
  minutes: number; moneyCents?: number; energy?: number; stress?: number
  organization?: number; communication?: number; affection?: number; trust?: number
}>
export type EventChoice = Readonly<{ id: string; label: string; outcome: string; effect: EventEffect; followUp?: string }>
export type EventDefinition = Readonly<{
  id: string; title: string; text: string; actor: "friend" | "mother" | null
  root: boolean; conditions: readonly EventCondition[]; choices: readonly EventChoice[]
}>

const choice = (id: string, label: string, outcome: string, effect: EventEffect, followUp?: string): EventChoice => ({ id, label, outcome, effect, ...(followUp ? { followUp } : {}) })
const event = (id: string, title: string, text: string, actor: EventDefinition["actor"], root: boolean, conditions: readonly EventCondition[], choices: readonly EventChoice[]): EventDefinition => ({ id, title, text, actor, root, conditions, choices })

// 10 cadeias de três etapas. Só condições/efeitos declarativos, sem callbacks.
// Ofertas únicas por campanha e orçamento de uma decisão por dia.
export const lifeEvents: readonly EventDefinition[] = [
  event("cafe", "Um café fora de casa", "{person} perguntou se você topa um café. É uma chance de se encontrar fora da correria.", "friend", true, [{ type: "energy", min: 15 }], [
    choice("go", "Ir ao café · R$ 12,00, 45 min", "Você encontrou {person} no café da praça. Por um momento, a mudança saiu da conversa.", { minutes: 45, moneyCents: -1200, energy: -2, stress: -6, affection: 3 }, "planos"),
    choice("stay", "Ficar em casa e guardar esse dinheiro", "Você explicou que precisa segurar os gastos. {person} deixou o convite para outra hora.", { minutes: 5, stress: 1 }),
  ]),
  event("planos", "A conversa continuou", "{person} lembrou do que vocês falaram no café e quer saber como anda a procura por um caminho na cidade.", "friend", false, [], [
    choice("talk", "Contar seus planos · 30 min", "Você falou dos próximos passos sem fingir que já tem tudo resolvido. {person} escutou.", { minutes: 30, trust: 3, stress: -3 }, "companhia"),
    choice("later", "Dizer que ainda precisa pensar", "Você pediu um pouco de tempo para organizar as ideias.", { minutes: 5, stress: -1 }),
  ]),
  event("companhia", "Alguém para dividir a semana", "{person} sugeriu caminhar pelo bairro, sem gastar nada.", "friend", false, [], [
    choice("walk", "Caminhar juntos · 1 hora", "Vocês deram uma volta pelas ruas do bairro. A amizade ganhou espaço na sua rotina.", { minutes: 60, energy: -4, stress: -8, affection: 4 }),
    choice("rest", "Aproveitar a hora para descansar", "Você preferiu uma hora em silêncio em casa e avisou {person}.", { minutes: 60, energy: 10, stress: -2 }),
  ]),
  event("visita", "Um convite da sua mãe", "Sua mãe perguntou se você quer passar lá. Ela disse que fez comida demais, como sempre.", "mother", true, [], [
    choice("go", "Visitar · R$ 12,00 de transporte, 2 horas", "Você foi até a casa da sua mãe. Ela quis saber da vida antes de perguntar do trabalho.", { minutes: 120, moneyCents: -1200, energy: 8, stress: -8, affection: 4 }, "mesa"),
    choice("phone", "Conversar por telefone · 20 min", "Vocês conversaram pelo telefone. Sua mãe disse para você aparecer quando puder.", { minutes: 20, trust: 1, stress: -2 }),
  ]),
  event("mesa", "O que ficou da visita", "Sua mãe quer saber se tem alguma coisa que está pesando. A pergunta veio sem cobrança.", "mother", false, [], [
    choice("honest", "Falar da parte difícil · 30 min", "Você contou o que tem sido difícil. Sua mãe ficou ouvindo, sem tentar resolver tudo.", { minutes: 30, trust: 4, stress: -6 }, "receita"),
    choice("light", "Manter a conversa leve", "Vocês falaram de coisas pequenas. Hoje você não quis abrir essa parte da vida.", { minutes: 15, affection: 1 }),
  ]),
  event("receita", "Uma receita no celular", "Sua mãe mandou uma receita simples e disse onde costuma encontrar os ingredientes mais baratos.", "mother", false, [], [
    choice("cook", "Fazer a receita · R$ 25,00, 1 hora", "Você fez a receita e mandou uma foto para sua mãe. A cozinha começou a parecer sua.", { minutes: 60, moneyCents: -2500, energy: 10, stress: -4, affection: 2 }),
    choice("save", "Guardar a receita para outra semana", "Você guardou a receita. Sua mãe respondeu que não tem pressa.", { minutes: 5, affection: 1 }),
  ]),
  event("oficina", "Uma oficina no centro comunitário", "O centro comunitário abriu uma oficina curta sobre organização no trabalho. Cabe nesta noite, mas tem uma taxa de material.", null, true, [{ type: "employed", value: false }], [
    choice("learn", "Participar · R$ 10,00, 90 min", "Você organizou documentos de exemplo e descobriu um jeito melhor de preparar uma lista de tarefas.", { minutes: 90, moneyCents: -1000, organization: .025, energy: -5 }, "curriculo"),
    choice("home", "Revisar suas anotações em casa · 30 min", "Você releu as próprias anotações. Foi um começo pequeno, mas coube no dia.", { minutes: 30, organization: .005 }),
  ]),
  event("curriculo", "Olhar o currículo de novo", "Depois da oficina, você percebeu que seu currículo não mostra bem o que já sabe fazer.", null, false, [], [
    choice("edit", "Reescrever com calma · 1 hora", "Você reorganizou o currículo e descreveu melhor suas experiências.", { minutes: 60, organization: .02, energy: -4 }, "preparo"),
    choice("leave", "Deixar como está por enquanto", "Você decidiu usar a versão atual do currículo nesta semana.", { minutes: 5 }),
  ]),
  event("preparo", "Antes de enviar", "O currículo está mais claro. Você pode ensaiar como explicar suas experiências antes da próxima candidatura.", null, false, [], [
    choice("practice", "Ensaiar uma conversa · 45 min", "Você praticou explicar o que sabe fazer. A próxima entrevista já parece menos distante.", { minutes: 45, communication: .025, stress: -3 }),
    choice("stop", "Encerrar por hoje e descansar", "Você guardou o currículo e fechou o celular por um tempo.", { minutes: 30, energy: 8 }),
  ]),
  event("estante", "Um serviço de poucas horas", "Um morador do prédio quer ajuda para organizar uma estante e separar caixas. Ele oferece R$ 50,00 pelo serviço.", null, true, [{ type: "employed", value: false }, { type: "energy", min: 30 }], [
    choice("help", "Fazer o serviço · 2 horas", "Você ajudou a organizar a estante e recebeu R$ 50,00. Foram duas horas separando caixas e livros.", { minutes: 120, moneyCents: 5000, energy: -15, organization: .01 }, "indicacao"),
    choice("decline", "Guardar a disposição para procurar emprego", "Você recusou com educação e separou tempo para pensar nas candidaturas.", { minutes: 30, organization: .005 }),
  ]),
  event("indicacao", "A indicação chegou", "O morador comentou seu trabalho com outra pessoa do prédio. Perguntaram se você tem tempo para conversar sobre uma nova ajuda.", null, false, [], [
    choice("listen", "Ouvir a proposta · 20 min", "Você ouviu a proposta: separar documentos e organizar uma pequena mudança.", { minutes: 20, communication: .01 }, "segundo-servico"),
    choice("no", "Dizer que não vai conseguir desta vez", "Você explicou que não consegue assumir outro serviço agora.", { minutes: 5 }),
  ]),
  event("segundo-servico", "Mais um serviço no prédio", "A pessoa combinou R$ 70,00 para separar documentos e organizar caixas. O pagamento é ao terminar.", null, false, [{ type: "energy", min: 20 }], [
    choice("work", "Fazer o serviço · 150 min", "Você terminou o serviço e recebeu os R$ 70,00 combinados.", { minutes: 150, moneyCents: 7000, energy: -20, organization: .015 }),
    choice("pass", "Recusar e descansar", "Você preferiu não assumir o serviço sem disposição suficiente.", { minutes: 30, energy: 8 }),
  ]),
  event("turno", "O trabalho veio para casa", "As tarefas do emprego continuam na sua cabeça mesmo em casa. Dá para fazer algo com isso, mas o descanso também está faltando.", null, true, [{ type: "employed", value: true }], [
    choice("write", "Anotar o que ficou pendente · 30 min", "Você anotou as tarefas de amanhã e conseguiu parar de repassá-las mentalmente.", { minutes: 30, stress: -5, organization: .01 }, "tarefas"),
    choice("rest", "Deixar o trabalho para amanhã", "Você separou um tempo para descansar. As tarefas do trabalho ficam para o próximo expediente.", { minutes: 45, energy: 10, stress: -3 }),
  ]),
  event("tarefas", "Uma lista mais curta", "A lista do trabalho tem tarefas demais para um único dia. Você pode reorganizar a ordem antes de começar o próximo turno.", null, false, [{ type: "employed", value: true }], [
    choice("order", "Escolher o que precisa vir primeiro · 30 min", "Você separou as tarefas urgentes das que podem esperar.", { minutes: 30, organization: .025, stress: -2 }, "limite"),
    choice("leave", "Seguir a lista como veio", "Você guardou a lista para seguir a ordem de sempre.", { minutes: 5 }),
  ]),
  event("limite", "Um jeito de encerrar o dia", "A organização ajudou, mas você quer evitar que todo expediente termine em preocupação.", null, false, [], [
    choice("routine", "Criar uma rotina para fechar o trabalho · 45 min", "Você reservou alguns minutos para revisar pendências antes de sair. A ideia é deixar o trabalho no trabalho.", { minutes: 45, organization: .02, stress: -5 }),
    choice("sleep", "Priorizar o descanso de hoje", "Você escolheu descansar e pensar no próximo turno depois.", { minutes: 60, energy: 15 }),
  ]),
  event("orcamento", "Antes do próximo aluguel", "O saldo ainda não cobre o aluguel. Rever os gastos não cria dinheiro, mas pode mostrar o que precisa esperar.", null, true, [{ type: "money", max: 74999 }], [
    choice("review", "Rever o extrato · 1 hora", "Você reviu cada gasto e anotou os compromissos que vêm primeiro.", { minutes: 60, organization: .015, stress: -3 }, "compras"),
    choice("later", "Deixar essa revisão para outro dia", "Você fechou o extrato. O próximo aluguel continua na sua cabeça.", { minutes: 5, stress: 2 }),
  ]),
  event("compras", "Cozinhar pode caber na semana", "Você fez uma lista curta de compras. Os ingredientes custam R$ 35,00; preparar tudo leva uma hora e meia.", null, false, [], [
    choice("prepare", "Comprar e preparar · R$ 35,00, 90 min", "Você comprou os ingredientes e preparou comida em casa. O gasto ficou registrado no extrato.", { minutes: 90, moneyCents: -3500, energy: 12, organization: .01 }, "rotina-compras"),
    choice("hold", "Adiar a compra e preservar o saldo", "Você guardou a lista e decidiu preservar o saldo disponível.", { minutes: 5 }),
  ]),
  event("rotina-compras", "A lista ficou mais simples", "Depois de cozinhar, você percebeu quais compras realmente usa no dia a dia.", null, false, [], [
    choice("list", "Ajustar a lista da próxima semana · 20 min", "Você tirou da lista o que não usou e deixou só o essencial.", { minutes: 20, organization: .02, stress: -2 }),
    choice("done", "Encerrar por hoje", "Você deixou a próxima lista para quando precisar dela.", { minutes: 5, energy: 2 }),
  ]),
  event("cansaco", "Uma noite sem mais tarefas", "O corpo está pedindo uma pausa. Ainda tem coisas para fazer em casa, mas nenhuma precisa ser hoje.", null, true, [{ type: "energy", max: 40 }], [
    choice("pause", "Reservar duas horas para descansar", "Você aceitou que o dia acabou e descansou por duas horas.", { minutes: 120, energy: 30, stress: -5 }, "notificacoes"),
    choice("short", "Resolver uma tarefa curta · 20 min", "Você resolveu uma tarefa pequena e deixou o resto como estava.", { minutes: 20, energy: -3, organization: .01 }),
  ]),
  event("notificacoes", "O celular não para", "Mesmo depois da pausa, você está olhando o celular toda hora. Nenhuma mensagem é urgente.", null, false, [], [
    choice("silence", "Silenciar por um tempo · 45 min", "Você silenciou as notificações e ficou um tempo sem conferir a tela.", { minutes: 45, stress: -8 }, "pausa"),
    choice("check", "Conferir uma última vez · 10 min", "Você conferiu as mensagens e fechou o celular de novo.", { minutes: 10, stress: -1 }),
  ]),
  event("pausa", "A pausa teve efeito", "A casa continua com tarefas, mas você conseguiu separar um pouco de tempo sem cobrança.", null, false, [], [
    choice("keep", "Reservar meia hora só para você", "Você manteve meia hora livre e deixou a noite mais leve.", { minutes: 30, stress: -5, energy: 5 }),
    choice("use", "Usar a meia hora para organizar amanhã", "Você usou o tempo para preparar o dia seguinte.", { minutes: 30, organization: .015, energy: -2 }),
  ]),
  event("biblioteca", "Um aviso na biblioteca", "A biblioteca do bairro abriu uma roda de leitura. Não há taxa, mas você precisa separar uma hora e meia.", null, true, [{ type: "energy", min: 25 }], [
    choice("read", "Participar · 90 min", "Você ouviu outras leituras e explicou o que entendeu de um texto.", { minutes: 90, communication: .025, energy: -6, stress: -3 }, "leitura"),
    choice("home", "Ler em casa por meia hora", "Você leu um pouco em casa e anotou uma ideia que quer lembrar.", { minutes: 30, communication: .005 }),
  ]),
  event("leitura", "Uma conversa sobre o texto", "{person} perguntou como foi a roda de leitura e acabou se interessando pelo texto.", "friend", false, [], [
    choice("share", "Contar o que você leu · 30 min", "Você explicou o texto do seu jeito. {person} trouxe outra interpretação.", { minutes: 30, communication: .02, affection: 2 }, "encontro-leitura"),
    choice("send", "Enviar o nome do texto", "Você enviou o nome do texto para {person} ler quando puder.", { minutes: 5, affection: 1 }),
  ]),
  event("encontro-leitura", "Ler junto fora de casa", "{person} sugeriu passar na biblioteca com você e tomar alguma coisa na volta.", "friend", false, [], [
    choice("go", "Ir juntos · R$ 10,00, 2 horas", "Vocês passaram na biblioteca e continuaram a conversa na volta.", { minutes: 120, moneyCents: -1000, communication: .015, affection: 3, energy: -8 }),
    choice("library", "Ir só à biblioteca · 1 hora", "Vocês combinaram só a passagem pela biblioteca, sem gastar na volta.", { minutes: 60, communication: .01, affection: 1, energy: -4 }),
  ]),
  event("distancia", "Uma amizade fora da rotina", "A mudança reorganizou sua rotina. Você pensa em como manter espaço para a amizade com {person}.", "friend", true, [], [
    choice("call", "Procurar para conversar · 30 min", "Você procurou {person} e falou da correria. A conversa começou a tirar um pouco da distância.", { minutes: 30, affection: 3, trust: 2 }, "resposta"),
    choice("wait", "Esperar por uma hora mais tranquila", "Você decidiu esperar por uma hora mais tranquila, mesmo sabendo que a rotina não vai parar sozinha.", { minutes: 5, affection: -1 }),
  ]),
  event("resposta", "A conversa ficou aberta", "{person} respondeu que também sentiu falta e perguntou quando vocês podem se encontrar.", "friend", false, [], [
    choice("plan", "Separar um tempo para se ver · 20 min", "Vocês separaram um tempo para conversar pessoalmente.", { minutes: 20, trust: 2 }, "reencontro"),
    choice("honest", "Dizer que esta semana está difícil", "Você explicou que esta semana não vai dar. {person} preferiu a resposta sincera.", { minutes: 10, trust: 1 }),
  ]),
  event("reencontro", "A conversa saiu do celular", "Chegou a oportunidade de encontrar {person} sem pressa. O transporte custa R$ 15,00.", "friend", false, [], [
    choice("visit", "Ir ao encontro · R$ 15,00, 90 min", "Você encontrou {person}. Algumas coisas que pareciam difíceis por mensagem ficaram mais simples pessoalmente.", { minutes: 90, moneyCents: -1500, affection: 5, trust: 2, stress: -5 }),
    choice("home", "Propor conversar por telefone", "Vocês conversaram por telefone e deixaram o encontro para outra ocasião.", { minutes: 30, affection: 1 }),
  ]),
  event("casa", "As caixas no corredor", "As caixas que sobraram da mudança continuam ocupando o corredor. Separar tudo leva tempo, mas pode deixar a casa mais fácil de usar.", null, true, [{ type: "energy", min: 20 }], [
    choice("sort", "Organizar o corredor · 2 horas", "Você abriu as caixas, separou o que precisava e liberou o corredor.", { minutes: 120, energy: -15, stress: -6, organization: .015 }, "rotina-casa"),
    choice("small", "Organizar só uma caixa · 30 min", "Você organizou uma caixa e deixou as outras para um dia com mais disposição.", { minutes: 30, energy: -4, stress: -1 }),
  ]),
  event("rotina-casa", "Agora dá para encontrar as coisas", "Com o corredor livre, você percebeu que falta um lugar fixo para documentos e contas.", null, false, [], [
    choice("place", "Separar documentos e contas · 45 min", "Você juntou documentos e contas num lugar só. A casa começou a ganhar uma rotina.", { minutes: 45, organization: .025, stress: -3 }, "casa-pronta"),
    choice("later", "Deixar essa parte para depois", "Você preferiu aproveitar o corredor livre e descansar.", { minutes: 20, energy: 5 }),
  ]),
  event("casa-pronta", "Uma casa para receber", "{person} perguntou se já pode conhecer a casa. Você pode preparar algo simples ou só convidar para uma conversa.", "friend", false, [], [
    choice("meal", "Preparar algo para receber · R$ 35,00, 2 horas", "{person} conheceu a casa. Vocês comeram e conversaram sem o corredor cheio de caixas.", { minutes: 120, moneyCents: -3500, affection: 4, stress: -5, energy: -8 }),
    choice("simple", "Receber sem preparar comida · 1 hora", "{person} passou para conhecer a casa. Vocês conversaram e deixaram a comida para outro dia.", { minutes: 60, affection: 2, stress: -2, energy: -4 }),
  ]),
]

export function validateLifeEvents(definitions: readonly EventDefinition[] = lifeEvents): readonly string[] {
  const errors: string[] = [], ids = new Set(definitions.map(d => d.id))
  if (ids.size !== definitions.length) errors.push("Evento com ID duplicado.")
  for (const definition of definitions) {
    if (!definition.id || !definition.title || !definition.text || definition.choices.length < 2 || new Set(definition.choices.map(c => c.id)).size !== definition.choices.length) errors.push(`Evento incompleto: ${definition.id}.`)
    if (!definition.choices.some(option => (option.effect.moneyCents ?? 0) >= 0)) errors.push(`Evento sem alternativa gratuita: ${definition.id}.`)
    for (const condition of definition.conditions) {
      if (condition.type === "employed") continue
      const { min, max } = condition
      if ((min !== undefined && !Number.isFinite(min)) || (max !== undefined && !Number.isFinite(max)) || (min !== undefined && max !== undefined && min > max)) errors.push(`Condição inválida: ${definition.id}.`)
    }
    for (const option of definition.choices) {
      if (!option.id || !option.label || !option.outcome) errors.push(`Escolha incompleta: ${definition.id}.`)
      if (option.followUp && !ids.has(option.followUp)) errors.push(`Follow-up ausente: ${option.followUp}.`)
      if (option.followUp && definitions.find(event => event.id === option.followUp)?.root) errors.push(`Follow-up aponta para início de cadeia: ${option.followUp}.`)
      for (const [key, value] of Object.entries(option.effect)) if (!Number.isFinite(value) || (key === "minutes" && (!Number.isSafeInteger(value) || value < 1 || value > 480)) || (key === "moneyCents" && !Number.isSafeInteger(value))) errors.push(`Efeito inválido: ${definition.id}/${option.id}.`)
    }
  }
  for (const definition of definitions) {
    const visit = (id: string, path: Set<string>) => {
      if (path.has(id)) { errors.push(`Ciclo de eventos: ${id}.`); return }
      const event = definitions.find(item => item.id === id)
      const next = new Set(path); next.add(id)
      for (const choice of event?.choices ?? []) if (choice.followUp) visit(choice.followUp, next)
    }
    visit(definition.id, new Set())
  }
  return errors
}
