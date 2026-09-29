PARALELO
MASTER DESIGN BIBLE
Simulador de vida textual sistêmico, mobile-first,
com mundo persistente e identidade editorial.
STATUS
Direção de produto v1.0

DOCUMENTO
Produto • Game Design • UX • UI • Escrita • Arquitetura

TÍTULO
PARALELO é um nome de trabalho e pode ser substituído


UMA VIDA. MUITAS HISTÓRIAS. O MUNDO CONTINUA.
CONTEÚDO
Guia de navegação por produto, sistemas, identidade e implementação.
0. Como usar este documento
1. Resumo executivo
2. Manifesto de design
3. Anti-clone: como ser muito melhor que BitLife sem copiar BitLife
4. O princípio mais importante: simulação primeiro
5. Estrutura de experiência
6. A Timeline: o coração do jogo
7. Como apresentar escolhas
8. Personagens e identidade
9. Personalidade
10. Memória
11. Relações
12. Conversas e mensagens
13. Objetivos e IA de NPCs
14. Tempo e ritmo
15. Trabalho e carreira
16. Educação e habilidades
17. Dinheiro, dívida e patrimônio
18. Moradia e cidade sem mapa 2D
19. Economia e sociedade
20. Notícias
21. Saúde e bem-estar
22. Família, gerações e legado
23. Crime, reputação e instituições: módulos futuros
24. Motor de eventos
25. Conteúdo e escrita
26. Bíblia de tom para diálogos
27. Direção visual: editorial, não dashboard
28. Sistema visual proposto
29. Componentes de UI
30. Layout das telas principais
31. Regra anti-cara-de-IA
32. Anti-cara-de-IA na escrita
33. Som, feedback e movimento
34. Acessibilidade
35. Stack técnica recomendada
36. Arquitetura de software
37. Modelo de dados
38. Determinismo
39. Escala de simulação
40. Save, banco e migrações
41. Conteúdo data-driven
42. Ferramentas internas obrigatórias
43. Testes
44. Performance
45. Exemplo de cadeia emergente
46. Exemplo de sessão
47. Direção de onboarding
48. Escopo do primeiro vertical slice
49. Roadmap
50. Regras para Claude Code
51. Padrão de especificação de feature
52. Critérios de qualidade de uma feature
53. Como revisar uma tela antes de aprovar
54. Como revisar um evento antes de aprovar
55. Guardrails de conteúdo procedimental
56. Monetização e produto
57. Nome, marca e identidade
58. Design tokens iniciais
59. Exemplo de Home em texto
60. Exemplo de pessoa
61. Exemplo de carreira
62. Exemplo de dinheiro
63. Exemplo de Mundo
64. Mapa de causalidade do produto
65. O que cortar quando o projeto ficar grande demais
66. Definition of Done global
67. Prompt de partida para Claude
68. Conclusão
69. Gramática autoral de layout
70. Design fingerprints: como o jogo deve ser reconhecido sem o logo
71. Estados vazios, loading e erro
72. Responsividade
73. Biblioteca de microcopy
74. Vocabulário proibido ou restrito
75. Padrões de informação por domínio
76. Sistema de capítulos de vida
77. Retrospectiva anual
78. Sistema de causas
79. Conhecimento e crenças
80. Repositório recomendado
81. Convenções TypeScript
82. Observabilidade
83. Balanceamento sistêmico
84. Checklist final de autoria

# 0. Como usar este documento
Este documento é a fonte de verdade para o projeto, com o título de trabalho PARALELO. O nome pode mudar sem alterar a direção de produto.
Ele foi escrito para orientar simultaneamente produto, game design, UX, UI, narrativa sistêmica, conteúdo, arquitetura de software, QA e implementação por agentes como Claude Code.
A regra de prioridade é:
1. Princípios inegociáveis deste documento.
2. Decisões explícitas mais recentes do dono do projeto.
3. Arquitetura e contratos de sistemas.
4. Especificações de features.
5. Preferências locais de implementação.
Se uma implementação contradizer um princípio central para economizar tempo, a implementação está errada. Se duas seções entrarem em conflito, Claude deve registrar a contradição antes de escolher uma solução.

### O que este jogo não é
- Não é um clone de BitLife.
- Não é uma coleção de pop-ups aleatórios.
- Não é um dashboard de barras de status.
- Não é um RPG de texto com uma história fixa.
- Não é um chatbot disfarçado de jogo.
- Não é um produto que depende de IA generativa em tempo de execução.
- Não é uma simulação gráfica do cotidiano.

### O que este jogo é
Um simulador de vida textual sistêmico no qual uma pessoa existe dentro de uma sociedade persistente. Pessoas, empresas, famílias, relações, empregos, dívidas, oportunidades, crises e notícias continuam evoluindo mesmo quando o jogador não está olhando para elas.
O texto é a janela para a simulação. O texto não substitui a simulação.

# 1. Resumo executivo
PARALELO deve ser pensado como um simulador de vida com profundidade de management game e apresentação editorial.
A ambição é responder à pergunta:
E se um jogo de vida mobile tratasse cada pessoa, trabalho, relação e decisão como parte do mesmo mundo, em vez de como eventos isolados?
O jogador acompanha sua vida por uma timeline. Ele observa acontecimentos, toma decisões e navega por cinco áreas principais: Vida, Pessoas, Carreira, Dinheiro e Mundo.
Por baixo dessa interface existem sistemas conectados:
- identidade;
- personalidade;
- necessidades;
- humor e stress;
- memória;
- relações;
- família;
- educação;
- habilidades;
- trabalho;
- empresas;
- renda e despesas;
- patrimônio;
- moradia;
- reputação;
- saúde;
- instituições;
- notícias;
- eventos;
- objetivos;
- informação conhecida por cada personagem;
- histórico de vida.
O jogo deve conseguir explicar consequências. Se o jogador for demitido, existe uma causa. Se um relacionamento termina, existe uma história. Se uma empresa fecha, funcionários perdem renda e isso pode alterar famílias inteiras.
A meta não é simular fisicamente cada minuto. A meta é simular decisões, vínculos, recursos e consequências em resolução suficiente para produzir histórias plausíveis.

### Promessa central
Uma vida. Milhares de histórias. Um mundo que continua.

### Frase de produto
Um simulador de vida em que o mundo não existe para servir ao jogador.

### Diferencial competitivo
A profundidade surge de quatro elementos:
1. NPCs com continuidade.
2. Causas e consequências rastreáveis.
3. Sistemas que realmente interagem.
4. Uma apresentação adulta, editorial e intencional.

# 2. Manifesto de design

### 2.1 O mundo não espera
A mãe do jogador continua envelhecendo. O amigo pode conseguir outro emprego. O ex pode entrar em uma nova relação. Uma empresa pode crescer sem qualquer participação do jogador.
A sensação fundamental deve ser: eu moro aqui, não sou o centro do universo.

### 2.2 O jogo prefere consequências a recompensas
Ações não existem apenas para aumentar um número.
Aceitar um emprego significa:
- renda;
- agenda;
- colegas;
- chefe;
- deslocamento abstrato;
- stress;
- experiência;
- oportunidades;
- menos tempo para outras relações.
Toda escolha importante deve criar algum custo de oportunidade.

### 2.3 O jogador deve entender o suficiente, não tudo
Informações objetivas como salário, dinheiro e dívida podem ser exatas.
Informações humanas não precisam ser reduzidas a um número explícito. O jogador não vê "amor 82". Ele percebe a relação por comportamento, histórico, descrições e sinais.

### 2.4 Falhar cria história
Demissão, término, dívida, reprovação, briga ou uma oportunidade perdida não devem automaticamente significar fracasso de campanha. São mudanças de trajetória.

### 2.5 O mundo precisa lembrar
Memória é um dos pilares do jogo.
Um personagem pode lembrar:
- promessa quebrada;
- ajuda financeira;
- discussão;
- aniversário esquecido;
- indicação profissional;
- traição;
- cuidado em uma crise;
- humilhação pública;
- conquista compartilhada.
A intensidade, a recência e a relevância dessas memórias alteram comportamento.

### 2.6 O jogo deve produzir histórias que o designer não escreveu literalmente
Conteúdo autoral fornece situações, vozes, opções e regras. A combinação entre estado do mundo, relações, contexto e eventos deve produzir histórias emergentes.

### 2.7 A complexidade interna deve resultar em clareza externa
Se o jogador precisar ler uma planilha para entender sua vida, a interface falhou.
A UI apresenta:
- o que aconteceu;
- por que provavelmente aconteceu;
- o que mudou;
- o que pode ser feito agora.

### 2.8 Não gamificar tudo
Nem toda relação precisa de barra.
Nem toda atividade precisa de XP.
Nem toda escolha precisa de recompensa visível.
Nem todo problema precisa virar missão.
A vida é interessante porque objetivos competem entre si.

# 3. Anti-clone: como ser muito melhor que BitLife sem copiar BitLife
BitLife pode ser usado apenas como referência de uma categoria: vida em formato textual e mobile. A direção de PARALELO deve divergir deliberadamente em estrutura, linguagem e sistemas.

### Evitar
- idade avançando por um único botão como eixo principal de toda experiência;
- sequência de pop-ups independentes;
- estatísticas humanas resumidas a quatro barras;
- emojis como identidade visual;
- eventos que existem sem causa;
- NPCs descartáveis;
- relacionamentos que só avançam pela repetição de uma mesma ação;
- dezenas de ações equivalentes em listas gigantes;
- humor puramente absurdo como personalidade padrão;
- menus que parecem um app utilitário.

### Adotar
- timeline contínua;
- calendário e agenda;
- contexto antes da escolha;
- consequências persistentes;
- pessoas com histórico;
- ações desbloqueadas pelo contexto;
- sistemas que geram acontecimentos;
- notícias do mundo;
- empresas e instituições persistentes;
- relações multidimensionais;
- texto editorial;
- decisões sem resposta obviamente "certa".

### Regra de teste
Se uma feature puder ser descrita como "a mesma coisa que BitLife, só com mais opções", ela ainda não está suficientemente diferenciada.
A pergunta correta é:
Que estado persistente e quais relações entre sistemas tornam esta feature possível?

