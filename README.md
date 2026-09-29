# PARALELO

Simulador de vida textual sistêmico, para Android (Expo / React Native).

A fonte de verdade do projeto é a **bíblia de design**:
[`docs/PARALELO_MASTER_DESIGN_BIBLE.md`](docs/PARALELO_MASTER_DESIGN_BIBLE.md)
(original em `.docx` na mesma pasta). Leia antes de mexer em arquitetura.

> Status: **só estrutura**. Nenhum sistema de jogo foi implementado ainda.
> Próximo passo: Fase 0 do roadmap (bíblia §49 e §67).

## Estrutura (bíblia §80)

```
apps/
  mobile/        App Expo (Android). Só apresentação e input.
    src/screens/  navigation/  components/  hooks/  theme/
  dev-sim/       CLI: gerar mundo, avançar tempo, inspecionar, benchmark.
packages/
  simulation/    Núcleo puro em TS. Nunca importa React/React Native.
    src/domain/  systems/  commands/  queries/  time/  rng/  scheduling/
  content/       Dados: eventos, empregos, cursos, traços, textos, validação.
  persistence/   SQLite, migrações, repositórios.
  shared/        IDs com marca de tipo, Result, tipos comuns.
  ui/            Design tokens (§58), primitivas e padrões visuais.
tests/
  long-run/      Simulações de 1, 5 e 20 anos.
  fixtures/
docs/            Bíblia de design.
```

Fluxo obrigatório: `UI -> Command -> Simulation -> World State -> Query -> UI`.

## Como rodar

Requisitos: Node 20+ e npm.

```bash
npm install          # instala todos os workspaces
npm test             # testes (vitest)
npm run typecheck    # TypeScript strict em todos os pacotes
npm run sim          # CLI dev-sim
npm run mobile       # servidor Expo
```

### No Android

- **Rápido:** instale o app **Expo Go** no celular, rode `npm run mobile`
  e leia o QR code.
- **Emulador:** com Android Studio instalado, `npm run android`.
- **APK instalável:** `cd apps/mobile && npx eas-cli@latest build -p android --profile preview`
  (requer conta Expo; perfis em `apps/mobile/eas.json`).

As pastas nativas `android/` e `ios/` são geradas (`npx expo prebuild`) e não
vão para o git; configure tudo via `apps/mobile/app.json`.

## Primeira entrega recomendada (bíblia §67)

1. monorepo ✅
2. pacote simulation (esqueleto ✅)
3. relógio determinístico
4. RNG com streams nomeados
5. IDs (tipos ✅)
6. Person
7. Relationship
8. WorldState
9. comando simples
10. timeline mínima
11. SQLite/save inicial
12. testes de determinismo
