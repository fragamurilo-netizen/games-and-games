# Continuidade do desenvolvimento

Fonte de verdade: `PARALELO_MASTER_DESIGN_BIBLE.md`, especialmente §§36–43,
49, 67, 80–82. Leia a bíblia antes de alterar arquitetura.

Branch compartilhada: `claude/inspiring-cray-82ewil` no remoto `origin`.
Atualize este documento e faça commit/push de cada entrega validada. Nunca
confunda sistemas planejados com funcionalidades já implementadas.

## Entrega atual: rotina, alimentação e presença no trabalho

- Núcleo TS puro em `packages/simulation`: relógio Gregorian sem Date do sistema,
  RNG de seis streams independentes, IDs estáveis, pessoas, relações, agenda,
  comandos, timeline, queries, validação e hash de diagnóstico.
- Cenário: adulto jovem, moradia, mãe e dois amigos em Santa Aurora. A cidade
  contém 100 pessoas persistentes, 10 empresas, 12 funções/vagas e 3 cursos.
  Conteúdo em `packages/content`. As 96 pessoas de fundo ainda não têm IA ativa.
- Descansar recupera energia; ligar consome tempo e pode não obter resposta;
  contatos têm intervalo de oito horas. Skip para em mensagens importantes.
- `GameSession` é a dona da campanha na aplicação. UI assina o read model e
  envia comandos; persistência precede a publicação da transição.
- Expo Router e cinco áreas VIDA/PESSOAS/CARREIRA/DINHEIRO/MUNDO em `apps/mobile/src/app`; SQLite Android/web na borda,
  via `apps/mobile/src/persistence`. Web exige WASM e COOP/COEP, configurados no Metro.
- Save v4: snapshot integral em SQLite, atualização e backup anterior em uma
  transação. IDs/referências/intervalos/hash são verificados na carga. Save
  futuro é recusado; corrupção tenta backup sem substituir a cópia válida por
  dados danificados. Se ambas as cópias falharem, nenhuma é sobrescrita.
- CLI `apps/dev-sim`: seed, fast-forward, inspeção, benchmark e snapshot JSON.
- Cursos cobram aulas, desenvolvem habilidade e têm conclusão e limite diário.
  Habilidades condicionam candidaturas; seleção é determinística e tem cooldown.
  Contratação fecha a vaga. Trabalho tem turno de oito horas, dias úteis e limite
  de um turno por dia. Cada turno acumula 1/20 do salário de referência.
- Sono acumulado e fome em `Person.needs`, junto de energia e stress. Descansar
  e dormir são atividades distintas. Integração de intervalos mantém os efeitos
  consistentes quando há eventos no meio de uma ação. Só o jogador tem essas
  necessidades processadas; NPCs continuam seguindo seus tiers anteriores.
- Despensa começa com quatro porções. Comprar seis custa R$ 48 e leva uma hora;
  preparar comida usa uma porção e 35 minutos. Restaurante: R$ 18/45 minutos.
  Almoço comunitário: gratuito, uma vez por dia, entrada entre 11h e 14h. Há
  caminho de recuperação mesmo sem saldo. Estoque máximo: 30 refeições.
- Agenda de trabalho real: lembrete às 8h e conferência de presença às 14h01,
  apenas em dias úteis. Entrada é permitida das 6h às 14h. A cobrança começa
  no próximo dia útil, inclusive para empregos migrados. Presença é registrada
  antes de processar as oito horas para não marcar falta durante um turno.
- Primeira falta gera aviso; segunda, advertência; terceira seguida encerra
  o contrato. Trabalhar interrompe a sequência. A saída liquida o salário
  acumulado uma vez, reabre a vaga, remove a agenda antiga e entra no histórico
  profissional. Nova candidatura à mesma empresa tem intervalo de sete dias.
  Sono, alimentação, stress e energia afetam o desempenho; nenhum sorteio é
  usado para essas faltas. As regras são parâmetros de gameplay em `content/routine.ts`.
- VIDA mostra os próximos turnos e pagamento/aluguel, sem revelar eventos
  internos dos NPCs. CARREIRA explica a situação da presença e exibe contratos
  encerrados. Lembretes sem novidade não interrompem a passagem de tempo.
- Dia 1 às 8h: pagamento dos turnos efetivamente cumpridos, seguido do aluguel.
  Todos os valores são inteiros em centavos; saldo precisa conferir com o ledger.
  Saldo negativo é explícito. Refeições e aulas são bloqueadas sem saldo suficiente.