# 4. O princípio mais importante: simulação primeiro
A fonte de verdade nunca é a tela.
Exemplo incorreto:
onPress={() => {
  player.cash += 1000
  setToast("Você recebeu R$ 1.000")
}}
Exemplo correto:
dispatch({
  type: "accept_job_offer",
  actorId: playerId,
  offerId
})
O motor:
1. valida se a oferta ainda existe;
2. valida pré-requisitos;
3. encerra emprego incompatível quando aplicável;
4. cria vínculo empregatício;
5. agenda o trabalho;
6. registra memória;
7. atualiza rede profissional;
8. emite fatos do domínio;
9. atualiza as consultas usadas pela UI.
A interface apenas mostra o resultado.

### Consequência dessa regra
O jogo deve poder rodar sem tela.
Um teste pode fazer:
const world = makeWorld({ seed: 483911 })
advanceWorld(world, { years: 5 })
expect(validateWorld(world)).toEqual([])
Isso torna o projeto muito mais fácil de:
- testar;
- balancear;
- escalar;
- refatorar;
- programar com Claude;
- portar para outras interfaces.

# 5. Estrutura de experiência

## 5.1 As cinco áreas principais

### VIDA
A tela inicial.
Mostra:
- data e fase da vida;
- timeline;
- estado atual em linguagem humana;
- compromissos próximos;
- decisões pendentes;
- prioridades;
- acontecimentos pessoais.

### PESSOAS
Mostra:
- família;
- amizades;
- relações românticas;
- trabalho;
- conhecidos;
- histórico social;
- conversas;
- pessoas distantes ou perdidas de vista.

### CARREIRA
Inclui:
- trabalho;
- desempenho;
- agenda;
- educação;
- qualificações;
- habilidades;
- oportunidades;
- histórico profissional.

### DINHEIRO
Inclui:
- caixa;
- contas;
- renda;
- despesas;
- compromissos;
- dívidas;
- patrimônio;
- moradia;
- histórico financeiro.

### MUNDO
Inclui:
- notícias;
- empresas;
- instituições;
- indicadores relevantes;
- oportunidades públicas;
- acontecimentos da cidade;
- contexto econômico.

## 5.2 Navegação
A navegação principal deve caber em cinco destinos.
Evitar uma barra com:
Inventário | Habilidades | Relações | Trabalho | Mapa | Objetivos | Notícias | Configurações.
O jogo textual deve parecer seguro de sua própria hierarquia.

## 5.3 Hierarquia
O jogador entra para saber:
1. o que mudou;
2. o que merece atenção;
3. que escolhas estão abertas;
4. o que está planejado;
5. como sua vida está evoluindo.
Todos os outros detalhes ficam progressivamente acessíveis.

# 6. A Timeline: o coração do jogo
A timeline é a principal superfície narrativa.
Ela substitui a sensação de "menu de eventos" por uma sensação de vida acontecendo.
Exemplo:
SEGUNDA, 8 DE MARÇO

07:34
Você acordou mais cansado que o normal.

08:16
O ônibus atrasou.

09:04
Você chegou ao trabalho depois do horário.

11:42
Rodrigo chamou você para almoçar.

13:08
Ele contou que pretende pedir demissão.

17:27
Seu chefe pediu para conversar amanhã.

19:14
Sua mãe ligou.

22:36
Marina perguntou se está tudo bem entre vocês.

### 6.1 Tipos de entrada
- acontecimento automático;
- consequência de ação;
- mensagem;
- compromisso;
- notícia pessoal;
- oportunidade;
- mudança de status;
- observação;
- evento que exige decisão.

### 6.2 Peso editorial
Nem tudo merece o mesmo destaque.
Níveis:
Ruído
Acontecimentos quase decorativos. Podem ser resumidos.
Cotidiano
Ajuda a construir continuidade.
Relevante
Pode alterar planos.
Importante
Afeta relações, carreira, dinheiro ou vida.
Marco
Eventos que definem capítulos da vida.

### 6.3 Agrupamento
Ao acelerar o tempo, o jogo não deve despejar 80 notificações.
Pode resumir:
Esta semana você trabalhou além do horário três vezes. Quase não viu Marina e cancelou um encontro com Rodrigo.
O resumo precisa derivar de fatos reais do período.

### 6.4 Histórico
Entradas importantes podem ser revisitadas anos depois.
O jogo deve ser capaz de responder:
- quando conheci esta pessoa?
- quando comecei neste trabalho?
- quando minha situação financeira mudou?
- quais acontecimentos levaram a este término?

# 7. Como apresentar escolhas
Escolhas devem parecer ações possíveis dentro de uma situação, não perguntas de quiz.

### Ruim
Seu chefe está bravo.

A) Pedir desculpas
B) Gritar
C) Ignorar

### Melhor
Seu chefe pediu para falar com você às 16h.

Nas últimas duas semanas, você chegou atrasado quatro vezes.
Sua avaliação mais recente também caiu.

Preparar o que vai dizer
Pedir orientação a Camila
Entrar na reunião sem se preparar
Depois da reunião, novas ações podem surgir.

### 7.1 Sem opção obviamente ótima
Toda escolha importante deve ter:
- custo;
- risco;
- oportunidade;
- efeito de personalidade;
- efeito social;
- efeito de tempo.

### 7.2 Nem sempre revelar probabilidade
O jogo pode dizer:
- provável;
- arriscado;
- difícil;
- você se sente preparado.
Evitar transformar a vida em porcentagens expostas.

### 7.3 Opções contextuais
A lista de ações de uma pessoa depende de:
- relação;
- situação;
- lugar;
- agenda;
- memórias;
- fase da vida.
Não mostrar permanentemente quarenta verbos iguais.

# 8. Personagens e identidade
Cada personagem relevante é uma entidade persistente.
Campos essenciais:
- ID estável;
- nome;
- nascimento;
- família;
- residência;
- trabalho/estudo;
- situação financeira;
- personalidade;
- habilidades;
- relações;
- memórias;
- objetivos;
- conhecimento;
- agenda;
- histórico;
- estado emocional;
- condições temporárias.

### 8.1 Não expor a ficha inteira
O jogador não deve ver:
Empatia 73
Ciúme 42
Ambição 82
Ele pode perceber:
Como você a enxerga
- muito ambiciosa;
- reservada;
- costuma cumprir o que promete;
- se fecha quando está sob pressão.
Essas descrições são inferidas de comportamento e conhecimento do jogador.

### 8.2 Informação imperfeita
O jogador não possui acesso divino à vida de todo mundo.
Uma pessoa pode:
- esconder que pretende pedir demissão;
- mentir;
- omitir uma dívida;
- contar algo a um amigo;
- descobrir informação por terceiros.
O jogo precisa diferenciar:
- fato do mundo;
- fato conhecido pelo jogador;
- crença de um NPC;
- rumor.

# 9. Personalidade
Personalidade influencia decisões, mas não determina comportamento rigidamente.
Dimensões iniciais possíveis:
- sociabilidade;
- disciplina;
- empatia;
- ambição;
- tolerância a risco;
- impulsividade;
- paciência;
- materialismo;
- franqueza;
- estabilidade emocional.

### 9.1 Regra
Traços são modificadores, não scripts.
Uma pessoa impulsiva pode agir com cautela quando:
- o risco é enorme;
- existe uma memória traumática;
- há pressão familiar;
- o objetivo em jogo é importante.

### 9.2 Mudança lenta
Parte da personalidade pode mudar ao longo de anos e experiências, mas não como XP.

### 9.3 Voz comportamental
Personalidade também afeta:
- que assuntos uma pessoa inicia;
- quanto ela revela;
- como pede ajuda;
- como reage a conflito;
- quão rápido perdoa;
- que oportunidades considera.

# 10. Memória
Memória é um sistema estrutural.
Uma memória contém:
type Memory = {
  id: MemoryId
  ownerId: PersonId
  participants: PersonId[]
  kind: MemoryKind
  occurredAt: GameDate
  emotionalValence: number
  intensity: number
  salience: number
  reliability: number
  causeIds: string[]
  tags: string[]
}

### 10.1 O que vira memória
Não registrar tudo.
Pontuação de relevância pode considerar:
- emoção;
- novidade;
- impacto em objetivo;
- impacto financeiro;
- importância da pessoa;
- quebra de expectativa;
- consequência futura.

### 10.2 Decaimento
Memória não precisa desaparecer binariamente.
Pode:
- perder precisão;
- perder intensidade;
- ser reforçada;
- ser reinterpretada por novos acontecimentos.

### 10.3 Memórias sociais
Exemplos:
- foi apoiado quando perdeu o emprego;
- recebeu dinheiro;
- teve segredo exposto;
- promessa cumprida;
- foi ignorado em momento importante;
- recebeu indicação;
- foi defendido em público.

### 10.4 O jogador não vê banco de dados de memórias
A interface mostra uma narrativa:
Momentos que marcaram a relação
- Você a apoiou quando ela mudou de carreira.
- Uma discussão sobre dinheiro ainda pesa entre vocês.
- Ela se lembra de quando você faltou à formatura.

# 11. Relações
Relacionamentos são arestas persistentes entre personagens.
Dimensões possíveis:
- familiaridade;
- afeto;
- confiança;
- respeito;
- atração;
- intimidade;
- ressentimento;
- dependência;
- tensão.

### 11.1 Rótulos não substituem estado
"Amigo", "colega" ou "namorado" é uma categoria social. Não explica sozinho a qualidade da relação.
É possível:
- amar alguém e não confiar;
- respeitar alguém de quem não gosta;
- estar em um relacionamento com alta tensão;
- ser amigo de infância com pouco contato recente.

### 11.2 Evolução
Relações mudam por:
- tempo;
- convivência;
- compatibilidade;
- escolhas;
- conflitos;
- promessas;
- apoio;
- distância;
- terceiros;
- grandes eventos.

### 11.3 Evitar grind social
O jogador não deve precisar apertar "elogiar" dez vezes para subir afinidade.
Ações repetidas têm retornos decrescentes ou podem soar artificiais.

### 11.4 Relações triangulares
O sistema deve permitir que:
- A conhece B;
- B conhece C;
- C tem opinião sobre A por histórias de B;
- uma decisão afeta grupos.
Isso produz sociedade, não apenas pares isolados.

