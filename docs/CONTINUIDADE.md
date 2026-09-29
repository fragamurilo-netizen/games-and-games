# Continuidade do desenvolvimento

Fonte de verdade: `PARALELO_MASTER_DESIGN_BIBLE.md`, especialmente §§36–43,
49, 67, 80–82. Leia a bíblia antes de alterar arquitetura.

Branch compartilhada: `claude/inspiring-cray-82ewil` no remoto `origin`.
Atualize este documento e faça commit/push de cada entrega validada. Nunca
confunda sistemas planejados com funcionalidades já implementadas.

## Entrega atual: campanha Android com decisões

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
- Save v3: snapshot integral em SQLite, atualização e backup anterior em uma
  transação. IDs/referências/intervalos/hash são verificados na carga. Save
  futuro é recusado; corrupção tenta backup sem substituir a cópia válida por
  dados danificados. Se ambas as cópias falharem, nenhuma é sobrescrita.
- CLI `apps/dev-sim`: seed, fast-forward, inspeção, benchmark e snapshot JSON.
- Cursos cobram aulas, desenvolvem habilidade e têm conclusão e limite diário.
  Habilidades condicionam candidaturas; seleção é determinística e tem cooldown.
  Contratação fecha a vaga. Trabalho tem turno de oito horas, dias úteis e limite
  de um turno por dia. Cada turno acumula 1/20 do salário de referência.
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

Há 37 testes cobrindo determinismo, relógio, eventos, comandos recusados,
read models isolados, SQLite real, rollback, backup, saves futuros/corrompidos,
duplo toque, falha de gravação e integridade durante 1, 5 e 20 anos.
As corridas longas verificam integridade financeira e social; não demonstram
balanceamento de uma vida completa. Ainda não há macroeconomia ou envelhecimento
com morte/legado. Também há testes de curso, contratação, turno e conservação do ledger.

## Save e migrações

SQLite `PRAGMA user_version = 1`: tabela `saves(slot, payload)`; slots `current`
e `previous`. Envelope JSON `schemaVersion = 3`, hash e WorldState v3. O save
do laboratório (`paralelo-character`) é independente do save da campanha.
Migração v1 -> v2 em `systems/slice.ts`: preserva pessoas originais, relações,
timeline, seed, relógio e cursores RNG. Acrescenta cidade/finanças/carreira via
namespace determinística independente. Fixture produzida com o gerador do
commit de fundação `1670156` em `tests/fixtures/legacy-save-v1.json`; testes
verificam migração, persistência e preservação da versão antiga como backup.
Migração v2 -> v3 em `systems/events.ts`: preserva os sistemas existentes e
acrescenta estado/agenda de decisões sem consumir RNG. Fixture v2 gerada no
checkpoint `82e83c6`; decisões pendentes e follow-ups são salvos integralmente.
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
respondíveis gerais, Utility AI completa, promoção/demissão e troca de emprego faltam.
Empregos e contas só são simulados para o jogador. Moradia é fixa. O registro
MUNDO deriva de fatos da campanha, não é um sistema de jornalismo da cidade.
As taxas de energia/stress são provisórias e não representam rotina de sono.
O hash de diagnóstico não é criptográfico. Histórico de comandos guarda os
últimos 256; timeline persistida é integral e query mostra os últimos 80.

## Próximas entregas, na ordem

1. Validar APK/emulador Android: abertura offline, fonte ampliada, voltar,
   background, retomada, duplo toque e SQLite real no aparelho.
2. Ampliar rotina, necessidades e agenda; fome e obrigações de trabalho pendentes.
3. Utility AI, empregos/finanças dos NPCs, mensagens respondíveis e crenças.
4. Promoções/demissões, despesas detalhadas, dívidas, macroeconomia e mudanças.
5. Completar o slice de §48: promover 20 NPCs relevantes, educação aprofundada,
   notícias da cidade e campanhas de três meses com trabalho e decisões.
6. Portar renderer/genoma vetorial para TS e react-native-svg sem duplicar a
   fonte de verdade; só depois acrescentar retratos às listas de pessoas.

## Validação e performance desta entrega

`npm test`: 37 testes, incluindo as 60 escolhas dos 30 eventos, cadeia completa,
replay de decisão recusado, opção sem saldo, retomada pendente e migrações v1/v2.
`npm run typecheck`: todos os workspaces.
`npm --workspace apps/mobile run lint` e `npx expo install --check`: executados.
Web: navegação, ações, extrato, autosave e retomada/migração inspecionados no browser.
Em campanha separada de QA, decisão interrompeu às 19h, permaneceu pendente após
reabrir e gerou entrada de R$ 50 às 21h após duas horas de serviço. As cinco fontes
carregaram e não houve erros no console. Campanha do usuário foi preservada.
CLI seed `flores`, 90 dias, `--auto-choice first`: mundo válido e cadeias
contextuais. Sem essa opção, a CLI pausa na decisão do jogador; `safe` usa a
última alternativa disponível para testar fast-forward sem impor gastos.
Benchmark CPU local: 1.000 mundos de 100 pessoas em aproximadamente 414 ms.
Não representa FPS nem desempenho Android. Export Android/Hermes passou:
bundle cerca de 3 MB, mais assets/fontes. Saídas em `output/`, ignoradas pelo Git.

## Checkpoints compartilhados

- `7df361c`: laboratório vetorial revisado.
- `1670156`: fundação e save v1.
- `82e83c6`: carreira, cursos, ledger, autonomia social e save v2.
- Entrega atual: motor de decisões/save v3 e fontes autorais Android; localizar
  em `git log` pelo título "Adiciona decisoes encadeadas e tipografia autoral para Android".
  Nunca force-push desta branch compartilhada.

Registre aqui resultados medidos e novos limites ao concluir cada entrega.
