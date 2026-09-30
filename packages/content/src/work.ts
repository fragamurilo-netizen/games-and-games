// Trabalho vivido por dentro (bíblia §7, §15, §46, §61): situações do turno por família de
// função, tarefas com prazo, conversa mensal com quem responde pela equipe e entrevistas.
// Conteúdo declarativo; a simulação decide quando cada coisa acontece e o que custa.
// Placeholders: {coworker} {manager} {company} {role} {task} {due}. Texto sem marca de gênero
// para o jogador; colegas são tratados pelo nome.

export type RoleFamily = "atendimento" | "operacao" | "escritorio"
export type WorkEffect = Readonly<{
  performance?: number; trust?: number; energy?: number; stress?: number; hunger?: number
  /** afeto com o colega da cena */
  coworker?: number
  /** prática na habilidade da função (0–1) */
  practice?: number
  /** unidades da tarefa da semana */
  progress?: number
  moneyCents?: number
  /** dias a mais no prazo da tarefa */
  extendDue?: number
}>
export type WorkOutcome = Readonly<{ text: string; effect: WorkEffect }>
export type WorkChoice = Readonly<{ id: string; label: string; minutes?: number; difficulty?: number; success: WorkOutcome; failure?: WorkOutcome }>
export type WorkCondition = Readonly<{ lowEnergy?: boolean; weakCompany?: boolean; assignmentDue?: boolean; late?: boolean; minTrust?: number; minShifts?: number }>
export type WorkSituation = Readonly<{ id: string; family: RoleFamily | "geral"; actor: "coworker" | "manager" | "customer"; text: string; when?: WorkCondition; choices: readonly WorkChoice[] }>

export const workRules = {
  /** depois disso a chegada conta como atraso (o turno ainda pode começar até 14h) */
  onTimeMinute: 510,
  /** a situação do turno acontece depois dessas horas de trabalho */
  momentAfterMinutes: 180,
  reviewEveryDays: 28,
  raise: 0.07,
  raiseMinDays: 56,
  promotionMinDays: 60,
  promotionWindowDays: 14,
  /** advertências formais antes da demissão por desempenho */
  warningLimit: 2,
  assignmentEveryDays: 7,
  recentSituations: 8,
  interviewHours: [600, 900] as readonly number[],
  prepareMinutes: 60,
} as const

/** Família e próximo degrau de cada função (bíblia §15.5). */
export const roleCareer: Readonly<Record<string, Readonly<{ family: RoleFamily; next: string | null }>>> = {
  stock: { family: "operacao", next: "inventory" },
  dispatch: { family: "operacao", next: "inventory" },
  inventory: { family: "operacao", next: "assistant" },
  counter: { family: "atendimento", next: "sales" },
  barista: { family: "atendimento", next: "reception" },
  sales: { family: "atendimento", next: "support" },
  reception: { family: "atendimento", next: "hotel" },
  hotel: { family: "atendimento", next: "support" },
  support: { family: "atendimento", next: null },
  assistant: { family: "escritorio", next: "office" },
  office: { family: "escritorio", next: "accounts" },
  accounts: { family: "escritorio", next: null },
}

const c = (id: string, label: string, success: WorkOutcome, extra: Partial<Pick<WorkChoice, "minutes" | "difficulty" | "failure">> = {}): WorkChoice => ({ id, label, success, ...extra })
const o = (text: string, effect: WorkEffect): WorkOutcome => ({ text, effect })