# 12. Conversas e mensagens
O jogo não precisa simular chat livre por IA generativa.
Conversas podem ser construídas com:
- intenções;
- tópicos;
- contexto;
- texto autoral parametrizado;
- escolhas.

### 12.1 Intenções
Exemplos:
- pedir ajuda;
- convidar;
- confrontar;
- contar novidade;
- pedir conselho;
- pedir dinheiro;
- pedir indicação;
- terminar relação;
- fazer as pazes.

### 12.2 Mensagens
Mensagens criam ritmo cotidiano.
Exemplo:
Marina
22:36

Tá tudo bem com a gente?
Você anda distante faz dias.
Ações:
- responder agora;
- dizer que conversa amanhã;
- ligar;
- não responder.
O silêncio também é ação e pode gerar memória.

### 12.3 Escrita
As pessoas não devem soar iguais.
Variações devem depender de:
- idade;
- intimidade;
- personalidade;
- contexto;
- estado emocional.
Não exagerar em bordões artificiais para "provar" personalidade.

# 13. Objetivos e IA de NPCs
NPCs importantes possuem objetivos.
Exemplos:
- encontrar emprego;
- economizar;
- mudar de casa;
- terminar formação;
- melhorar relação;
- ter filho;
- evitar dívida;
- buscar status;
- sair da cidade.
Cada objetivo tem:
- prioridade;
- prazo;
- progresso;
- alternativas;
- custo;
- condições de abandono.

### 13.1 Utility AI
Ações são pontuadas por contexto.
score =
urgência
x personalidade
x oportunidade
x recursos
x relação
x objetivo
x contexto
+ pequena incerteza

### 13.2 Inércia
Sem inércia, NPCs oscilam.
Incluir:
- compromisso;
- custo de mudança;
- cooldown;
- preferência por continuidade.

### 13.3 Explicabilidade de desenvolvimento
No modo debug, Claude/desenvolvedor deve poder inspecionar:
OBJETIVO: procurar emprego
Prioridade: 0,82

AÇÕES
candidatar-se à Nexo        0,71
pedir indicação à Helena    0,84  <- escolhida
esperar uma semana          0,22
Sem inspector de IA, balancear o sistema será um pesadelo.

# 14. Tempo e ritmo
O tempo é parte central, mas não deve ser um botão de "envelhecer".

### 14.1 Camadas
- minutos/horas para compromissos;
- dias para rotina;
- semanas para planejamento;
- meses para finanças;
- anos para trajetória.

### 14.2 Velocidades
- pausado;
- normal;
- rápido;
- avançar até próximo evento relevante.

### 14.3 Skip inteligente
O jogador pode selecionar:
Avançar até
- amanhã;
- próximo compromisso;
- próxima decisão;
- próximo pagamento;
- fim de semana.
O motor processa o período e a timeline resume o que não merece interrupção.

### 14.4 Tempo não é renderização
Resultados nunca dependem de FPS.

# 15. Trabalho e carreira
Carreira deve ser um dos sistemas mais profundos.

### 15.1 Empresas persistentes
Empresa possui:
- setor;
- tamanho;
- saúde financeira;
- cultura abstrata;
- reputação;
- salários;
- quadro;
- vagas;
- localização;
- líderes relevantes.

### 15.2 Vagas existem no mundo
Uma vaga é criada por:
- expansão;
- saída de funcionário;
- substituição;
- nova equipe;
- crescimento do setor.
Ela não surge apenas porque o jogador abriu a aba Carreira.

### 15.3 Seleção
Fatores:
- formação;
- experiência;
- habilidades;
- indicação;
- reputação;
- entrevista;
- mercado;
- ajuste salarial;
- competição.

### 15.4 Desempenho
Depende de:
- habilidade;
- energia;
- stress;
- presença;
- dificuldade;
- relação com equipe;
- contexto da empresa.

### 15.5 Promoção
Não é um medidor linear.
Requer:
- oportunidade;
- desempenho;
- confiança;
- experiência;
- habilidade;
- apoio;
- contexto financeiro.

### 15.6 Demissão
Pode ocorrer por:
- desempenho;
- falta grave;
- reestruturação;
- crise;
- conflito;
- redundância.
O jogo deve indicar sinais quando plausível, sem garantir antecipação.

### 15.7 Rede profissional
Colegas podem:
- indicar;
- avisar sobre vaga;
- falar bem;
- bloquear;
- recrutar;
- sair e reaparecer anos depois.

# 16. Educação e habilidades
Educação deve alterar possibilidades reais.

### 16.1 Formação
Instituições e cursos possuem:
- duração;
- custo;
- horários;
- reputação;
- pré-requisitos;
- habilidades;
- credencial.

### 16.2 Estudo
Estudar compete com:
- trabalho;
- sono;
- relações;
- lazer.

### 16.3 Habilidades
Evitar árvore gamificada gigante.
Habilidades podem ser:
- discretas;
- parcialmente observáveis;
- ligadas a prática e experiência.
Exemplos:
- comunicação;
- escrita;
- análise;
- tecnologia;
- liderança;
- negociação;
- culinária;
- direção.

### 16.4 Proficiência
A UI pode usar:
- iniciante;
- competente;
- avançado;
- especialista;
em vez de exibir 73/100 sempre.

# 17. Dinheiro, dívida e patrimônio
O dinheiro precisa ser concreto.
Exibir valores reais da moeda do mundo do jogo.

### 17.1 Ledger
Toda mudança relevante gera transação:
{
  amount: -1850,
  category: "rent",
  date: "2028-04-05",
  causeId: "lease_44"
}

### 17.2 Renda
- salário;
- trabalho temporário;
- negócio;
- benefícios quando existirem;
- venda;
- rendimentos futuros.

### 17.3 Despesas
- moradia;
- alimentação;
- transporte;
- saúde;
- educação;
- lazer;
- dívida;
- família.
Não simular cada café se isso não cria gameplay. Categorias podem agregar rotina.

### 17.4 Dívida
Dívida deve criar pressão sem transformar uma falha em espiral inevitável.
Rotas de recuperação:
- renegociação;
- mudança de moradia;
- emprego temporário;
- ajuda familiar;
- venda de ativo;
- corte de gastos.

### 17.5 Informação visual
Dinheiro é uma das áreas onde números exatos fazem sentido.
A tela deve privilegiar:
- saldo;
- fluxo do mês;
- compromissos próximos;
- tendência;
- riscos.

# 18. Moradia e cidade sem mapa 2D
Mesmo sem um mapa gráfico, cidade e localização importam.

### 18.1 Estrutura abstrata
Cidade
  -> bairros
      -> propriedades
      -> empresas
      -> instituições

### 18.2 Moradia
Variáveis:
- custo;
- tamanho;
- qualidade;
- segurança percebida;
- acesso a transporte;
- proximidade de trabalho/família;
- prestígio.

### 18.3 Deslocamento
Calcular:
- tempo;
- custo;
- confiabilidade;
- stress.
Não animar ônibus andando.

### 18.4 Mudança
Mudar de casa pode alterar:
- orçamento;
- tempo disponível;
- contato com família;
- acesso a oportunidades;
- satisfação.

### 18.5 Apresentação
A UI pode dizer:
Centro
Apartamento de 1 quarto
25 min do trabalho
Próximo da universidade
Aluguel: R$ 2.450
Sem precisar mostrar um mapa jogável.

# 19. Economia e sociedade
O mundo precisa ser suficientemente sistêmico para afetar vidas.

### 19.1 Indicadores
Começar simples:
- desemprego;
- inflação;
- pressão de aluguel;
- saúde por setor;
- salário de referência.

### 19.2 Empresas
Empresas contratam, crescem, congelam vagas, reestruturam e fecham.

### 19.3 Transmissão de efeitos
Exemplo:
queda no setor
-> empresa reduz receita
-> congelamento
-> demissões
-> queda de renda familiar
-> atraso em contas
-> stress
-> conflitos
-> mudança de moradia

### 19.4 Evitar falso realismo
O objetivo é gerar decisões e histórias coerentes, não replicar uma economia nacional com precisão acadêmica.

### 19.5 Mundo legível
Notícias e telas devem explicar tendências sem exigir gráficos complexos.

# 20. Notícias
A aba Mundo transforma estado sistêmico em narrativa pública.
Exemplos:
Nexo anuncia corte de 8% do quadro
Aluguéis sobem pelo quarto mês no Centro
Hospital Santa Clara abre 120 vagas
Universidade reduz bolsas para o próximo semestre

### 20.1 Notícias são derivadas de fatos
Não inventar uma notícia aleatória que não tenha efeito.
Uma notícia pode ser:
- consequência real;
- sinal de oportunidade;
- contexto;
- antecipação de risco.

### 20.2 Relevância pessoal
O jogador pode receber destaque quando:
- trabalha na empresa;
- mora no bairro;
- conhece envolvidos;
- atua no setor.

### 20.3 Informação parcial
A notícia representa o que é público, não a verdade absoluta de todos os bastidores.

# 21. Saúde e bem-estar
Saúde deve ser tratada com cuidado e utilidade de gameplay.

### 21.1 Estados
Evitar transformar saúde inteira em uma barra.
Categorias:
- condição geral;
- energia;
- sono;
- stress;
- condições temporárias;
- condições persistentes se incluídas.

### 21.2 Causalidade
Riscos podem depender de:
- idade;
- histórico;
- rotina;
- ambiente;
- acaso.

### 21.3 Sem punição aleatória opaca
Grandes acontecimentos de saúde precisam de contexto e feedback adequados.

### 21.4 Representação responsável
Não usar doenças reais como piada ou simples debuff sem consideração.

# 22. Família, gerações e legado
O sistema deve permitir campanha longa.

### 22.1 Família
Grafo:
- pais;
- filhos;
- irmãos;
- parceiros;
- ex-parceiros;
- avós.

### 22.2 Mudança geracional
Nascimento, envelhecimento, saída de casa, casamento e morte alteram a rede.

### 22.3 Legado
Quando um personagem morre, o mundo continua.
Possibilidades futuras:
- continuar como descendente;
- observar legado;
- rever vida;
- preservar história familiar.

