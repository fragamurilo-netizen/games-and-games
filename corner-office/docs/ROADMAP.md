# Roadmap

Baseado em Game Design Bible §20. Regra: implementar o vertical slice antes de sistemas periféricos; só expandir quando o core loop estiver divertido e estável.

## M0 — Estrutura ✅

- [x] Projeto Godot 4.4 com preset Android
- [x] Arquitetura em camadas, autoloads, modelos de dados serializáveis
- [x] Save versionado com migrações
- [x] Conteúdo canônico em JSON (7 organizações globais, roster de 2027, academias, agências, mídia, regiões, categorias, rulesets)
- [x] Casca de UI com 5 abas (portrait/landscape) e tokens de cor
- [x] Runner de testes headless + CI

## M1 — Loop jogável

- [x] `WorldGenerator`: 211 atletas, elenco regional, elencos rivais e free agents
- [x] Organizações rivais ativas (`OrgAI`: agenda, cards, caixa, adiamentos, renovações, contratações)
- [x] Protótipo da biblioteca de rostos (`prototypes/face-lab/`)
- [x] Fight Studio: catálogo 2D pareado, arenas das sete organizações, replays autorais e sampler Godot ([guia](FIGHT_VISUALS.md))
- [x] Perfis de combate do roster canônico e adaptador de eventos reais para o Fight Studio
- [x] Reutilização do renderer original do Fight Studio em pacote offline para Android
- [ ] Arte final, desempenho da transmissão e QA em aparelho
- [ ] `FaceGenerator`: portar o protótipo para Godot (e/ou integrar o gerador do Mais Uma Rodada — auditar licença/estrutura primeiro)
- [x] Tela Lutadores: roster, perfil (página; bottom sheet pendente), rankings
- [x] `Contracts`: oferta, contraproposta por preço e renovação
- [ ] BATNA com ofertas rivais e memória
- [x] Tela Eventos: montar evento com 6–10 lutas
- [x] `Matchmaking`: sporting fit / acceptance / commercial fit + recusa com reason codes
- [x] Protótipo `FightEngine` + `Judge`: trocas, dano, KO/TKO/submissão, decisões e scorecards
- [x] Tela de luta: round a round em 1x/2x/5x/instantâneo
- [x] `Rankings`: atualização pós-evento + snapshots (fórmula inicial; WCI completo pendente)
- [x] `Economy`: P&L projetado e real
- [x] `Media`: notícias com triggers factuais
- [x] Avançar semana e repetir
- [ ] Testes de simulação: milhares de lutas (distribuição KO/sub/decisão, upsets > 0)
- [x] Screenshots portrait/landscape

## M2 — Mercado vivo

- [ ] Agentes com memória
- [ ] Free agency concorrida
- [ ] Scouting (faixas + confiança)
- [x] Organizações rivais operacionais (IA sem informação privilegiada) — base; falta BATNA/memória
- [ ] Lesões, quedas de luta e substitutos (tela de crise)
- [ ] Weight & camp engine (pesagem, catchweight, multas)
- [ ] Popularidade regional

## M3 — Mundo de longo prazo

- [ ] Regens, aposentadorias, retornos
- [ ] Hall da Fama e recordes
- [ ] Academias dinâmicas
- [ ] Novas organizações surgindo/quebrando
- [ ] História prévia (30–35 anos) e eras detectadas a posteriori
- [ ] Mídia mais profunda
- [ ] Testes de 20–50 anos sem colapso

## M4 — Profundidade de produto

- [ ] Reality show / Prospect Series
- [ ] Grand Prix
- [ ] Patrocinadores
- [ ] Direitos de mídia
- [ ] Realism tiers (Accessible / Promoter / Simulation)
- [ ] Modding (bancos externos)

Estado detalhado e verificações: [HANDOFF.md](HANDOFF.md). M1 não está encerrado.