- Pessoas próximas podem iniciar contato diário por iniciativa própria segundo
  sociabilidade. Contatos deixam memória; ausências prolongadas afetam proximidade.
  Esta é IA social inicial, não a Utility AI completa de §13.
- Motor declarativo com 30 acontecimentos em 10 cadeias de três etapas.
  Condições consideram trabalho, energia, dinheiro e stress. Escolhas consomem
  tempo e podem alterar saldo, habilidades, necessidades, relações e memórias.
  Custos pagos sem saldo são recusados e sempre existe uma alternativa gratuita.
  Uma decisão pendente pausa o skip e impede ações até o jogador responder.
  Follow-ups mantêm a pessoa original e são agendados dois dias depois.
  Orçamento: no máximo uma decisão por dia; novos inícios a cada três dias;
  cada definição aparece uma vez. Conteúdo é validado contra IDs/ciclos/efeitos.
- Fontes por orientação explícita do usuário: Newsreader nos títulos e narrativa,
  Commissioner no corpo/controles. Sem Barlow. Cinco TTF estáticos importados
  individualmente e empacotados offline; tokens em `packages/ui/src/tokens.ts`.
- Falha ao abrir SQLite oferece nova tentativa sem apagar dados. Campanha
  carregando mantém a recuperação acessível também ao abrir uma rota diretamente.
  MUNDO mostra moradores em lotes de 20 para reduzir a montagem inicial no celular.
- Laboratório vetorial em `prototypes/faces`: 133 cabelos, 106 barbas, 19 roupas,
  corpos contínuos, idades, ancestrais e herança. Commit `7df361c`.

## Como verificar e continuar

Use Node 24 e execute `npm ci`, `npm test`, `npm run typecheck`,
`npm --workspace apps/mobile run lint`. Depois `npm run mobile` para Android ou
`npm --workspace apps/mobile run web`. O laboratório abre separadamente com
`python -m http.server 8765 --bind 127.0.0.1` dentro de `prototypes/faces`.

Há 49 testes cobrindo determinismo, relógio, eventos, comandos recusados,
read models isolados, SQLite real, rollback, backup, saves futuros/corrompidos,
duplo toque, falha de gravação e integridade durante 1, 5 e 20 anos.
As corridas longas verificam integridade financeira e social; não demonstram
balanceamento de uma vida completa. Ainda não há macroeconomia ou envelhecimento
com morte/legado. Também há curso, contratação, turno, presença, demissão,
despensa, sono e conservação do ledger. Um cenário de 90 dias trabalha,
compra comida, dorme, responde decisões e recebe três pagamentos mensais.

## Save e migrações

SQLite `PRAGMA user_version = 1`: tabela `saves(slot, payload)`; slots `current`
e `previous`. Envelope JSON `schemaVersion = 4`, hash e WorldState v4. O save
do laboratório (`paralelo-character`) é independente do save da campanha.
Migração v1 -> v2 em `systems/slice.ts`: preserva pessoas originais, relações,
timeline, seed, relógio e cursores RNG. Acrescenta cidade/finanças/carreira via
namespace determinística independente. Fixture produzida com o gerador do
commit de fundação `1670156` em `tests/fixtures/legacy-save-v1.json`; testes
verificam migração, persistência e preservação da versão antiga como backup.
Migração v2 -> v3 em `systems/events.ts`: preserva os sistemas existentes e
acrescenta estado/agenda de decisões sem consumir RNG. Fixture v2 gerada no
checkpoint `82e83c6`; decisões pendentes e follow-ups são salvos integralmente.
Migração v3 -> v4 em `systems/routine.ts`: acrescenta fome/sono, despensa e
controle de presença sem consumir RNG nem aplicar faltas passadas. Fixture v3
produzida no checkpoint `99a5700`, com emprego ativo e R$ 90 a receber, está em
`tests/fixtures/legacy-save-v3.json`. Pessoas antigas mantêm todos os campos
anteriores; só recebem as novas necessidades. A versão anterior fica no backup.
Ao adicionar campos obrigatórios, criar migração explícita e teste de fixture
da versão anterior; não aceitar silenciosamente dados incompletos.

## Limitações conhecidas