### 22.4 Histórico
O jogo deve ser capaz de gerar uma retrospectiva baseada em fatos, não em texto genérico.

# 23. Crime, reputação e instituições: módulos futuros
Esses sistemas devem ser modulares e não bloquear o núcleo.

### Crime/legal
Possíveis elementos:
- ação ilegal;
- risco;
- testemunhas;
- evidência;
- consequência;
- processo;
- registro.

### Reputação
Reputação não é um único número global.
Pode existir por:
- empresa;
- círculo social;
- setor;
- comunidade.

### Instituições
Empresas, escolas, hospitais e órgãos podem ter regras próprias.

### Regra de escopo
Não implementar sistemas avançados antes de:
- pessoas;
- relações;
- trabalho;
- dinheiro;
- eventos;
- save/load;
estarem sólidos.

# 24. Motor de eventos
O motor de eventos deve escalar para milhares de situações sem um script por evento.

### 24.1 Definição
{
  "id": "career.manager_requests_meeting.001",
  "category": "career",
  "trigger": "performance_concern",
  "conditions": [
    {"type": "employment_active"},
    {"type": "performance_below", "value": 0.35}
  ],
  "cooldownDays": 60,
  "choices": [
    {
      "id": "prepare",
      "effects": [
        {"type": "schedule_action", "action": "prepare_for_meeting"}
      ]
    }
  ]
}

### 24.2 Eventos não devem conter lógica arbitrária
Eles usam primitivas aprovadas:
- adicionar memória;
- agendar;
- alterar relação;
- criar transação;
- criar objetivo;
- abrir oportunidade;
- registrar fato.

### 24.3 Tipos
- sistêmico;
- reativo;
- oportunidade;
- cadeia;
- marco;
- ambiente.

### 24.4 Orçamento de atenção
O jogo deve limitar interrupções.
Um dia pode ter dezenas de fatos e apenas dois merecerem uma decisão explícita.

### 24.5 Eventos com continuidade
Uma escolha pode voltar meses depois porque:
- alguém lembra;
- uma dívida vence;
- uma promessa não foi cumprida;
- uma indicação gera entrevista.

# 25. Conteúdo e escrita
A escrita é parte da identidade do jogo.

### 25.1 Princípios
- concreta;
- econômica;
- observacional;
- humana;
- sem exagero;
- sem moralizar a escolha;
- sem explicar sentimento que poderia ser mostrado por contexto.

### 25.2 Evitar voz de IA
Não usar em excesso:
- "Em um mundo onde...";
- "cada escolha importa";
- "uma jornada única";
- "moldar seu destino";
- "navegue pelas complexidades";
- "desvende";
- "prepare-se para";
- "não é apenas X, é Y";
- frases de marketing dentro da narrativa.

### 25.3 Evitar simetria artificial
Texto de IA frequentemente organiza tudo em pares ou tríades perfeitas.
Pessoas não falam assim o tempo todo.

### 25.4 Evitar explicação redundante
Ruim:
Marina parece chateada. Ela está chateada porque você não respondeu.
Melhor:
Marina viu sua mensagem às 18:12. Desde então, não respondeu.

### 25.5 Específico vence genérico
Ruim:
O trabalho tem sido estressante.
Melhor:
Você saiu depois das 20h pela terceira vez nesta semana.

### 25.6 Variedade de comprimento
Nem toda entrada deve ser um parágrafo de três linhas.
Misturar:
- uma frase;
- duas frases;
- diálogo;
- bloco factual;
- notícia;
- silêncio.

### 25.7 Não transformar tudo em lore
O cotidiano dá credibilidade aos grandes momentos.

# 26. Bíblia de tom para diálogos

### 26.1 Pessoas falam como pessoas
Uma mãe, um colega recém-conhecido e um parceiro de cinco anos não usam a mesma distância.

### 26.2 Subtexto
Nem toda emoção é explicitada.
Em vez de:
Estou ressentida porque você não foi ao meu aniversário.
Pode aparecer:
Relaxa. Você devia estar ocupado.
O sistema sabe que existe ressentimento; o texto não precisa declarar a variável.

### 26.3 Mensagens curtas
No mobile, conversas podem usar mensagens naturais e compactas.

### 26.4 Sem falsa juventude
Evitar encher falas com gíria para parecer humano.

### 26.5 Regionalização
Se o jogo for localizado para português do Brasil, a voz deve soar brasileira, mas sem caricatura.

### 26.6 Repetição
Conteúdo recorrente precisa de:
- variantes;
- condições;
- cooldown;
- memória;
para não soar procedural.

# 27. Direção visual: editorial, não dashboard
A identidade visual deve parecer criada por um diretor de arte com opinião.

### 27.1 Conceito
Jornal íntimo + sistema operacional da vida.
A interface mistura:
- leitura editorial;
- agenda;
- arquivo pessoal;
- documentação;
- interfaces de gestão discretas.

### 27.2 O que evitar
- card em volta de toda informação;
- bordas arredondadas grandes em tudo;
- glassmorphism;
- gradientes roxo/azul;
- brilho neon;
- 3D blobs;
- emojis como ícones;
- sombras macias em toda superfície;
- dezenas de pílulas;
- ícones decorativos;
- alinhamento central excessivo;
- cards de KPI;
- barras de progresso para conceitos humanos;
- hero screens genéricas.

### 27.3 O que usar
- tipografia forte;
- linhas divisórias;
- margens consistentes;
- colunas;
- listas;
- recuos;
- blocos editoriais;
- datas;
- pequenos rótulos;
- hierarquia por tamanho/peso;
- uma cor de acento rara.

### 27.4 Sensação
Deve parecer:
- sério sem ser frio;
- adulto sem ser sisudo;
- íntimo sem ser sentimental;
- sofisticado sem ser luxuoso;
- funcional sem parecer SaaS.

# 28. Sistema visual proposto

## 28.1 Paleta
Base escura:
- Background: #111315
- Surface: #181B1E
- Surface Elevated: #202428
- Rule: #30353A
- Text Primary: #EEECE6
- Text Secondary: #A5A49F
- Text Muted: #747670
- Accent: #B8E986
- Warning: #E6B95C
- Danger: #D86A62
- Info: #7DA7D9

### Uso
A cor de acento não colore metade da interface.
Ela marca:
- seleção;
- ação principal;
- informação positiva;
- foco.

## 28.2 Tipografia
Direção preferencial:
Serif editorial para narrativa/títulos
- Newsreader ou alternativa serifada equivalente.
Sans para interface
- Inter, Source Sans 3 ou equivalente.

### Hierarquia
- Display: marcos de vida, datas especiais.
- H1: nome de tela.
- H2: seção.
- Body: narrativa.
- UI: ações, números, labels.
- Caption: metadados.

## 28.3 Raios
Não usar o mesmo raio de 16 px em tudo.
Tokens:
- 0: listas/editorial;
- 4: controles pequenos;
- 8: campos/sheets;
- 12: painéis especiais.
Cards totalmente arredondados são exceção.

## 28.4 Bordas
Linhas de 1 px têm função estrutural.
Separar conteúdo com linhas pode ser mais característico que caixas.

## 28.5 Espaçamento
Escala:
4, 8, 12, 16, 24, 32, 48.
Evitar 28 valores arbitrários.

## 28.6 Iconografia
Monocromática.
Traço simples.
Sem emojis.
Ícone existe quando acelera reconhecimento. Texto continua sendo principal.

# 29. Componentes de UI
Criar poucos componentes fortes.

### 29.1 `TimelineEntry`
Variantes:
- normal;
- pessoa;
- trabalho;
- dinheiro;
- mundo;
- decisão;
- marco.
Não precisa de card fechado. Pode ser uma coluna temporal com horário + conteúdo.

### 29.2 `DecisionBlock`
Contém:
- contexto;
- possíveis ações;
- custo visível quando conhecido;
- prazo.

### 29.3 `PersonRow`
- nome;
- relação percebida;
- última interação relevante;
- indicador textual curto.

### 29.4 `SectionHeader`
Título + ação secundária pequena.

### 29.5 `FactRow`
Label + valor factual.

### 29.6 `NarrativeState`
Exemplo:
Energia
Baixa
Sem barra obrigatória.

### 29.7 `LedgerRow`
Data, descrição, categoria, valor.

### 29.8 `NewsStory`
Manchete, resumo, relevância pessoal.

### 29.9 `BottomNav`
Cinco itens.
Sem label escondido.

### 29.10 `Sheet`
Usado para ações contextuais rápidas.
Não empilhar sheets infinitamente.

# 30. Layout das telas principais

## 30.1 VIDA
Topo:
- data;
- idade/fase;
- contexto breve.
Corpo:
- timeline;
- decisão atual;
- próximos compromissos.
Rodapé:
- navegação.

## 30.2 PESSOAS
Topo:
- busca;
- filtros mínimos.
Seções:
- próximos;
- família;
- trabalho;
- outros.
Pessoa aberta:
- nome;
- relação;
- contexto;
- histórico;
- ações.

## 30.3 CARREIRA
Blocos:
- situação atual;
- agenda;
- desempenho em linguagem;
- renda;
- pessoas;
- oportunidades;
- educação.

## 30.4 DINHEIRO
Blocos:
- saldo;
- mês atual;
- contas futuras;
- renda;
- despesas;
- dívida;
- patrimônio.

## 30.5 MUNDO
Blocos:
- manchetes;
- economia;
- empresas relevantes;
- cidade;
- oportunidades públicas.
Não tentar encaixar tudo na Home.

# 31. Regra anti-cara-de-IA
Antes de aprovar qualquer tela, aplicar este checklist.

### Reprovar se houver:
- seis ou mais cards visualmente idênticos na primeira dobra;
- gradiente decorativo sem função;
- ícones coloridos em círculos para cada seção;
- título genérico + subtítulo inspiracional;
- excesso de cantos arredondados;
- tudo centralizado;
- textos que parecem placeholder;
- quatro KPIs no topo;
- barras para atributos humanos;
- sombras idênticas em todas as superfícies;
- componentes que poderiam pertencer a um dashboard de fintech sem alteração;
- paleta roxo neon/azul por padrão;
- slogans espalhados durante gameplay;
- escolha binária em grandes botões sempre que há decisão;
- emoji como linguagem visual central.