export const workSituations: readonly WorkSituation[] = [
  // ---------------- atendimento ----------------
  { id: "troco", family: "atendimento", actor: "customer", text: "Uma cliente voltou ao balcão dizendo que recebeu troco a menos. A fila atrás dela começa a reclamar.", choices: [
    c("conferir", "Conferir o caixa na frente dela", o("O caixa fechava certo. Você mostrou a conta com calma e ela foi embora convencida.", { performance: 3, trust: 1, practice: .01 }),
      { minutes: 20, difficulty: .2, failure: o("A conta não bateu na primeira tentativa e a fila cresceu. No fim, a diferença era de centavos e a cliente saiu irritada.", { performance: -1, stress: 5 }) }),
    c("devolver", "Devolver a diferença sem discutir", o("Você devolveu os cinco reais. No fechamento, o caixa sobrou exatamente esse valor. {manager} pediu para conferir antes da próxima vez.", { trust: -1, stress: -1 })),
    c("chamar", "Chamar {manager}", o("{manager} resolveu em dois minutos e depois mostrou como conferir o troco na frente do cliente.", { trust: -1, practice: .01 })),
  ] },
  { id: "fila", family: "atendimento", actor: "coworker", text: "A fila dobrou na hora do almoço e {coworker} ainda está no intervalo.", choices: [
    c("sozinho", "Segurar a fila sem ajuda", o("Você atendeu um por um sem perder o fio. Quando {coworker} voltou, a fila já tinha andado.", { performance: 4, trust: 2, energy: -8, stress: 4, coworker: 2 }),
      { difficulty: .3, failure: o("Você trocou dois pedidos e um cliente foi embora sem ser atendido.", { performance: -3, energy: -8, stress: 8 }) }),
    c("chamar", "Chamar {coworker} de volta mais cedo", o("{coworker} voltou mastigando e sem dizer muita coisa. A fila andou.", { performance: 2, coworker: -3 })),
    c("ritmo", "Pedir paciência e seguir no seu ritmo", o("Alguns clientes bufaram, mas ninguém saiu com o pedido errado.", { performance: -1, stress: -1 })),
  ] },
  { id: "grito", family: "atendimento", actor: "customer", text: "Um cliente levantou a voz por causa de um pedido errado. Não foi você que anotou.", choices: [
    c("ouvir", "Ouvir até o fim e oferecer uma solução", o("Ele desabafou, você propôs trocar o pedido e ainda ganhou um obrigado seco. {manager} viu tudo de longe.", { performance: 4, trust: 3, stress: 4, practice: .015 }),
      { difficulty: .35, failure: o("Nada do que você ofereceu serviu. O cliente exigiu falar com {manager}.", { performance: -2, stress: 8 }) }),
    c("explicar", "Explicar que o erro foi de outro turno", o("A explicação era verdadeira, mas soou como desculpa. O cliente saiu dizendo que não volta.", { performance: -2, stress: 3 })),
    c("gestor", "Passar a conversa para {manager}", o("{manager} assumiu. Depois comentou que, da próxima vez, espera que você resolva sem chamar ninguém.", { trust: -2, stress: -2 })),
  ] },
  { id: "freguesa", family: "atendimento", actor: "customer", text: "Uma senhora que vem todo dia pergunta seu nome e quer saber se você chegou há pouco no bairro.", choices: [
    c("conversar", "Conversar um pouco", o("Ela contou que mora ali há quarenta anos e prometeu trazer bolo na sexta.", { performance: 1, stress: -4, practice: .01 }), { minutes: 10 }),
    c("sorriso", "Responder com um sorriso e seguir o trabalho", o("Ela sorriu de volta. Amanhã provavelmente pergunta de novo.", { performance: 1 })),
  ] },
  { id: "falta-produto", family: "atendimento", actor: "customer", text: "Um cliente procura algo que acabou. A loja do outro lado da rua tem.", choices: [
    c("indicar", "Indicar a outra loja", o("O cliente agradeceu e prometeu voltar. {manager} torceu o nariz.", { trust: -1, stress: -1 })),
    c("parecido", "Oferecer um produto parecido", o("Ele levou e ainda perguntou quando chega reposição.", { performance: 3, trust: 2 }),
      { difficulty: .3, failure: o("Ele levou, mas voltou no fim da tarde para trocar.", { performance: -1, stress: 3 }) }),
    c("anotar", "Anotar o pedido para a próxima entrega", o("Você anotou nome e telefone. Se chegar, alguém vai ligar.", { performance: 2, trust: 1, progress: 1 }), { minutes: 10 }),
  ] },
  { id: "novato", family: "atendimento", actor: "manager", text: "{manager} pediu para você mostrar a rotina a alguém que começou hoje.", when: { minShifts: 5 }, choices: [
    c("ensinar", "Ensinar com calma o que você já sabe", o("No fim do turno a pessoa nova já fazia o básico sozinha. {manager} notou.", { trust: 4, performance: 2, energy: -5, practice: .02 }),
      { difficulty: .4, failure: o("Você explicou rápido demais e teve que refazer metade do que foi mostrado.", { trust: -1, stress: 4, energy: -5 }) }),
    c("basico", "Passar o básico e voltar ao seu trabalho", o("A pessoa ficou com dúvidas, mas o seu trabalho não atrasou.", { performance: 1 })),
    c("recusar", "Dizer que ainda está aprendendo", o("{manager} entendeu e passou a tarefa para {coworker}.", { trust: -1, stress: -2 })),
  ] },
  { id: "cobranca-dupla", family: "atendimento", actor: "manager", text: "Você percebeu que cobrou um item duas vezes de um cliente que já saiu.", choices: [
    c("contar", "Contar a {manager}", o("{manager} agradeceu por avisar. O estorno ficou registrado e ninguém saiu prejudicado.", { trust: 3, stress: 2 })),
    c("correr", "Correr atrás do cliente", o("Você alcançou o cliente na esquina e devolveu a diferença. Ele não acreditou.", { performance: 2, trust: 2, energy: -4 }), { minutes: 10 }),
    c("esperar", "Esperar para ver se ele reclama", o("Ninguém voltou. O erro ficou com você o resto do turno.", { performance: -1, stress: 4 })),
  ] },
  { id: "fechamento", family: "atendimento", actor: "coworker", text: "Faltam dez minutos para fechar e entra um grupo grande.", choices: [
    c("atender", "Atender todo mundo", o("O grupo saiu satisfeito e deixou um elogio no caderno. Você saiu bem depois do horário.", { performance: 3, trust: 3, energy: -6 }), { minutes: 40 }),
    c("dividir", "Dividir o grupo com {coworker}", o("Vocês atenderam em dupla e fecharam só um pouco atrasados.", { performance: 2, coworker: 2 }), { minutes: 20 }),
    c("fechado", "Avisar que o atendimento já encerrou", o("O grupo foi embora contrariado. {manager} ouviu a reclamação no dia seguinte.", { trust: -1, stress: -2 })),
  ] },
  // ---------------- operação ----------------
  { id: "caminhao", family: "operacao", actor: "coworker", text: "O caminhão chegou duas horas atrasado e a carga precisa estar no lugar até o fim do turno.", choices: [
    c("acelerar", "Acelerar e descarregar tudo", o("Tudo guardado no prazo. As costas vão lembrar disso amanhã.", { performance: 4, trust: 3, energy: -10 }),
      { difficulty: .3, failure: o("Uma pilha tombou. Nada quebrou, mas o susto custou meia hora.", { performance: -1, energy: -10, stress: 6 }) }),
    c("ajuda", "Pedir ajuda a {coworker}", o("{coworker} ajudou, meio a contragosto. Em dupla, a carga foi rápido.", { performance: 3, energy: -5, coworker: -1 })),
    c("registrar", "Guardar o que der e registrar o resto", o("Metade ficou para amanhã, com tudo anotado. {manager} preferiu assim a ver coisa fora do lugar.", { trust: 1, stress: -1 })),
  ] },
  { id: "contagem", family: "operacao", actor: "manager", text: "A contagem do estoque não bate com o sistema: faltam doze unidades.", choices: [
    c("recontar", "Recontar prateleira por prateleira", o("As doze unidades estavam numa caixa sem etiqueta atrás da porta. {manager} anotou seu nome.", { performance: 5, trust: 4, progress: 1, energy: -6 }),
      { minutes: 60, difficulty: .35, failure: o("Você recontou tudo e a diferença continuou. Pelo menos agora o erro está documentado.", { performance: 1, energy: -6, stress: 3 }) }),
    c("avisar", "Registrar a diferença e avisar {manager}", o("{manager} disse que vai checar as notas de entrada.", { performance: 1, trust: 1 })),
    c("ajustar", "Ajustar o número para bater", o("Ninguém percebeu. Por enquanto.", { stress: 4 }),
      { difficulty: .55, failure: o("{manager} refez a contagem e viu o ajuste. A conversa foi curta e séria.", { trust: -10, performance: -4, stress: 8 }) }),
  ] },
  { id: "escada", family: "operacao", actor: "coworker", text: "{coworker} está subindo na prateleira sem a escada para pegar uma caixa lá em cima.", choices: [
    c("insistir", "Buscar a escada e insistir", o("{coworker} revirou os olhos, mas desceu. Dez minutos depois, a prateleira de cima cedeu sozinha.", { coworker: 2, trust: 1, stress: 2 })),
    c("segurar", "Segurar a base para ajudar", o("Deu certo. {coworker} agradeceu, e você ficou com o coração acelerado.", { coworker: 2, stress: 4 })),
    c("deixar", "Seguir com o seu trabalho", o("Dessa vez não aconteceu nada.", { performance: 1 })),
  ] },
  { id: "etiqueta", family: "operacao", actor: "manager", text: "Um lote inteiro saiu com a etiqueta de outro cliente. A coleta passa em uma hora.", choices: [
    c("refazer", "Refazer as etiquetas antes da coleta", o("Deu tempo por pouco. O motorista esperou cinco minutos.", { performance: 4, trust: 3, energy: -5 }), { minutes: 45 }),
    c("transportadora", "Ligar para a transportadora e ajustar", o("A transportadora aceitou trocar os destinos no sistema.", { performance: 2, trust: 2, practice: .01 }),
      { difficulty: .3, failure: o("A ligação caiu duas vezes. O lote foi com a etiqueta errada e voltou três dias depois.", { performance: -3, trust: -2, stress: 5 }) }),
    c("seguir", "Deixar seguir e avisar depois", o("O lote voltou na semana seguinte com uma reclamação formal.", { performance: -4, trust: -4 })),
  ] },
  { id: "ideia-corredor", family: "operacao", actor: "manager", text: "Você teve uma ideia para organizar o corredor dos volumes pesados.", when: { minShifts: 8 }, choices: [
    c("propor", "Propor a ideia a {manager}", o("{manager} gostou e pediu para você testar na semana que vem.", { trust: 5, performance: 2, practice: .02 }),
      { difficulty: .35, failure: o("{manager} ouviu, mas disse que agora não é hora de mudar nada.", { trust: -1, stress: 2 }) }),
    c("testar", "Testar por conta própria", o("O corredor ficou melhor. Nem todo mundo gostou de ter que procurar as coisas em outro lugar.", { performance: 3, progress: 1, energy: -4, coworker: -1 }), { minutes: 30 }),
    c("guardar", "Guardar a ideia para outro momento", o("A ideia ficou anotada no celular.", {})),
  ] },
  { id: "costas", family: "operacao", actor: "coworker", text: "As costas reclamam depois da terceira pilha de caixas.", when: { lowEnergy: true }, choices: [
    c("parar", "Parar cinco minutos", o("A pausa ajudou. A pilha esperou.", { performance: -1, energy: 4, stress: -3 })),
    c("seguir", "Seguir no ritmo", o("Você terminou a pilha. À noite, vai sentir.", { performance: 2, energy: -8, stress: 3 })),
    c("trocar", "Trocar de tarefa com {coworker}", o("{coworker} aceitou pegar o pesado e ficou com cara de quem vai cobrar depois.", { energy: 2, coworker: -1 })),
  ] },
  { id: "urgente", family: "operacao", actor: "manager", text: "{manager} precisa de um pedido separado em meia hora para um cliente grande.", choices: [
    c("largar", "Largar tudo e separar", o("Pedido completo em vinte e oito minutos. {manager} fez um sinal de positivo.", { performance: 4, trust: 5, stress: 5 }),
      { difficulty: .3, failure: o("Faltaram dois itens e o cliente recebeu incompleto.", { performance: -2, trust: -3, stress: 6 }) }),
    c("dupla", "Chamar {coworker} para dividir", o("Em dupla foi rápido. {coworker} gostou do convite.", { performance: 3, trust: 2, coworker: 1 })),
    c("prazo", "Dizer que precisa de uma hora", o("{manager} respirou fundo e renegociou o horário com o cliente.", { trust: -1, performance: 1 })),
  ] },
  { id: "carrinho", family: "operacao", actor: "coworker", text: "O carrinho hidráulico quebrou de novo no meio da descarga.", choices: [
    c("consertar", "Tentar consertar com o que tem", o("Uma porca solta. Dez minutos e o carrinho voltou a rodar.", { performance: 3, trust: 2, practice: .015 }),
      { difficulty: .4, failure: o("Você piorou o vazamento e ainda sujou a roupa de óleo.", { performance: -1, energy: -6, stress: 4 }) }),
    c("mao", "Registrar o defeito e carregar na mão", o("O defeito ficou registrado e você carregou tudo no braço.", { performance: 1, trust: 1, energy: -8 })),
    c("esperar", "Esperar a manutenção", o("A manutenção chegou duas horas depois. A carga esperou.", { performance: -2, stress: -2 })),
  ] },
  // ---------------- escritório ----------------
  { id: "planilha", family: "escritorio", actor: "coworker", text: "A planilha que {coworker} te passou tem fórmulas quebradas na metade das linhas.", choices: [
    c("corrigir", "Corrigir e mostrar a {coworker} o que estava errado", o("{coworker} agradeceu e pediu para você olhar a próxima também.", { performance: 3, coworker: 2, practice: .02 }),
      { difficulty: .35, failure: o("Você consertou uma parte e quebrou outra. Levou meia hora para desfazer.", { stress: 5 }), minutes: 20 }),
    c("devolver", "Devolver para {coworker} arrumar", o("{coworker} arrumou, mas deixou claro que achou exagero.", { performance: -1, coworker: -2 })),
    c("silencio", "Corrigir sem dizer nada", o("A planilha ficou certa. {coworker} nem ficou sabendo.", { performance: 3, stress: 2 }), { minutes: 30 }),
  ] },
  { id: "fornecedor", family: "escritorio", actor: "customer", text: "Um fornecedor respondeu seu e-mail com um tom atravessado e cópia para {manager}.", choices: [
    c("firme", "Responder com calma e firmeza", o("A resposta seguinte veio educada. {manager} não comentou, mas leu.", { trust: 3, performance: 2, practice: .015 }),
      { difficulty: .35, failure: o("Sua resposta saiu mais dura do que você queria. A conversa azedou de vez.", { performance: -1, stress: 5 }) }),
    c("ligar", "Ligar e resolver por telefone", o("Por telefone, o problema era outro. Resolvido em quinze minutos.", { performance: 2, stress: 2 }), { minutes: 15 }),
    c("encaminhar", "Encaminhar para {manager}", o("{manager} respondeu em uma linha. O assunto morreu ali.", { trust: -1, stress: -3 })),
  ] },
  { id: "reuniao", family: "escritorio", actor: "manager", text: "{manager} chamou você para uma reunião em que ninguém da sua área costuma ir.", choices: [
    c("falar", "Ir e falar quando fizer sentido", o("Você fez uma pergunta que ninguém tinha feito. Depois, {manager} pediu que você acompanhasse o assunto.", { trust: 5, practice: .02 }),
      { difficulty: .4, failure: o("Você falou uma vez e a frase saiu atravessada. O resto da reunião foi em silêncio.", { trust: -1, stress: 5 }) }),
    c("anotar", "Ir e só anotar", o("Você saiu com três páginas de anotações e entendendo melhor como a empresa funciona.", { trust: 2, practice: .01 })),
    c("ficar", "Pedir para ficar no que está fazendo", o("Você adiantou a tarefa. {manager} foi sem você.", { performance: 2, progress: 1, trust: -1 })),
  ] },
  { id: "contrato-sumido", family: "escritorio", actor: "coworker", text: "Um contrato assinado sumiu da pasta e o cliente liga à tarde.", choices: [
    c("procurar", "Procurar pasta por pasta", o("Estava arquivado com a letra errada. Você reorganizou a gaveta inteira de quebra.", { performance: 4, trust: 3, progress: 1 }),
      { minutes: 40, difficulty: .3, failure: o("Não apareceu. Você deixou registrado onde já procurou.", { stress: 5 }) }),
    c("colega", "Perguntar a {coworker}", o("{coworker} lembrou que tinha levado para escanear. Estava na impressora.", { performance: 2, coworker: 1 })),
    c("segunda-via", "Pedir segunda via ao cliente", o("O cliente mandou, mas perguntou se estava tudo bem por aí.", { performance: 1, trust: -1 })),
  ] },
  { id: "recado", family: "escritorio", actor: "manager", text: "{manager} pediu para você resolver uma pendência pessoal na rua, no meio do expediente.", choices: [
    c("ir", "Ir e resolver", o("Você foi e voltou em meia hora. {manager} agradeceu de um jeito diferente do normal.", { trust: 3, performance: -1 })),
    c("negociar", "Propor resolver no fim do turno", o("{manager} topou. Você fez as duas coisas.", { trust: 1, performance: 1 }),
      { minutes: 20, difficulty: .3, failure: o("{manager} achou estranha a proposta e foi resolver por conta própria, com cara de poucos amigos.", { trust: -2, stress: 3 }) }),
    c("recusar", "Dizer que tem entregas pendentes", o("{manager} entendeu, mas não gostou.", { trust: -2, performance: 1 })),
  ] },
  { id: "sistema", family: "escritorio", actor: "coworker", text: "O sistema caiu de manhã e os pedidos do dia estão só no papel.", choices: [
    c("lista", "Organizar tudo numa lista à mão", o("Quando o sistema voltou, bastou digitar a sua lista. Nenhum pedido se perdeu.", { performance: 4, trust: 3, progress: 1 }),
      { difficulty: .3, failure: o("A lista ficou confusa e dois pedidos foram lançados em dobro.", { performance: -1, stress: 4 }) }),
    c("dividir", "Dividir os pedidos com {coworker}", o("Vocês dividiram por cliente e terminaram antes do almoço.", { performance: 2, coworker: 2 })),
    c("esperar", "Esperar o sistema voltar", o("O sistema voltou às três. O dia inteiro ficou apertado.", { performance: -2, stress: 3 })),
  ] },
  // ---------------- qualquer função ----------------
  { id: "prazo", family: "geral", actor: "manager", text: "A tarefa da semana, {task}, vence {due} e ainda falta uma parte.", when: { assignmentDue: true }, choices: [
    c("extra", "Ficar uma hora a mais na tarefa", o("A hora extra rendeu. Agora falta pouco.", { progress: 2, energy: -6, stress: 3, trust: 1 }), { minutes: 60 }),
    c("prazo", "Pedir mais um dia a {manager}", o("{manager} deu mais um dia, sem sorrir.", { extendDue: 1, trust: -1 }),
      { difficulty: .3, failure: o("{manager} disse que o prazo é o prazo.", { trust: -3, stress: 4 }) }),
    c("horario", "Fazer o que der no horário", o("Você avançou o que coube no dia.", { progress: 1 })),
  ] },
  { id: "atraso", family: "geral", actor: "manager", text: "{manager} viu você chegar depois do horário combinado.", when: { late: true }, choices: [
    c("explicar", "Explicar o que aconteceu", o("{manager} ouviu e disse que entende, desde que não vire rotina.", { trust: 1 }),
      { difficulty: .25, failure: o("A explicação soou ensaiada. {manager} só respondeu \"tá\".", { trust: -2, stress: 3 }) }),
    c("compensar", "Pedir desculpas e compensar no almoço", o("Você comeu em quinze minutos e voltou antes de todo mundo.", { trust: 2, performance: 1, hunger: 10 }), { minutes: 30 }),
    c("calar", "Não dizer nada", o("Ninguém tocou no assunto. {manager} anotou alguma coisa.", { trust: -2 })),
  ] },
  { id: "cobertura", family: "geral", actor: "coworker", text: "{coworker} pede que você cubra a última hora de hoje por causa de um compromisso de família.", choices: [
    c("cobrir", "Cobrir a hora inteira", o("{coworker} saiu correndo e mandou mensagem à noite agradecendo.", { coworker: 5, energy: -5, performance: 1 }), { minutes: 60 }),
    c("meia", "Cobrir meia hora", o("Meia hora ajudou. {coworker} deu um jeito no resto.", { coworker: 2, energy: -2 }), { minutes: 30 }),
    c("negar", "Dizer que hoje não dá", o("{coworker} disse que tudo bem, mas chegou em cima da hora ao compromisso.", { coworker: -2 })),
  ] },
  { id: "boato", family: "geral", actor: "coworker", text: "Corre no corredor que a empresa vai cortar gente.", when: { weakCompany: true }, choices: [
    c("perguntar", "Perguntar a {manager} diretamente", o("{manager} falou com franqueza: a situação está difícil, mas não há lista pronta.", { trust: 3, stress: -4 }),
      { difficulty: .4, failure: o("{manager} desconversou. O silêncio assustou mais que o boato.", { trust: -2, stress: 5 }) }),
    c("caprichar", "Caprichar e não chamar atenção", o("Você trabalhou sem parar. A cabeça não desligou.", { performance: 3, stress: 5 })),
    c("conversar", "Conversar com {coworker} no intervalo", o("{coworker} também está com medo. Dividir ajudou um pouco.", { coworker: 2, stress: -2 })),
  ] },
  { id: "elogio", family: "geral", actor: "manager", text: "{manager} elogiou seu trabalho na frente da equipe.", when: { minTrust: 65 }, choices: [
    c("dividir", "Dividir o mérito com {coworker}", o("{coworker} não esperava e gostou. A equipe notou.", { coworker: 3, trust: 1 })),
    c("aprender", "Aproveitar e pedir para aprender outra parte do trabalho", o("{manager} topou e marcou uma tarde para mostrar.", { trust: 2, practice: .03 }),
      { difficulty: .3, failure: o("{manager} disse que primeiro você precisa dominar o que já faz.", { stress: 2 }) }),
    c("agradecer", "Agradecer e seguir", o("Você agradeceu. O resto do dia foi mais leve.", { trust: 1, stress: -3 })),
  ] },
  { id: "cansaco", family: "geral", actor: "coworker", text: "O cansaço bateu no meio da tarde e os erros começaram a aparecer.", when: { lowEnergy: true }, choices: [
    c("cafe", "Tomar um café e respirar", o("Dez minutos depois, a cabeça voltou.", { energy: 5, stress: -3, performance: -1 }), { minutes: 10 }),
    c("automatico", "Seguir no automático", o("Você terminou o turno, mas refez duas coisas.", { performance: -3, energy: -4 })),
    c("leve", "Pedir para trocar para algo mais leve", o("{coworker} trocou com você. {manager} viu.", { energy: 3, trust: -1, coworker: -1 })),
  ] },
  { id: "almoco", family: "geral", actor: "coworker", text: "A equipe vai almoçar junto hoje e {coworker} chamou você.", choices: [
    c("ir", "Ir junto", o("O almoço foi barulhento e bom. Você entendeu melhor quem é quem na equipe.", { coworker: 3, stress: -4, hunger: -50, moneyCents: -1800 })),
    c("rapido", "Comer rápido e voltar ao trabalho", o("Você adiantou coisas enquanto o resto almoçava.", { performance: 2, hunger: -30, coworker: -1 })),
  ] },
]

