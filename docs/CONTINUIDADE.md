# Continuidade do desenvolvimento

Fonte de verdade: `PARALELO_MASTER_DESIGN_BIBLE.md`, especialmente §§36–43,
49, 67, 80–82. Leia a bíblia antes de alterar arquitetura.

Branch compartilhada: `claude/inspiring-cray-82ewil` no remoto `origin`.
Atualize este documento e faça commit/push de cada entrega validada. Nunca
confunda sistemas planejados com funcionalidades já implementadas.

## Entrega atual: primeira campanha jogável

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
- Save v2: snapshot integral em SQLite, atualização e backup anterior em uma
  transação. IDs/referências/intervalos/hash são verificados na carga. Save
  futuro é recusado; corrupção tenta backup sem sobrescrever dados danificados.
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
- Laboratório vetorial em `prototypes/faces`: 133 cabelos, 106 barbas, 19 roupas,
  corpos contínuos, idades, ancestrais e herança. Commit `7df361c`.

## Como verificar e continuar

Use Node 24 e execute `npm ci`, `npm test`, `npm run typecheck`,
`npm --workspace apps/mobile run lint`. Depois `npm run mobile` para Android ou
`npm --workspace apps/mobile run web`. O laboratório abre separadamente com
`python -m http.server 8765 --bind 127.0.0.1` dentro de `prototypes/faces`.

Há 31 testes cobrindo determinismo, relógio, eventos, comandos recusados,
read models isolados, SQLite real, rollback, backup, saves futuros/corrompidos,
duplo toque, falha de gravação e integridade durante 1, 5 e 20 anos.
As corridas longas verificam integridade financeira e social; não demonstram
balanceamento de uma vida completa. Ainda não há macroeconomia ou envelhecimento
com morte/legado. Também há testes de curso, contratação, turno e conservação do ledger.

## Save e migrações

SQLite `PRAGMA user_version = 1`: tabela `saves(slot, payload)`; slots `current`
e `previous`. Envelope JSON `schemaVersion = 2`, hash e WorldState v2. O save
do laboratório (`paralelo-character`) é independente do save da campanha.
Migração v1 -> v2 em `systems/slice.ts`: preserva pessoas originais, relações,
timeline, seed, relógio e cursores RNG. Acrescenta cidade/finanças/carreira via
namespace determinística independente. Fixture produzida com o gerador do
commit de fundação `1670156` em `tests/fixtures/legacy-save-v1.json`; testes
verificam migração, persistência e preservação da versão antiga como backup.
Ao adicionar campos obrigatórios, criar migração explícita e teste de fixture
da versão anterior; não aceitar silenciosamente dados incompletos.

## Limitações conhecidas

Sem validação em dispositivo Android físico/APK nesta entrega. Web é o ambiente
de inspeção disponível. O retrato vetorial ainda não é integrado à campanha.
Person e Relationship são modelos iniciais; crenças, macroeconomia, mensagens
respondíveis, Utility AI completa, promoção/demissão e troca de emprego faltam.
Empregos e contas só são simulados para o jogador. Moradia é fixa. O registro
MUNDO deriva de fatos da campanha, não é um sistema de jornalismo da cidade.
As taxas de energia/stress são provisórias e não representam rotina de sono.
O hash de diagnóstico não é criptográfico. Histórico de comandos guarda os
últimos 256; timeline persistida é integral e query mostra os últimos 80.

## Próximas entregas, na ordem

1. Eventos data-driven, decisões com consequências e cadeias; prioridade à
   variedade contextual da escrita. Atualmente IA repete mensagens da mudança.
2. Ampliar rotina, necessidades e agenda; fome e obrigações de trabalho pendentes.
3. Utility AI, empregos/finanças dos NPCs, mensagens respondíveis e crenças.
4. Promoções/demissões, despesas detalhadas, dívidas, macroeconomia e mudanças.
5. Completar o slice de §48: 20 NPCs relevantes, 30 eventos, 10 cadeias e notícias.
6. Portar renderer/genoma vetorial para TS e react-native-svg sem duplicar a
   fonte de verdade; só depois acrescentar retratos às listas de pessoas.

## Validação e performance desta entrega

`npm test`: 31 testes. `npm run typecheck`: todos os workspaces.
`npm --workspace apps/mobile run lint` e `npx expo install --check`: executados.
Web: navegação, ações, extrato, autosave e retomada/migração inspecionados no browser.
CLI seed `flores`, 90 dias: mundo válido. Benchmark CPU local: 1.000 mundos de
100 pessoas em aproximadamente 322 ms. Não representa FPS nem desempenho Android.

Registre aqui resultados medidos e novos limites ao concluir cada entrega.