### Aprovar quando:
- é possível reconhecer o jogo por um screenshot sem logo;
- tipografia possui papel claro;
- existe hierarquia sem depender de caixas;
- densidade é intencional;
- espaço em branco tem função;
- cada informação tem uma razão para estar na tela;
- textos parecem escritos para aquela situação;
- componentes repetidos não geram monotonia;
- números aparecem onde números são naturais;
- emoções aparecem principalmente através de comportamento e contexto.

# 32. Anti-cara-de-IA na escrita
Claude deve passar qualquer conteúdo por uma revisão específica.

### Sinais de texto sintético a remover
- mesma cadência em todos os parágrafos;
- listas de três itens em toda frase;
- excesso de dois-pontos;
- explicação do óbvio;
- "de repente" como gatilho constante;
- personagens nomeando suas emoções diretamente;
- opções perfeitamente simétricas;
- opções boas, neutras e más caricatas;
- humor que parece meme genérico;
- frases excessivamente polidas em mensagens pessoais;
- todas as falas com pontuação impecável;
- todo NPC sendo espirituoso.

### Técnica de revisão
Perguntar:
1. Esta frase contém informação que o jogador já sabe?
2. Uma pessoa real diria isso neste relacionamento?
3. Existe detalhe concreto?
4. Estou explicando uma variável em vez de dramatizá-la?
5. Outra situação do jogo poderia usar exatamente o mesmo texto?
Se a resposta 5 for sim, reescrever.

# 33. Som, feedback e movimento
Mesmo sendo textual, o jogo precisa de presença.

### 33.1 Som
Direção:
- discreta;
- tátil;
- poucos sons reconhecíveis.
Usar:
- mudança de dia;
- mensagem importante;
- dinheiro;
- decisão;
- marco;
- erro.
Evitar casino sonoro.

### 33.2 Música
Pode usar ambiente leve e pouco intrusivo.
Não deve lutar com leitura.

### 33.3 Haptics
No mobile:
- ação confirmada;
- marco;
- alerta importante.
Sem vibrar em cada toque.

### 33.4 Motion
Animações curtas:
- entrada de timeline;
- mudança de estado;
- sheet;
- transição de data.
Nada de elementos flutuando por decoração.

# 34. Acessibilidade
Requisitos desde o início:
- texto escalável;
- contraste adequado;
- não depender apenas de cor;
- touch targets confortáveis;
- suporte a leitores de tela quando viável;
- reduzir movimento;
- controle de tamanho de texto;
- linguagem clara;
- nenhuma ação importante só por gesto;
- navegação previsível.
A direção editorial não pode virar fonte minúscula de revista.

# 35. Stack técnica recomendada
Com a remoção do mapa 2D, a prioridade muda.

### Stack
- TypeScript;
- React Native;
- Expo;
- núcleo de simulação em pacote TypeScript puro;
- SQLite para persistência local estruturada;
- camada de estado de UI separada da simulação;
- testes unitários e de simulação fora da interface.

### Por que
- Claude trabalha muito bem com TypeScript;
- lógica pode rodar em Node durante testes;
- UI mobile é mais rápida de construir;
- domínio pode ser portado;
- conteúdo pode ser validado;
- grande ecossistema;
- texto/listas/formulários são naturais na plataforma.

### Não acoplar ao Expo
O pacote de simulação não importa React Native.
Ideal:
apps/
  mobile/
  web-dev/

packages/
  simulation/
  content/
  persistence/
  shared/
  ui/

### Regra
packages/simulation deve rodar testes sem inicializar React Native.

# 36. Arquitetura de software
UI
 |
 v
Application Commands
 |
 v
Simulation Coordinator
 |
 +--> Person System
 +--> Relationship System
 +--> Memory System
 +--> Career System
 +--> Economy System
 +--> Education System
 +--> Housing System
 +--> Event System
 +--> NPC AI
 |
 v
World State
 |
 +--> Queries / Read Models
 +--> Persistence
 |
 v
UI

### Camadas
Domain
Tipos e estado.
Simulation
Regras e transições.
Application
Comandos, validação, orquestração.
Content
Definições.
Persistence
Banco/save/migração.
UI
Apresentação e input.

### Dependência
Simulação nunca importa componente React.

### Sistemas com dono
Exemplo:
- dinheiro é alterado pelo FinanceSystem;
- relação pelo RelationshipSystem;
- memória pelo MemorySystem.
Outros sistemas solicitam efeitos em vez de editar campos arbitrariamente.

# 37. Modelo de dados

### Person
type Person = {
  id: PersonId
  name: string
  birthDate: GameDate
  householdId: HouseholdId
  residenceId: ResidenceId
  personality: PersonalityState
  skills: SkillState
  needs: NeedState
  mood: MoodState
  goals: GoalId[]
  employmentIds: EmploymentId[]
  relationshipIds: RelationshipId[]
  memoryIds: MemoryId[]
  knownFactIds: KnownFactId[]
}

### Relationship
type Relationship = {
  id: RelationshipId
  a: PersonId
  b: PersonId
  familiarity: number
  affection: number
  trust: number
  respect: number
  attraction: number
  resentment: number
  tags: RelationshipTag[]
  lastInteractionAt?: GameDate
}

### Employment
type Employment = {
  id: EmploymentId
  personId: PersonId
  companyId: CompanyId
  roleId: RoleId
  salary: number
  startedAt: GameDate
  scheduleId: ScheduleId
  performance: number
  satisfaction: number
}

### WorldState
Inclui:
- clock;
- seed;
- pessoas;
- famílias;
- relações;
- empresas;
- empregos;
- residências;
- instituições;
- eventos agendados;
- economia;
- histórico;
- metadados de save.

### Regra
IDs persistentes. Nunca depender de índice de array como identidade.

# 38. Determinismo
O motor deve ser reproduzível.

### Requisito de bug
Um bug sistêmico deve poder ser reproduzido com:
- seed;
- data/tick;
- save;
- sequência de comandos.

### RNG
Usar streams nomeados:
- world;
- ai;
- event;
- career;
- health;
- relationship.
Não chamar Math.random() em sistemas centrais.

### Benefícios
- testes;
- debugging;
- balanceamento;
- simulações longas;
- reprodução por Claude.

# 39. Escala de simulação
Nem todo cidadão precisa da mesma resolução.

### Tier A: jogador
Máxima resolução.

### Tier B: pessoas importantes
Família, parceiro, amigos, chefe, colegas relevantes.

### Tier C: conhecidos
Estado individual, atualização menos frequente.

### Tier D: população de fundo
Pode ser agregada ou simplificada.

### Promoção
Quando alguém de fundo vira relevante, detalhes são materializados sem contradizer fatos prévios.

### Meta
A arquitetura deve permitir milhares de pessoas sem executar uma IA completa a cada minuto do jogo.

# 40. Save, banco e migrações

### SQLite
Bom para:
- entidades;
- relações;
- histórico;
- consultas;
- grandes saves.

### Snapshot
Pode existir uma camada de snapshot/cache para carregamento rápido.

### Versão
Todo save tem schemaVersion.

### Migração
v4 -> v5 -> v6
Nunca quebrar silenciosamente saves.

### Autosave
Gatilhos:
- passagem de período;
- decisão importante;
- app em background;
- intervalo seguro.
Manter backup anterior.

### Integridade
Na carga:
- validar IDs;
- validar referências;
- reconstruir índices;
- detectar corrupção;
- migrar;
- só então iniciar UI.

# 41. Conteúdo data-driven
Jobs, eventos, traços, cursos, empresas-base e textos parametrizados devem viver em dados validados sempre que possível.

### Não criar
cheating_event_37.ts
para cada situação.

### Criar
- ConditionRegistry;
- EffectRegistry;
- EventDefinition;
- ContentValidator.

### Benefício
Claude pode adicionar 100 eventos sem modificar o motor.

### Validação
Detectar:
- ID duplicado;
- referência inválida;
- texto ausente;
- condição impossível;
- cadeia circular;
- efeito desconhecido.

# 42. Ferramentas internas obrigatórias
Um jogo profundo precisa de ferramentas.

### 42.1 Inspector de pessoa
Mostra:
- estado;
- objetivos;
- relações;
- memórias;
- agenda;
- conhecimento;
- última decisão de IA.

### 42.2 Inspector de evento
Mostra:
- condições;
- score;
- por que elegível;
- por que bloqueado.

### 42.3 World validator
Varre:
- IDs;
- relações;
- empregos;
- famílias;
- finanças;
- datas.

### 42.4 Fast-forward
Botões de debug:
- 1 dia;
- 1 mês;
- 1 ano;
- 10 anos.

### 42.5 Estatísticas
Após simulação:
- desemprego;
- renda;
- relacionamentos;
- mudanças;
- eventos;
- população;
- performance.
Essas ferramentas devem chegar cedo.

# 43. Testes

### Unitários
- datas;
- condições;
- efeitos;
- finanças;
- pontuação de IA.

### Integração
- vaga -> candidatura -> contratação -> salário;
- relação -> conflito -> memória -> mudança;
- curso -> conclusão -> qualificação -> vaga;
- demissão -> perda de renda -> orçamento.

### Determinismo
Mesmo seed + mesmos comandos = mesmo estado crítico.

### Long run
Rodar:
- 1 ano;
- 5 anos;
- 20 anos.
Procurar:
- dinheiro infinito;
- desemprego universal;
- relações sempre colapsando;
- eventos explosivos;
- crescimento de memória sem limite;
- performance degradando.

### Save/load
Salvar, carregar e comparar estado.

# 44. Performance
O maior risco é a simulação, não a renderização.

### Evitar
- loops globais por minuto;
- scans completos para toda consulta;
- histórico infinito;
- recalcular tudo;
- observar todos os objetos pela UI.

### Usar
- índices;
- filas;
- tarefas agendadas;
- atualizações em lote;
- frequência por sistema;
- níveis de detalhe;
- compactação de histórico.

### Benchmark
Criar cenários:
- 100 pessoas;
- 1.000;
- 10.000 simplificadas;
- 20 anos em fast-forward.
Registrar tempo e memória por commit relevante.

