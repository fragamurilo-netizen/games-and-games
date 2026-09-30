# Continuidade do desenvolvimento

Fonte de verdade: `PARALELO_MASTER_DESIGN_BIBLE.md`. Decisões explícitas do dono vêm
logo depois; quando conflitam com a bíblia, estão registradas abaixo em
"Decisões e contradições". Leia a bíblia e `CLAUDE.md` antes de mexer em arquitetura.

Branch compartilhada: `claude/inspiring-cray-82ewil` (PR #59). Faça `git pull` antes
de começar; outros agentes (Codex, Claude) também empurram nela. Nunca force-push.
Atualize este documento a cada entrega validada e nunca descreva como pronto o que
só está planejado.

## Estado atual: save v8

`npm test`: 104 testes, todos verdes. `npm run typecheck`: limpo em todos os workspaces.
20 anos simulados em ~3,7 s no teste longo (limite do vitest: 5 s).

### Simulação (`packages/simulation`)

| Versão | Sistema | Arquivos principais |
|---|---|---|
| v1–v4 | relógio, RNG por streams, pessoas, relações, carreira básica, cursos, ledger, eventos (30 em 10 cadeias), rotina (fome, sono, despensa), presença | `systems/slice.ts`, `events.ts`, `routine.ts`, `career.ts` |
| v5 | sexo pelo nome (aparência) | `systems/appearance.ts` |
| v6 | **mundo vivo**: moradores com emprego/objetivo e IA por utilidade com inércia (§13); economia semanal das empresas com quadro e rotatividade; jornal; mensagens com prazo (responder, ligar, adiar; silêncio esfria a relação) | `systems/city.ts`, `content/city.ts` |
| v7 | **trabalho vivido** (§7, §15, §61): líder por empresa; turno com situação no meio (32 situações por família de função); pontualidade até 8h30; tarefa semanal; conversa do mês (aumento, advertência, demissão por desempenho, promoção por processo interno); candidatura vira entrevista marcada e preparável, com concorrência | `systems/work.ts`, `content/work.ts` |
| v8 | **corpo e aparência** (§21): peso por balanço calórico (Mifflin-St Jeor, 7.700 kcal/kg), força e fôlego por treino com retorno decrescente e perda sem prática, academia com mensalidade, barba e cabelo, guarda-roupa, roupa do dia para todos por clima, compromisso e sorteio, código de vestimenta no trabalho, "presença" pesando em entrevistas, espelho em frases | `systems/body.ts`, `content/body.ts` |

Outros módulos:
- Timeline com peso editorial, resumo de rotina e compactação (§6.2–6.4): `timeline.ts`.
- Começo da campanha (§47): nome, corpo, idade e ponto de partida em `systems/onboarding.ts`.
- Ferramentas (§42): `queries/debug.ts` (inspector de pessoa e de evento, estatísticas);
  CLI `npm run sim -- --seed x --days 365 --auto-choice safe --stats --events --inspect person:player --quiet`.
- `test-support.ts`: ajudantes que jogam como uma pessoa (resolvem cenas, vão a entrevistas).

### App (`apps/mobile`)

- Começo da campanha (`screens/start-screen.tsx`), Vida com cena, régua do dia, mensagens,
  timeline por dia; Pessoas por círculo com histórico; Carreira no formato do §61;
  Mundo com jornal; cenas em tela cheia para decisão e trabalho (`components/game-feel.tsx`).
- Personagens 2D do renderizador vetorial (`packages/characters`), via `drawCharacter`.
- Corpo no app: toda query que devolve `appearance` traz `appearance.look` (`appearanceOf` em
  `systems/body.ts`); `Portrait` e `LifeScene` desenham gordura, músculo, roupa do dia e barba.
  `drawCharacter` transforma `look.stubbleDays` em barba (`beardAfter`: por fazer a partir de
  2 dias, curta a partir de 6, cheia a partir de 15) só para quem anda barbeado por estilo.
- Seção "Corpo" e "Roupa de hoje" na Vida (`components/body-section.tsx`, `queryBody`): espelho
  em frases e peso da balança, caminhar/correr/treinar em casa (academia só com matrícula),
  barba, cabelo, lanche; guarda-roupa e loja recolhidos. Academia (matrícula e cancelamento)
  em Dinheiro.

## O que falta na frente atual (corpo e aparência, v8)

Corpo e aparência estão na simulação e no app (acima), com teste de migração v7→v8.
Correção junto: `beginLife` refaz corpo e guarda-roupa do jogador pelo sexo e idade escolhidos
(antes, quem escolhia outro sexo que o rascunho da seed ficava com roupas do rascunho).
Saves já começados com esse defeito não são corrigidos: a peça fica no guarda-roupa, sem efeito
além do nome na lista.

Falta:
1. Verificar no Android real (Expo Go): peso da tela Vida com a seção nova e o custo do
   redesenho do SVG quando a roupa muda. Na web (export + Chromium) a seção aparece e funciona.
2. **Saúde (§21) ainda não existe.** Hoje há um piso fisiológico provisório para quem não
   come (em `processDailyBody`). Fome prolongada, doença e consequências precisam do
   sistema de saúde, com cuidado de representação (§21.3, §21.4).

## Próximas frentes, na ordem combinada com o dono

1. ~~Terminar corpo e aparência no app~~ (feito; falta só verificar no Android).
2. **Escola e formação + profissões ampliadas.** Instituições com horário, custo,
   pré-requisito e credencial (§16): escola para crianças NPC, supletivo, curso técnico,
   faculdade. Dezenas de profissões por setor, exigindo formação, cada uma com família,
   situações de turno, salário e degrau seguinte (`roleCareer`). Ver decisão 1.
3. **Relações realistas** (§11): conhecer gente em lugares (trabalho, academia, escola),
   amizade por tempo junto, atração e romance, brigas e afastamento, casais e términos
   entre NPCs. O campo `attraction` já existe na relação; `presenceOf` já existe para
   primeiras impressões.
4. **Envelhecimento e gerações** (§22): corpo e saúde mudando com a idade, nascimentos,
   mortes, família mudando, crianças indo à escola.

Pedido do dono que orienta tudo: "tem que ser vontade de jogar, não SaaS" e "os menus e
jogos não parecem divertidos ainda". Priorize mudanças visíveis (o personagem muda,
as pessoas reagem) e escolhas com custo real.