export const assignmentTemplates: Readonly<Record<RoleFamily, readonly Readonly<{ id: string; title: string; needed: number }>[]>> = {
  operacao: [
    { id: "recontagem", title: "recontar o estoque do corredor de limpeza", needed: 4 },
    { id: "devolucoes", title: "reorganizar a área de devoluções", needed: 3 },
    { id: "etiquetas", title: "etiquetar o lote novo de prateleiras", needed: 4 },
  ],
  atendimento: [
    { id: "cadastro", title: "atualizar o cadastro dos clientes fiéis", needed: 3 },
    { id: "vitrine", title: "montar a vitrine da semana", needed: 3 },
    { id: "roteiro", title: "aprender o novo roteiro de atendimento", needed: 4 },
  ],
  escritorio: [
    { id: "notas", title: "fechar a planilha de notas do mês", needed: 4 },
    { id: "arquivo", title: "organizar o arquivo de contratos", needed: 3 },
    { id: "relatorio", title: "preparar o relatório de pedidos", needed: 4 },
  ],
}

export const reviewTexts = {
  intro: "No fim do turno, {manager} chamou você para a conversa do mês.",
  prepared: "Você chegou com as anotações do mês.",
  unprepared: "Você entrou sem ter pensado muito no que dizer.",
  late: "{manager} lembrou que você chegou depois do horário {count}.",
  absences: "{manager} citou as faltas do mês.",
  delivered: "A tarefa da semana foi entregue no prazo.",
  missed: "Uma tarefa passou do prazo e {manager} não esqueceu.",
  good: "No geral, {manager} gosta do que tem visto no seu trabalho.",
  weak: "{manager} disse que o trabalho caiu nas últimas semanas.",
  warning: "{manager} formalizou uma advertência. Se o próximo mês for parecido, o contrato acaba.",
  secondWarning: "Foi a segunda conversa difícil seguida.",
  offer: "{manager} comentou que vai abrir um processo interno para {role} e que você pode se candidatar.",
  choices: {
    raise: { label: "Pedir aumento", success: "{manager} conseguiu um aumento de {percent}. Passa a valer no próximo pagamento.", failure: "{manager} disse que agora não dá. \"Me mostra mais uns meses.\"", weakCompany: "{manager} foi direto: com a empresa do jeito que está, ninguém vai ter aumento agora." },
    responsibility: { label: "Pedir mais responsabilidade", success: "{manager} prometeu abrir um processo interno para {role}. Você pode se candidatar nas próximas duas semanas.", failure: "{manager} disse que ainda falta: {missing}.", noNext: "{manager} disse que, nesta função, o próximo passo é fora daqui." },
    listen: { label: "Ouvir e perguntar o que melhorar", success: "{manager} falou por dez minutos. Você saiu com duas coisas concretas para mudar." },
    explain: { label: "Explicar os atrasos e as faltas", success: "{manager} ouviu. A advertência continua, mas a conversa terminou num tom melhor.", failure: "{manager} disse que explicação não muda o que aconteceu." },
  },
} as const