# 45. Exemplo de cadeia emergente
Imagine:
1. A empresa Nexo perde contratos.
2. O sistema econômico reduz saúde financeira da empresa.
3. A empresa congela contratações.
4. Dois meses depois, decide cortar 8% da equipe.
5. A pontuação de risco do jogador sobe porque seu departamento está caro e seu desempenho está mediano.
6. O jogador é demitido.
7. A renda do domicílio cai.
8. O aluguel consome uma parcela muito maior do orçamento.
9. O jogador cancela dois encontros por falta de dinheiro.
10. A parceira interpreta isso com base na comunicação recente.
11. Ela já carrega memória de falta de transparência financeira.
12. A tensão aumenta.
13. O jogador pode explicar, esconder ou pedir ajuda.
14. Um amigo que trabalha em outra empresa lembra que o jogador está sem emprego.
15. Surge uma indicação.
Nenhum roteirista precisou escrever:
EVENTO 202: Você foi demitido e sua relação piorou.
A história nasceu da rede de sistemas.

# 46. Exemplo de sessão

### 07:12
Terça, 14 de abril
Você dormiu pouco. A apresentação do trimestre é hoje às 10h.
Próximo compromisso
Reunião trimestral
10:00 - Nexo Media
Ações:
- revisar a apresentação;
- tomar café com calma;
- mandar mensagem para Camila;
- avançar até a reunião.

### 09:48
Camila:
O Bruno chegou cedo. Tá perguntando pelos números de março.
O jogador sabe que Bruno é chefe da área.

### 12:14
A apresentação terminou.
Você respondeu bem às perguntas, mas Bruno voltou a cobrar o atraso do projeto Aurora.
O jogo registra:
- apresentação boa;
- confiança profissional pequena alta;
- cobrança de atraso;
- memória de interação.

### 18:32
Rodrigo quer conversar.
Ele recebeu uma proposta de outra empresa e está pensando em sair.
O jogador pode:
- perguntar detalhes;
- incentivar;
- pedir para ser avisado se abrir vaga;
- mudar de assunto.
Meses depois, essa conversa pode importar.

# 47. Direção de onboarding
Não abrir com 12 tutoriais.

### Primeiros minutos
1. definir identidade básica;
2. escolher contexto inicial;
3. entrar na timeline;
4. primeira decisão simples;
5. apresentar uma pessoa;
6. apresentar trabalho/dinheiro conforme surgirem.

### Ensinar no contexto
Quando aparece primeira conta:
Suas despesas fixas vencem ao longo do mês. Você pode acompanhar tudo em Dinheiro.

### Não interromper
Tutorial deve desaparecer rapidamente para jogadores experientes.

### Primeira hora
Precisa provar:
- pessoas lembram;
- tempo passa;
- dinheiro importa;
- trabalho importa;
- uma escolha volta depois.

# 48. Escopo do primeiro vertical slice
O primeiro slice não precisa de centenas de empregos.
Precisa provar a arquitetura.

### Conteúdo
- 1 cidade;
- 100 a 500 pessoas individualizadas;
- população de fundo agregada;
- 20 NPCs com alta relevância potencial;
- 10 empresas;
- 12 funções;
- 3 instituições educacionais;
- 30 eventos;
- 10 cadeias curtas;
- sistema de mensagens;
- relações;
- dinheiro;
- trabalho;
- timeline;
- notícias;
- save.

### Cenários
O jogador começa adulto jovem com:
- moradia;
- trabalho simples ou desemprego;
- família;
- dois amigos;
- dinheiro limitado.

### Critério
Depois de 3 meses de jogo, duas campanhas com seeds diferentes devem contar histórias claramente diferentes sem parecer uma coleção aleatória de cards.

# 49. Roadmap

### Fase 0: fundação
- monorepo;
- simulação pura;
- relógio;
- RNG;
- IDs;
- testes;
- save inicial.

### Fase 1: pessoa e timeline
- player;
- estado;
- agenda;
- ações;
- timeline;
- UI base.

### Fase 2: pessoas e relações
- NPCs;
- relação;
- memória;
- mensagens;
- IA básica.

### Fase 3: carreira e dinheiro
- empresas;
- vagas;
- empregos;
- salário;
- ledger;
- despesas.

### Fase 4: eventos
- condições;
- efeitos;
- cadeias;
- conteúdo.

### Fase 5: mundo
- economia;
- notícias;
- moradia;
- instituições.

### Fase 6: vida longa
- educação;
- família;
- envelhecimento;
- legado.

### Fase 7: escala
- mais conteúdo;
- ferramentas;
- performance;
- balanceamento.

### Fase 8: sistemas avançados
- crime/legal;
- negócios próprios;
- investimentos;
- saúde ampliada;
- modding.

# 50. Regras para Claude Code
Claude deve ler este documento antes de alterações estruturais.

### Sempre
- investigar o que já existe;
- integrar em vez de duplicar;
- manter simulação fora da UI;
- usar TypeScript estrito;
- escrever testes;
- preservar determinismo;
- usar IDs estáveis;
- validar conteúdo;
- registrar migrações;
- reportar limitações.

### Nunca
- criar GameManager2;
- jogar toda a lógica em Zustand/Redux;
- chamar Math.random() em simulação;
- guardar verdade do domínio em estado de tela;
- criar uma classe por evento;
- usar texto gerado em runtime como requisito para gameplay;
- criar dezenas de cards porque é mais fácil;
- inventar arquitetura nova sem verificar docs;
- reescrever todo o projeto por conveniência.

### Entrega de tarefa
Claude deve responder:
Implementado
- ...
Arquivos
- ...
Testes executados
- ...
Impacto em save
- ...
Performance
- ...
Limitações
- ...
Próximo passo lógico
- ...

# 51. Padrão de especificação de feature
Toda feature grande deve ter:

### Objetivo
Que problema resolve?

### Experiência
O que o jogador vê e faz?

### Regras
Qual é a verdade do sistema?

### Estado
Que dados entram?

### Comandos
Que ações podem ser solicitadas?

### Consequências
Que fatos podem ser emitidos?

### UI
Que telas mudam?

### Persistência
Que dados são salvos?

### Testes
Como provar?

### Performance
Quantas entidades e com que frequência?

### Conteúdo
Quais definições novas?

### Edge cases
O que pode quebrar?

# 52. Critérios de qualidade de uma feature
Uma feature não está pronta porque aparece na tela.
Está pronta quando:
- existe no estado autoritativo;
- funciona fora da UI;
- pode ser salva;
- pode ser carregada;
- possui causa;
- produz consequência;
- tem teste;
- funciona para NPC quando aplicável;
- não exige scan global absurdo;
- a UI consegue explicar o resultado;
- o texto está revisado;
- não introduz linguagem visual genérica.

# 53. Como revisar uma tela antes de aprovar
Perguntas obrigatórias:
1. Eu reconheceria PARALELO sem o logo?
2. Há mais caixas do que informação exige?
3. Tipografia cria hierarquia?
4. Algum número humano deveria ser texto?
5. Algum texto parece gerado por template?
6. Existe informação repetida?
7. O jogador entende o próximo passo?
8. O layout funciona com texto 30% maior?
9. Há algum botão que só existe porque "todo app tem"?
10. O conteúdo é específico desta vida?
11. Existe uma razão para a cor de acento?
12. Uma fintech poderia usar esta mesma tela quase sem mudanças?
Se 12 for sim, refazer.

# 54. Como revisar um evento antes de aprovar
Perguntas:
1. Por que isto aconteceu agora?
2. Quem sabe disto?
3. Quem é afetado?
4. Que estado real muda?
5. Que memórias podem surgir?
6. A escolha possui trade-off?
7. O evento poderia ocorrer com outro personagem?
8. Existe cooldown?
9. A escrita depende de contexto?
10. Pode voltar no futuro?
11. Existe risco de repetição?
12. É um evento ou deveria ser uma consequência sistêmica automática?

# 55. Guardrails de conteúdo procedimental
Conteúdo procedimental deve combinar blocos com cautela.

### Permitido
- preencher nomes;
- datas;
- valores;
- empresa;
- bairro;
- relação;
- motivo estruturado.

### Evitar
Montar parágrafos inteiros por concatenação de fragmentos.
Resultado comum:
Marina, sua amiga próxima, parece preocupada porque seu nível de stress está elevado.
Isso soa como banco de dados.
Preferir templates completos condicionais escritos por humanos.

### Variações
Uma situação recorrente pode ter múltiplas versões curadas.

### Runtime LLM
Não é requisito do core.
Se um dia for usado:
- deve ser opcional;
- nunca dono da lógica;
- nunca criar estado sem validação;
- saída deve ser limitada a apresentação.

# 56. Monetização e produto
A experiência principal deve ser projetada primeiro como jogo completo e respeitoso.
Não desenhar loops para:
- interromper decisão com anúncio;
- vender solução para problema criado artificialmente;
- energia paga;
- lootbox.
Se houver monetização futura, ela não deve comprometer:
- ritmo;
- saves;
- resultado da simulação;
- confiança do jogador.
A prioridade deste documento é o produto, não o modelo comercial.

# 57. Nome, marca e identidade
PARALELO funciona como título de trabalho porque sugere:
- outras vidas;
- trajetórias;
- mundos acontecendo ao lado;
- possibilidades.
Mas a arquitetura de marca não deve depender desse nome.

### Marca
Tom:
- adulto;
- direto;
- íntimo;
- observador.

### Slogans possíveis
- Uma vida. Muitas histórias.
- O mundo continua.
- Pequenas escolhas. Consequências longas.
- Sua vida é só uma parte da história.
Não exibir slogans durante gameplay.

### Logo
Preferir wordmark tipográfico forte.
Evitar logo com:
- personagem genérico;
- skyline clichê obrigatório;
- gradiente;
- brilho;
- símbolo abstrato "tech".

# 58. Design tokens iniciais
export const colors = {
  bg: "#111315",
  surface: "#181B1E",
  surfaceRaised: "#202428",
  rule: "#30353A",
  text: "#EEECE6",
  textSecondary: "#A5A49F",
  textMuted: "#747670",
  accent: "#B8E986",
  warning: "#E6B95C",
  danger: "#D86A62",
  info: "#7DA7D9",
} as const

