# Regras para agentes (resumo da bíblia §50, §67, §81)

Leia `docs/PARALELO_MASTER_DESIGN_BIBLE.md` antes de alterações estruturais.
A bíblia é a fonte de verdade; decisões explícitas do dono do projeto vêm logo depois.
Se duas seções conflitarem, registre a contradição antes de escolher.

## Sempre
- Investigar o que já existe; integrar em vez de duplicar.
- Manter simulação fora da UI: `packages/simulation` não importa React/React Native
  e roda testes em Node.
- TypeScript strict, sem `any` no domínio. IDs com marca (`@paralelo/shared`).
- `Result<T, E>` para validações esperadas, não exceções.
- Determinismo: RNG injetado com streams nomeados; nunca `Math.random()` nem
  `Date` do sistema na simulação.
- Conteúdo data-driven e validado (`packages/content`); nada de uma classe por evento.
- Todo save tem `schemaVersion`; registrar migrações.
- Escrever testes; preservar determinismo.
- UI editorial (bíblia §27–31, tokens em `packages/ui`): linhas antes de cards,
  sem emojis, sem barras para atributos humanos, acento verde raro.
- Texto em pt-BR, concreto e sem "voz de IA" (§25, §32, §74).

## Nunca
- Criar GameManager2, jogar lógica em Zustand/Redux ou guardar verdade do domínio em estado de tela.
- Depender de LLM em runtime para gameplay.
- Criar dezenas de cards porque é mais fácil.
- Reescrever o projeto por conveniência.
- Editar `apps/mobile/android` ou `ios` à mão (são gerados).

## Comandos
- `npm test` · `npm run typecheck` · `npm run sim` · `npm run mobile`
- Dependências do app: `cd apps/mobile && npx expo install <pacote>`.

## Ao entregar uma tarefa, responder com
Implementado · Arquivos · Testes executados · Impacto em save · Performance ·
Limitações · Próximo passo lógico.