## Decisões e contradições registradas

1. **"Adicionar todos os trabalhos possíveis"** × bíblia §65 (quantidade de profissões é o
   primeiro corte) e §3 (sem listas gigantes de opções equivalentes). Decisão: ampliar
   muito, por setores, com formação exigida e impacto real, sem lista infinita.
2. **"Adicionar escola"** × §48 (o jogador começa adulto jovem). Decisão: a escola existe
   no mundo (crianças NPC) e o jogador acessa supletivo, técnico e faculdade. Começar
   a vida criança fica para depois.
3. **"Ficar mais bonito/feio"** × §3 e §8.1 (sem barras e números para atributos humanos).
   Decisão: aparência muda no desenho e em frases; o número interno (`presenceOf`)
   nunca aparece na tela.
4. Personagens: o dono preferiu o renderizador 2D do Codex ao 2,5D; o 2,5D foi removido.

## Save e migrações

Envelope JSON `{ schemaVersion: 8, hash, world }` em SQLite (slots `current` e `previous`).
Cadeia explícita em `packages/persistence/src/snapshot.ts`:
v1→v2 `slice.ts`, v2→v3 `events.ts`, v3→v4 `routine.ts`, v4→v5 `appearance.ts`,
v5→v6 `city.ts`, v6→v7 `work.ts`, v7→v8 `body.ts`. Cada versão tem validador próprio
em `validation.ts`. Migrações não consomem RNG salvo (usam hash de seed e entidade).
Ao adicionar campo obrigatório: novo tipo `WorldStateVN`, `upgradeWorldVN`,
`validateWorldVN`, entrada na cadeia do snapshot e teste de migração.

## Como verificar

Node 22.13+ (24 recomendado). `npm ci`, `npm test`, `npm run typecheck`.
App: `npm run mobile` (Expo Go no Android) ou `cd apps/mobile && npx expo start --web`.
APK: `cd apps/mobile && npx eas-cli build -p android --profile preview` (conta Expo).
Personagens: `node prototypes/faces/check-characters.cjs`.

## Limitações conhecidas

- Sem saúde, doença ou morte; piso fisiológico provisório no corpo.
- Crenças (§79), moradia variável, dívidas e retrospectiva anual ainda não existem.
- O teste de 20 anos está a ~1,3 s do limite de 5 s do vitest; ao somar sistemas
  diários, use nível de detalhe (jogador diário, NPCs em lote semanal) como em
  `processDailyBody` e `processDailyCity`.
- Web é ambiente auxiliar; Android é o alvo. Não há SDK Android nesta máquina.