export const space = {
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  6: 24,
  8: 32,
  12: 48,
} as const

export const radius = {
  none: 0,
  sm: 4,
  md: 8,
  lg: 12,
} as const

### Regra
Tokens são ponto de partida. Não transformar design em uma matemática rígida que mata composição editorial.

# 59. Exemplo de Home em texto
PARALELO                                      18:42

SEXTA, 17 DE ABRIL
27 anos

Você chegou em casa depois das 19h.

Marina não respondeu suas últimas duas mensagens.
Ela esteve online há alguns minutos.

──────────────────────────────────────────────

TRABALHO

Seu desempenho caiu nas últimas três semanas.

Nexo Media
Analista de Conteúdo

Salário                              R$ 6.200
Situação                               Tensa

Bruno pediu para falar com você amanhã.

──────────────────────────────────────────────

ESTA NOITE

Conversar com Marina
Preparar a apresentação
Pedir comida
Dormir cedo

──────────────────────────────────────────────

VIDA      PESSOAS      CARREIRA      DINHEIRO      MUNDO
O objetivo não é copiar esta composição literalmente. É preservar:
- hierarquia;
- espaço;
- texto;
- poucas caixas;
- contexto.

# 60. Exemplo de pessoa
MARINA FERREIRA

Sua parceira
Juntos há 2 anos e 4 meses

Vocês não se veem há seis dias.

COMO ESTÁ A RELAÇÃO

Há carinho, mas as últimas semanas foram tensas.
Marina parece incomodada com a distância entre vocês.

ÚLTIMOS MOMENTOS

Hoje
Você deixou uma ligação tocar.

Ontem
Marina cancelou o jantar.

Domingo
Vocês discutiram sobre dinheiro.

MOMENTOS QUE ELA PROVAVELMENTE LEMBRA

Você a apoiou quando ela mudou de emprego.
Você faltou à formatura da irmã dela.

AÇÕES

Ligar
Mandar mensagem
Convidar para sair
Conversar sobre a relação
Observe: sem "amor 82".

# 61. Exemplo de carreira
CARREIRA

NEXO MEDIA
Analista de Conteúdo

R$ 6.200 / mês
Seg a sex, 9h às 18h
2 anos e 3 meses

SITUAÇÃO

As últimas semanas foram difíceis.
Seu atraso no projeto Aurora chamou atenção.

Bruno Almeida
Seu gestor

A relação profissional é correta, mas ele tem cobrado resultados.

PRÓXIMOS DIAS

Sex 10:00   Reunião com Bruno
Seg 09:30   Entrega: Projeto Aurora

OPORTUNIDADES

Nexo Media
Processo interno: Especialista
Você ainda não cumpre todos os requisitos.

Vértice
Analista Sênior
Helena pode indicar você.

# 62. Exemplo de dinheiro
DINHEIRO

R$ 8.742,31

SETEMBRO

Entradas                         R$ 6.200
Saídas                           R$ 5.487
Resultado                          +R$ 713

PRÓXIMOS 10 DIAS

05 out  Aluguel                  -R$ 2.450
08 out  Cartão                   -R$ 1.126
10 out  Internet                   -R$ 119

SUA SITUAÇÃO

Você consegue pagar os compromissos atuais,
mas sua reserva cobre menos de dois meses.

DÍVIDAS

Cartão parcelado                 R$ 3.800
Informação financeira deve ser concreta, sem ornamentação excessiva.

# 63. Exemplo de Mundo
MUNDO
Terça, 14 de abril

NEGÓCIOS

Nexo anuncia revisão de custos após perder dois contratos

A empresa não informou quantos postos podem ser afetados.
Você trabalha na Nexo há pouco mais de dois anos.

CIDADE

Aluguéis voltam a subir no Centro

O valor médio das novas locações aumentou pelo terceiro mês.

OPORTUNIDADES

Hospital Santa Clara abre vagas administrativas
Universidade Central anuncia bolsas noturnas
A aba Mundo é a ponte entre sistemas macro e a vida pessoal.

# 64. Mapa de causalidade do produto
ECONOMIA
   |
   v
EMPRESAS <-------- EDUCAÇÃO
   |                  |
   v                  v
TRABALHO --------> HABILIDADES
   |                  |
   +------> DINHEIRO <+
              |
              v
           MORADIA
              |
              v
          TEMPO/ROTINA
              |
     +--------+--------+
     v                 v
  SAÚDE             RELAÇÕES
                        |
                        v
                     MEMÓRIA
                        |
                        v
                  DECISÕES DE NPC
                        |
                        v
                     EVENTOS
Nenhuma seta deve ser entendida como única direção. O objetivo é ter ciclos controlados e legíveis.

# 65. O que cortar quando o projeto ficar grande demais
Cortar nesta ordem:
1. quantidade de profissões;
2. quantidade de cidades;
3. crime avançado;
4. investimentos complexos;
5. negócios próprios;
6. saúde detalhada;
7. política/instituições avançadas;
8. modding;
9. gerações muito profundas.
Não cortar:
- memória;
- relações;
- trabalho;
- dinheiro;
- timeline;
- causalidade;
- save;
- ferramentas de debug.
Esses são o jogo.

# 66. Definition of Done global
O produto pode ser considerado estruturalmente saudável quando:
- duas campanhas contam histórias distintas;
- NPCs fazem coisas sem participação do jogador;
- relações carregam passado;
- empresas afetam pessoas reais no mundo;
- dinheiro é rastreável;
- notícias são derivadas de fatos;
- eventos não dominam a simulação;
- save de longo prazo continua válido;
- fast-forward não quebra causalidade;
- a UI é reconhecível sem depender de logo;
- screenshots não parecem dashboard genérico;
- narrativa não parece saída bruta de LLM;
- desenvolvedores conseguem explicar por que um acontecimento ocorreu.

# 67. Prompt de partida para Claude
Use o texto abaixo ao iniciar a implementação:
Leia integralmente PARALELO_MASTER_DESIGN_BIBLE.md antes de alterar arquitetura. Este documento é a fonte de verdade de produto, simulação, UI e escrita. Antes de codificar, audite o repositório e descreva o que já existe, o que conflita com a bíblia e qual é o menor vertical slice coerente. Não implemente uma UI bonita sobre lógica falsa. Faça primeiro um fluxo completo UI -> Command -> Simulation -> World State -> Query -> UI, com testes e save. Não crie managers duplicados, não coloque lógica de domínio em componentes React e não use Math.random() na simulação. Ao terminar cada tarefa, informe arquivos alterados, testes executados, impacto em save, performance, limitações e próximo passo lógico.
A primeira entrega recomendada é:
1. monorepo;
2. pacote simulation;
3. relógio determinístico;
4. RNG;
5. IDs;
6. Person;
7. Relationship;
8. WorldState;
9. comando simples;
10. timeline mínima;
11. SQLite/save inicial;
12. testes de determinismo.

# 68. Conclusão
A vantagem de PARALELO não deve ser "ter mais coisas".
Deve ser fazer com que as coisas pertençam ao mesmo mundo.
Um emprego não é uma tela.
É uma empresa, um chefe, colegas, dinheiro, agenda, reputação e oportunidades.
Uma relação não é uma barra.
É histórico, memória, confiança, afeto, rotina e expectativa.
Uma notícia não é flavor text.
É a apresentação pública de algo que aconteceu.
Uma decisão não é um botão.
É a intervenção do jogador em uma rede de consequências.
E a interface não deve gritar tecnologia, IA ou template. Ela deve desaparecer o suficiente para que o jogador leia sua própria vida.
Se o projeto respeitar isso, ele não será "um BitLife maior".
Será outra categoria de simulador de vida.
APÊNDICES DE PRODUÇÃO E AUTORIA
Regras práticas para manter identidade, autoria e qualidade durante a produção.

# 69. Gramática autoral de layout
A identidade não será garantida apenas por cor e fonte. Ela precisa de uma gramática de composição.

### 69.1 Eixo dominante
Cada tela deve escolher um eixo dominante:
- leitura vertical;
- lista;
- documento;
- timeline;
- tabela/ledger.
Não misturar cinco padrões equivalentes disputando atenção.

### 69.2 Bordas antes de cards
A ordem de decisão visual é:
1. espaço;
2. tipografia;
3. alinhamento;
4. linha divisória;
5. background sutil;
6. card fechado, somente se realmente necessário.
Isso evita o comportamento comum de geradores automáticos de colocar cada grupo em um retângulo.

### 69.3 Assimetria controlada
Layouts podem ser levemente assimétricos.
Exemplo:
- título grande à esquerda;
- metadado discreto à direita;
- seção narrativa com largura menor que seção financeira.
Não procurar simetria perfeita como objetivo estético.

### 69.4 Ritmo
A interface deve alternar densidade.
Uma tela pode ter:
- um título grande;
- um bloco narrativo;
- uma lista densa;
- uma área de respiro;
- uma decisão.
Se tudo tiver o mesmo peso e o mesmo espaçamento, parece template.

### 69.5 Elementos de assinatura
Escolher poucos elementos que possam virar assinatura:
- data em serif grande;
- filetes horizontais;
- labels em caixa alta pequena;
- horários alinhados em coluna;
- uma única cor de acento;
- transições de capítulo.
Repetir esses elementos com consistência cria reconhecimento.

# 70. Design fingerprints: como o jogo deve ser reconhecido sem o logo
Um screenshot deve poder ser identificado por padrões recorrentes.

### Fingerprint 1: data como estrutura narrativa
Datas e horários têm presença editorial, não ficam escondidos.

### Fingerprint 2: texto primeiro
A primeira coisa que o olho lê é uma frase, um acontecimento ou um nome, não um conjunto de ícones.

### Fingerprint 3: linhas e colunas
Separação estrutural por filetes e alinhamento.

### Fingerprint 4: acento verde raro
O verde aparece apenas para:
- foco;
- ação atual;
- situação positiva importante.

### Fingerprint 5: informação humana em linguagem
Relação: distante, não 65%.

### Fingerprint 6: factualidade econômica
Finanças usam números exatos e layout mais técnico.

