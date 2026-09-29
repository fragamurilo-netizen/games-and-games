# PARALELO

Simulador de vida textual sistêmico, para Android (Expo / React Native).

A fonte de verdade do projeto é a **bíblia de design**:
[`docs/PARALELO_MASTER_DESIGN_BIBLE.md`](docs/PARALELO_MASTER_DESIGN_BIBLE.md)
(original em `.docx` na mesma pasta). Leia antes de mexer em arquitetura.

> Status: **primeira campanha jogável**, com motor puro, relógio, RNG, 100 pessoas,
> relações/memórias, carreira, cursos, extrato, 30 eventos/10 cadeias e save SQLite. As cinco áreas do app
> executam ou consultam o estado real da campanha.
> Continuidade para colegas: [`docs/CONTINUIDADE.md`](docs/CONTINUIDADE.md).

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

Requisitos: Node 22.13+ e npm; Node 24 recomendado para os testes com SQLite nativo.

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

## Primeira entrega (bíblia §67)

1. monorepo ✅
2. pacote simulation puro ✅
3. relógio determinístico ✅
4. RNG com streams nomeados ✅
5. IDs (tipos ✅)
6. Person inicial ✅
7. Relationship inicial ✅
8. WorldState ✅
9. comandos de descanso, contato e passagem de tempo ✅
10. timeline mínima ✅
11. SQLite/save inicial com backup ✅
12. testes de determinismo e save ✅

```bash
npm run sim -- --seed flores --days 7 --auto-choice safe --save campanha.json
npm run sim -- --load campanha.json --rest --contact person:mother
npm run sim -- --seed flores --days 7305 --auto-choice safe --benchmark 1000
npm --workspace apps/mobile run web
npm --workspace apps/mobile run lint
```

O laboratório vetorial continua em [`prototypes/faces`](prototypes/faces/README.md).
Ainda é um protótipo independente; sua integração aos retratos mobile é uma tarefa
explicitamente registrada no documento de continuidade.
