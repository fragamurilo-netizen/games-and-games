# Mais Uma Rodada

Simulador de gestão de futebol para **Android**, feito em **Godot 4.7** — offline, leve, em retrato e pensado
para aquele "só mais uma rodada" honesto: sem energia, sem timers, sem loot boxes. A vontade de continuar
vem da própria simulação.

> Todos os clubes, jogadores e o país de **Valdora** são fictícios.

## O que já dá para jogar (versão 0.1.0 · MVP 1)

- **Mundo vivo**: 80 clubes em 4 divisões (20 cada), ~2.000 jogadores procedurais com 15 atributos,
  potencial oculto (mostrado como estimativa), curvas de carreira, personalidades e histórico.
  Mundo padrão (seed fixo) ou aleatório (clubes e cidades novos).
- **Clubes com identidade**: 15 arquétipos (gigante endividado, rico recém-promovido, clube formador,
  tradição em crise...) que mudam finanças, base, IA de mercado e paciência da torcida. Escudos,
  uniformes e rostos gerados proceduralmente.
- **Temporada completa**: 38 rodadas (turno e returno), tabela com desempate, artilharia, assistências,
  acesso e rebaixamento (4/4), premiação e virada de ano.
- **Motor de partidas estatístico** minuto a minuto: setores, táticas, estilos, mando, clássicos, fadiga,
  cartões, lesões, pênaltis, substituições e acréscimos. Zebras existem, mas são raras.
- **Partida ao vivo** em campo 2D com narração procedural, placar dos outros jogos, velocidade
  Normal / Rápido / Turbo, pausa para tática e substituições, e comemoração proporcional ao momento
  (um gol aos 90+4 não é o quinto de uma goleada).
- **Escalação e tática**: 8 formações, 5 mentalidades, 6 estilos, intensidade, linha, pressão e bola parada.
- **Mercado**: busca com filtros, jogadores livres, propostas e contrapropostas, termos pessoais, renovação,
  venda, rescisão e propostas da IA pelo seu elenco. A IA negocia entre si.
- **Carreira**: diretoria com meta e confiança (ultimato e demissão no fim da temporada), torcida,
  finanças, investimento em estrutura e base, notícias geradas com dados reais do save, Hall da Fama.
- **Save** automático por rodada, 5 espaços, escrita atômica com backup e determinismo total
  (mesmo seed + mesmas decisões = mesmo mundo).

## Novidades da versão 0.2 (em andamento)

- **Prêmios**: craque, artilheiro, garçom, revelação e melhor de cada setor em todas as ligas, seleção do
  campeonato, craque de cada copa, Bola de Ouro com votação dos 10 mais, revelação mundial, Chuteira de Ouro
  e craque do clube. Seleção da rodada e seleção do mês (com craque do mês) na liga do usuário.
- **Troféus**: cada liga e copa tem um troféu desenhado (formato próprio, metal pela divisão, fita nas cores do
  país) e o clube ganha uma sala de troféus.
- **Temporadas anteriores**: tabela final, artilharia, assistências, notas, prêmios, Bola de Ouro, seleções do
  mês e os números do seu elenco em cada ano. No perfil, a carreira temporada a temporada com gráfico do overall.
- **Personalidade viva**: traços novos (mentor, resiliente, perfeccionista, cascudo, ídolo da torcida) e traços
  que surgem ou somem com a idade, os prêmios, a fase e o tempo de clube.
- **Evolução e declínio**: quem joga bem cresce mais, mentores aceleram os jovens, lesões graves custam físico,
  cada corpo envelhece no seu ritmo e veteranos ganham leitura de jogo enquanto o físico cai.

## Estrutura do repositório

```text
docs/ARQUITETURA.md      documento técnico (decisões, módulos, motor, economia, balanceamento)
mais-uma-rodada/         projeto Godot — abra esta pasta no editor
  data/                  todo o conteúdo em JSON (clubes, nomes, táticas, narração, notícias)
  scripts/               núcleo (models, generation, systems), autoloads e interface
  scenes/                cenas das telas e componentes
  tests/                 testes automáticos e simulador de temporadas
  tools/                 gerador do tema e passeio automático pelas telas (capturas)
```

## Rodando

1. Instale o [Godot 4.7.2](https://godotengine.org/download) (versão padrão, não a .NET).
2. Abra `mais-uma-rodada/project.godot` no editor e aperte **F5**. A janela abre em 450×900 (retrato);
   a interface é desenhada para 720×1280 e se adapta a qualquer proporção.

## Testes

```bash
cd mais-uma-rodada
godot --headless --import
godot --headless --script res://tests/run_tests.gd                 # 11 testes do núcleo (~35 s)
godot --headless --script res://tools/screenshot_tour.gd           # percorre todas as telas com uma carreira real
godot --headless --script res://tests/season_simulator.gd -- --seasons=100 --out=user://relatorio.md
```

O simulador imprime, por temporada: média de gols, mando, transferências, idade média, força média por
divisão, jogadores 80+, finanças, campeões, jovens gerados e aposentadorias — e um resumo final.
Com vídeo (ou `xvfb-run`), o passeio salva capturas: `... screenshot_tour.gd -- --out=/tmp/capturas`.

## Gerando o APK

O preset **Android** já está em `export_presets.cfg` (retrato, arm64-v8a + armeabi-v7a, permissão de vibração).

1. No editor: *Editor → Gerenciar Modelos de Exportação* → baixe os modelos da 4.7.2.
2. Em *Editor → Configurações do Editor → Exportar → Android*, aponte o Android SDK (e o JDK 17+).
3. *Projeto → Exportar → Android → Exportar Projeto*. Ou pela linha de comando:

```bash
godot --headless --path mais-uma-rodada --export-debug "Android" build/MaisUmaRodada-debug.apk
```

Para publicar, gere um keystore de release e use `--export-release`.

## Roteiro

| MVP | Conteúdo | Status |
|---|---|---|
| 1 | Mundo, temporada, motor, partida 2D, escalação/tática, mercado, evolução, finanças, diretoria, notícias, save | **jogável** |
| 2 | Eventos com decisões (personalidades em conflito, pedidos de saída), contratos avançados, empréstimos | próximo |
| 3 | Copa Nacional, scouts, editores de escudo/uniforme, recordes, aposentados virando treinadores | planejado |
| 4 | Polimento de áudio e animações, balanceamento fino, otimização para aparelhos modestos | planejado |

## Licenças

Código do jogo: deste repositório. Fontes Barlow / Barlow Condensed (Jeremy Tribby) sob SIL Open Font
License 1.1 (`mais-uma-rodada/assets/fonts/OFL.txt`). Godot Engine sob licença MIT.