### Fingerprint 7: timeline com horários
A Home tem um ritmo quase documental.

### Fingerprint 8: serif em momentos narrativos
Marcos, títulos e datas especiais recebem uma voz tipográfica diferente.

### Regra
Se um redesign remover quatro desses fingerprints, deve existir motivo forte.

# 71. Estados vazios, loading e erro
Telas sem conteúdo são parte da identidade.

### Estado vazio ruim
Nada por aqui! Volte mais tarde 😊
Genérico e infantil.

### Estado vazio bom
Nenhuma conversa recente
Você não fala com ninguém desta lista há algumas semanas.

### Loading
Evitar skeleton colorido em todo lugar por hábito.
Para operações locais rápidas, nenhuma animação complexa.
Para simulação longa:
Avançando até sexta-feira
Processando três dias da sua vida.

### Erro
Erro técnico não deve fingir ser narrativa.
Não foi possível carregar este save.
A cópia anterior ainda está disponível.

### Mundo sem notícia
Não inventar notícia para preencher espaço.
Pode mostrar:
Nada importante mudou desde ontem.

# 72. Responsividade
O produto nasce mobile, mas não deve ficar preso ao formato de telefone.

### Telefone
- uma coluna;
- bottom navigation;
- sheets contextuais;
- largura de leitura controlada;
- ações em lista.

### Tablet
- lista + painel de detalhe;
- timeline à esquerda, contexto à direita;
- navegação lateral opcional.

### Desktop
- não esticar coluna mobile até 1.500 px;
- usar duas ou três regiões com parcimônia;
- teclado;
- hover apenas como melhoria, nunca necessidade.

### Regra de leitura
Blocos narrativos não devem ficar largos demais.
Mesmo em desktop, manter largura confortável de texto.

# 73. Biblioteca de microcopy
Microcopy deve ser seca e específica.

### Confirmações
Preferir:
- Salvo.
- Pagamento feito.
- Mensagem enviada.
- Candidatura enviada.
Evitar:
- Tudo pronto!
- Sucesso! Sua incrível jornada continua.
- Parabéns!

### Ações
Preferir verbo direto:
- Ligar
- Responder
- Candidatar-se
- Pagar
- Adiar
- Cancelar
- Pedir ajuda

### Avisos
Você não tem dinheiro suficiente.
Melhor que:
Ops! Parece que seu saldo não é suficiente para realizar esta ação.

### Consequências
Isso pode atrasar o aluguel.
Melhor que:
Tenha em mente que esta decisão poderá ter consequências em suas finanças futuras.

# 74. Vocabulário proibido ou restrito
Não é uma lista absoluta, mas Claude deve desconfiar destas expressões quando escreve gameplay ou marketing interno:
- jornada;
- embarque;
- desvende;
- mergulhe;
- universo de possibilidades;
- cada escolha conta;
- destino em suas mãos;
- experiência imersiva;
- de forma única;
- repleto de;
- uma nova dimensão;
- não apenas X, mas também Y;
- complexidades da vida;
- navegue por;
- infinitas possibilidades;
- moldar seu futuro;
- viva sua melhor vida.
Elas podem aparecer quando uma pessoa real usaria, mas nunca como voz padrão do jogo.

# 75. Padrões de informação por domínio
Cada domínio tem uma linguagem de UI diferente.

### Pessoas
Priorizar:
- nomes;
- contexto;
- tempo;
- memória;
- comportamento.
Evitar precisão falsa.

### Dinheiro
Priorizar:
- valores;
- datas;
- categorias;
- tendência.
Precisão é desejável.

### Carreira
Misturar:
- fatos objetivos;
- avaliação;
- relação;
- oportunidade.

### Mundo
Usar:
- manchetes;
- indicadores;
- relevância.

### Vida
Usar:
- narrativa;
- agenda;
- prioridades;
- mudanças.
Essa diferenciação impede que todas as telas virem o mesmo card com outro ícone.

# 76. Sistema de capítulos de vida
Para campanhas longas, criar capítulos implícitos.
Exemplos:
- saindo de casa;
- começo de carreira;
- crise financeira;
- nova cidade;
- casamento;
- recomeço profissional;
- envelhecimento dos pais.
O sistema pode identificar períodos retrospectivamente com base em marcos.

### Uso
Na timeline anual:
2028
Um ano de mudanças
Você trocou de emprego, saiu do Centro e conheceu Marina.
Isso deve ser gerado a partir de fatos selecionados, com templates editoriais, não por um LLM obrigatório.

# 77. Retrospectiva anual
A cada ano, oferecer uma página opcional.

### Estrutura
2029
Você começou o ano na Nexo e terminou trabalhando na Vértice.
Trabalho
- saiu da Nexo em maio;
- passou dois meses sem emprego;
- entrou na Vértice em agosto.
Pessoas
- Marina mudou-se para sua casa;
- você voltou a falar com Rodrigo.
Dinheiro
- renda total;
- maior despesa;
- dívida reduziu/aumentou.
Marcos
Selecionar 3 a 6 fatos.
A retrospectiva é um dos lugares onde a identidade editorial pode brilhar.

# 78. Sistema de causas
Todo fato importante deve poder carregar causeIds.
Exemplo:
{
  type: "employment_ended",
  personId: "p_42",
  causeIds: [
    "company_restructure_91",
    "department_cost_cut_12"
  ]
}

### Por que
Permite:
- explicar UI;
- depurar;
- gerar notícia;
- gerar retrospectiva;
- gerar memória;
- evitar causalidade inventada.

### Causa percebida vs causa real
Personagens podem interpretar causas de forma diferente.
O sistema pode saber que a empresa cortou custos.
O personagem pode acreditar que foi demitido por não ser querido pelo chefe.
Essa diferença gera narrativa.

# 79. Conhecimento e crenças
Adicionar uma camada simples de conhecimento quando o núcleo estiver estável.

### Fact
Um acontecimento verdadeiro no mundo.

### KnownFact
Uma pessoa sabe ou acredita saber algo.
Campos:
- source;
- confidence;
- learnedAt;
- factId;
- distortion opcional.

### Uso
Permite:
- segredo;
- rumor;
- fofoca;
- mentira;
- surpresa;
- informação profissional.

### Guardrail
Não transformar o jogo em simulador epistemológico antes do básico funcionar.
Começar com:
- público;
- privado;
- conhecido por lista de pessoas.

# 80. Repositório recomendado
/
  apps/
    mobile/
      src/
        screens/
        navigation/
        components/
        hooks/
        theme/
    dev-sim/
      src/

  packages/
    simulation/
      src/
        domain/
        systems/
        commands/
        queries/
        time/
        rng/
        scheduling/

    content/
      src/
        events/
        jobs/
        education/
        traits/
        localization/
        validation/

    persistence/
      src/
        sqlite/
        migrations/
        repositories/

    shared/
      src/
        ids/
        types/
        result/

    ui/
      src/
        primitives/
        patterns/

  tests/
    long-run/
    fixtures/

  docs/

### `dev-sim`
Um pequeno app/CLI para:
- gerar mundo;
- avançar tempo;
- inspecionar pessoas;
- rodar benchmarks.
Isso acelera muito o trabalho com Claude.

# 81. Convenções TypeScript

### Strict mode
Obrigatório.

### Tipos de ID
Evitar trocar IDs por acidente.
type Brand<T, B extends string> = T & { readonly __brand: B }

type PersonId = Brand<string, "PersonId">
type CompanyId = Brand<string, "CompanyId">

### Result
Validações esperadas não devem lançar exceção como fluxo normal.
type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E }

### Imutabilidade
Preferir transições controladas.
Não expor objetos mutáveis para UI.

### Datas
Não usar Date de sistema como tempo de jogo.
Criar tipos de calendário do jogo.

### RNG
Injetado.

### Domínio
Nada de any para escapar de modelagem.

# 82. Observabilidade

### Log estruturado
log.info("employment.ended", {
  tick,
  personId,
  employmentId,
  causeIds
})

### Trace por pessoa
Ativar sob demanda.

### Histórico de comandos
Manter buffer recente em dev.

### Hash de estado
Calcular hash de campos críticos para determinismo.

### Painel de performance
- tempo por sistema;
- eventos processados;
- população por tier;
- fila agendada;
- queries lentas;
- memória.

### Relatório de mundo inválido
O validator deve retornar erros acionáveis, não apenas false.

# 83. Balanceamento sistêmico
Balancear um simulador exige observar distribuições.

### Métricas de dev
Após 10 anos:
- quantos empregados;
- salários;
- dívida;
- casamentos;
- divórcios;
- mudanças;
- tamanho de famílias;
- tempo médio em emprego;
- quantidade de eventos por mês.

### Rodadas de seed
Rodar 100 seeds e comparar.

### Sinais de problema
- todo mundo rico;
- todo mundo quebrado;
- toda relação termina;
- ninguém muda de emprego;
- todos viram amigos;
- event chains dominam;
- uma estratégia sempre ganha.

### Objetivo
Variedade plausível, não igualdade estatística perfeita.

# 84. Checklist final de autoria
Antes de uma versão importante, reunir 20 screenshots e 50 trechos de texto aleatórios.

### Screenshots
Perguntar:
- parecem todos a mesma composição?
- existem cards demais?
- o acento virou cor dominante?
- a serif está sendo usada com propósito?
- há telas que parecem Notion, fintech ou dashboard SaaS?
- a densidade é coerente?

### Texto
Perguntar:
- todos os NPCs falam com mesma gramática?
- existe repetição de frases?
- há emoção explicada em excesso?
- há opções moralmente óbvias?
- o texto usa abstrações em vez de detalhes?
- existe humor acidentalmente "ChatGPT"?

### Produto
Perguntar:
- aconteceu algo porque o sistema quis ou porque faltava conteúdo?
- NPCs tiveram vida própria?
- o jogador consegue explicar a própria história?
Esta revisão é obrigatória antes de chamar a identidade de consolidada.
DOCUMENT CONTROL
Título de trabalho
PARALELO
Versão
1.0
Formato
Master Design Bible
Direção
Text-first • Simulation-first • Editorial UI
Fonte de verdade
Este documento + decisões posteriores explícitas do dono do projeto