**Android é a plataforma principal.** Export de produção Android/Hermes passou,
inclusive com as cinco fontes TTF. Isso valida resolução/compilação e assets;
não é um APK nem substitui teste em aparelho. Não há SDK Android/adb disponível
nesta máquina. Perfis EAS development/preview APK/production AAB já existem.
Não foi disparado build EAS remoto nesta entrega. Web é ambiente auxiliar de
inspeção. O retrato vetorial ainda não é integrado à campanha.
Person e Relationship são modelos iniciais; crenças, macroeconomia, mensagens
respondíveis gerais, Utility AI completa, promoções e troca voluntária de emprego faltam.
Demissão implementada apenas por faltas consecutivas; crise da empresa, licença,
justificativa de ausência e desligamento por desempenho ainda não existem.
Empregos e contas só são simulados para o jogador. Moradia é fixa. O registro
MUNDO deriva de fatos da campanha, não é um sistema de jornalismo da cidade.
As taxas de necessidades são parâmetros abstratos de jogo e precisam de
balanceamento com uso real. Não há doença, desmaio ou morte por negligenciar
alimentação/sono nesta versão. Não foram acrescentadas dependências nativas.
O hash de diagnóstico não é criptográfico. Histórico de comandos guarda os
últimos 256; timeline persistida é integral e query mostra os últimos 80.

## Próximas entregas, na ordem

1. Validar APK/emulador Android: abertura offline, fonte ampliada, voltar,
   background, retomada, duplo toque e SQLite real no aparelho.
2. Ampliar agenda com compromissos pessoais, licenças e justificativas de falta.
3. Utility AI, empregos/finanças dos NPCs, mensagens respondíveis e crenças.
4. Promoções, desligamentos por outros motivos, despesas detalhadas, dívidas e mudanças.
5. Completar o slice de §48: promover 20 NPCs relevantes, educação aprofundada,
   notícias da cidade e campanhas de três meses com trabalho e decisões.
6. Portar renderer/genoma vetorial para TS e react-native-svg sem duplicar a
   fonte de verdade; só depois acrescentar retratos às listas de pessoas.

## Validação e performance desta entrega

`npm test`: 49 testes, incluindo as 60 escolhas dos 30 eventos, cadeia completa,
replay recusado, opção sem saldo, retomada pendente e migrações v1/v2/v3.
Rotina: refeições e compras, sono vs pausa, intervalos de necessidade, contrato
às 14h, fim de semana, advertência, recuperação de presença, acerto único,
vaga reaberta, agenda corrompida e campanha ativa de três meses.
`npm run typecheck`: todos os workspaces.
`npm --workspace apps/mobile run lint` e `npx expo install --check`: executados.
Web: navegação, ações, extrato, autosave e retomada/migração inspecionados no browser.
Em campanha separada de QA v3, a atualização preservou saldo de R$ 850, acrescentou
quatro porções, consumiu uma e comprou seis por R$ 48 (saldo R$ 802). Contratação
na Padaria Aurora e turno de oito horas geraram R$ 95 a receber, sem falta falsa
às 14h01. Faltar no dia seguinte mostrou aviso na área CARREIRA.
Reabrir a rota CARREIRA preservou o emprego, a falta e os R$ 95 acumulados.
A campanha principal foi migrada mantendo 16/01/2026 às 19h55, com histórico
anterior intacto, quatro porções iniciais e nenhum erro de console.
CLI seed `rotina-v4`, 90 dias, `--auto-choice first`: mundo válido e cadeias
contextuais. Sem essa opção, a CLI pausa na decisão do jogador; `safe` usa a
última alternativa disponível para testar fast-forward sem impor gastos.
Benchmark CPU local: 1.000 mundos de 100 pessoas em aproximadamente 420 ms.
Não representa FPS nem desempenho Android. Export Android/Hermes passou:
bundle cerca de 3 MB, mais assets/fontes. Saídas em `output/`, ignoradas pelo Git.

## Checkpoints compartilhados

- `7df361c`: laboratório vetorial revisado.
- `1670156`: fundação e save v1.
- `82e83c6`: carreira, cursos, ledger, autonomia social e save v2.
- `99a5700`: motor de decisões/save v3 e fontes autorais Android.
- Entrega atual: localizar em `git log` pelo título
  "Implementa rotina alimentar sono e presenca profissional com save v4".
  Nunca force-push desta branch compartilhada.

Registre aqui resultados medidos e novos limites ao concluir cada entrega.
