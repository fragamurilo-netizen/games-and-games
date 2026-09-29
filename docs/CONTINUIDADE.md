# Continuidade do desenvolvimento

Fonte de verdade: `PARALELO_MASTER_DESIGN_BIBLE.md`, especialmente §§36–43,
49, 67, 80–82. Leia a bíblia antes de alterar arquitetura.

Branch compartilhada: `claude/inspiring-cray-82ewil` no remoto `origin`.
Atualize este documento e faça commit/push de cada entrega validada. Nunca
confunda sistemas planejados com funcionalidades já implementadas.

## Entrega atual: fundação jogável

- Núcleo TS puro em `packages/simulation`: relógio Gregorian sem Date do sistema,
  RNG de seis streams independentes, IDs estáveis, pessoas, relações, agenda,
  comandos, timeline, queries, validação e hash de diagnóstico.
- Cenário inicial pequeno: adulto jovem, moradia, mãe e dois amigos em Santa
  Aurora. Conteúdo em `packages/content`; não é o slice de 100–500 pessoas ainda.
- Descansar recupera energia; ligar consome tempo e pode não obter resposta;
  contatos têm intervalo de oito horas. Skip para em mensagens importantes.
- `GameSession` é a dona da campanha na aplicação. UI assina o read model e
  envia comandos; persistência precede a publicação da transição.
- Expo Router e tela VIDA em `apps/mobile/src/app`; SQLite Android/web na borda,
  via `apps/mobile/src/persistence`. Web exige WASM e COOP/COEP, configurados no Metro.
- Save v1: snapshot integral em SQLite, atualização e backup anterior em uma
  transação. IDs/referências/intervalos/hash são verificados na carga. Save
  futuro é recusado; corrupção tenta backup sem sobrescrever dados danificados.
- CLI `apps/dev-sim`: seed, fast-forward, inspeção, benchmark e snapshot JSON.
- Laboratório vetorial em `prototypes/faces`: 133 cabelos, 106 barbas, 19 roupas,
  corpos contínuos, idades, ancestrais e herança. Commit `7df361c`.

## Como verificar e continuar

Use Node 24 e execute `npm ci`, `npm test`, `npm run typecheck`,
`npm --workspace apps/mobile run lint`. Depois `npm run mobile` para Android ou
`npm --workspace apps/mobile run web`. O laboratório abre separadamente com
`python -m http.server 8765 --bind 127.0.0.1` dentro de `prototypes/faces`.

Há 22 testes cobrindo determinismo, relógio, eventos, comandos recusados,
read models isolados, SQLite real, rollback, backup, saves futuros/corrompidos,
duplo toque, falha de gravação e integridade durante 1, 5 e 20 anos.
As corridas longas verificam esta fundação; não demonstram balanceamento de uma
vida completa, pois ainda não há economia, IA ou carreira.

## Save e migrações

SQLite `PRAGMA user_version = 1`: tabela `saves(slot, payload)`; slots `current`
e `previous`. Envelope JSON `schemaVersion = 1`, hash e WorldState v1. O save
do laboratório (`paralelo-character`) é independente do save da campanha.
Ao adicionar campos obrigatórios, criar migração explícita e teste de fixture
da versão anterior; não aceitar silenciosamente dados incompletos.

## Limitações conhecidas

Sem validação em dispositivo Android físico/APK nesta entrega. Web é o ambiente
de inspeção disponível. O retrato vetorial ainda não é integrado à campanha.
Person e Relationship são modelos iniciais; memórias, crenças, empregos, ledger,
economia, mensagens respondíveis e IA de NPC não estão implementados ainda.
As taxas de energia/stress são provisórias e não representam rotina de sono.
O hash de diagnóstico não é criptográfico. Histórico de comandos guarda os
últimos 256; timeline persistida é integral e query mostra os últimos 80.

## Próximas entregas, na ordem

1. Rotina diária e ações com custos claros; agenda e contexto para cada pessoa.
2. Carreira/financeiro: empresas persistentes, vagas, seleção, emprego, salário,
   despesas e ledger inteiro em centavos, com causas e testes de conservação.
3. Autonomia dos NPCs, memórias de contato, mensagens e decisões contextuais.
4. Eventos data-driven e cadeias com condições/efeitos validados.
5. Expandir a cidade até o slice de §48 e testar seeds de três meses.
6. Portar renderer/genoma vetorial para TS e react-native-svg sem duplicar a
   fonte de verdade; só depois acrescentar retratos às listas de pessoas.

Registre aqui resultados medidos e novos limites ao concluir cada entrega.