export const interviewTexts = {
  intro: {
    atendimento: "{manager} atendeu você numa mesinha do salão e perguntou como você lidaria com um cliente irritado.",
    operacao: "{manager} mostrou o depósito e perguntou se você já trabalhou com contagem e carga.",
    escritorio: "{manager} abriu seu currículo na tela e perguntou como você organiza o próprio trabalho.",
  },
  internal: "{manager} fez a entrevista do processo interno para {role} na sala de sempre, mas com outro tom.",
  choices: {
    experience: { label: "Falar da experiência que você tem", success: "Você deu exemplos concretos. {manager} anotou dois.", failure: "Os exemplos ficaram vagos." },
    motivation: { label: "Contar por que quer esta vaga", success: "Você falou do bairro, da mudança e do que quer construir. Pareceu verdade porque era.", failure: "A resposta saiu decorada." },
    course: { label: "Mostrar o que aprendeu no curso", success: "Você citou o curso e explicou como aplicaria. {manager} se interessou.", failure: "{manager} perguntou um detalhe do curso e você não soube responder." },
    team: { label: "Perguntar sobre a equipe", success: "{manager} falou da equipe com gosto. A conversa ficou mais leve.", failure: "A pergunta ficou sem espaço; {manager} já estava olhando o relógio." },
  },
  scheduled: "{company} chamou você para uma entrevista {when}.",
  canceled: "{company} avisou que a vaga foi preenchida antes da sua entrevista.",
  missed: "Você não apareceu na entrevista da {company}. A vaga seguiu sem você.",
  passed: "{company} ligou: a vaga de {role} é sua. A presença passa a ser cobrada em {start}.",
  failed: "{company} ligou para agradecer. Escolheram outra pessoa para {role}.",
  promoted: "Promoção: a partir de agora você é {role} na {company}.",
  notPromoted: "O processo interno para {role} ficou com outra pessoa. {manager} disse que sua hora vai chegar.",
} as const

const PLACEHOLDER = /\{([a-zA-Z]+)\}/g
const WORK_KEYS = new Set(["coworker", "manager", "company", "role", "task", "due", "count", "percent", "missing", "when", "start"])
export function validateWorkContent(roleIds: readonly string[]): string[] {
  const errors: string[] = []
  const walk = (value: unknown, path: string): void => {
    if (typeof value === "string") {
      for (const m of value.matchAll(PLACEHOLDER)) if (!WORK_KEYS.has(m[1]!)) errors.push(`Placeholder desconhecido {${m[1]}} em ${path}.`)
      if (!value.trim()) errors.push(`Texto vazio em ${path}.`)
    } else if (Array.isArray(value)) value.forEach((v, i) => walk(v, `${path}[${i}]`))
    else if (value && typeof value === "object") for (const [k, v] of Object.entries(value)) walk(v, `${path}.${k}`)
  }
  walk(workSituations, "workSituations"); walk(assignmentTemplates, "assignmentTemplates"); walk(reviewTexts, "reviewTexts"); walk(interviewTexts, "interviewTexts")
  const ids = new Set<string>()
  for (const s of workSituations) {
    if (ids.has(s.id)) errors.push(`Situação duplicada: ${s.id}.`)
    ids.add(s.id)
    if (s.choices.length < 2 || s.choices.length > 3) errors.push(`Situação ${s.id} precisa de 2 ou 3 escolhas.`)
    if (s.text.includes("{coworker}") && s.actor !== "coworker" && !s.choices.length) errors.push(`Situação ${s.id} cita colega sem ator.`)
    for (const ch of s.choices) {
      if (ch.difficulty !== undefined && (ch.difficulty < 0 || ch.difficulty > 1 || !ch.failure)) errors.push(`Escolha ${s.id}/${ch.id} com risco precisa de dificuldade 0–1 e desfecho de falha.`)
      if (ch.minutes !== undefined && (!Number.isInteger(ch.minutes) || ch.minutes < 0 || ch.minutes > 120)) errors.push(`Escolha ${s.id}/${ch.id} com tempo inválido.`)
    }
  }
  for (const [id, career] of Object.entries(roleCareer)) {
    if (!roleIds.includes(id)) errors.push(`Carreira de função inexistente: ${id}.`)
    if (career.next && !roleIds.includes(career.next)) errors.push(`Próximo degrau inexistente: ${career.next}.`)
  }
  for (const id of roleIds) if (!roleCareer[id]) errors.push(`Função sem família: ${id}.`)
  const families: RoleFamily[] = ["atendimento", "operacao", "escritorio"]
  for (const f of families) if (workSituations.filter(s => s.family === f).length < 6) errors.push(`Poucas situações para ${f}.`)
  return errors
}
