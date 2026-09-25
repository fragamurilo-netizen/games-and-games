# Mais Uma Rodada

Simulador de gestão de futebol para **Android**, feito em **Godot 4.7** — offline, leve, em retrato e pensado
para aquele "só mais uma rodada" honesto: sem energia, sem timers, sem loot boxes. A vontade de continuar
vem da própria simulação.

> Clubes, estádios e ligas usam os **nomes reais** apenas como referência, sem vínculo oficial.
> Todos os jogadores são fictícios.

## O que já dá para jogar (versão 0.1.0 · MVP 1)

- **Mundo vivo**: 692 clubes reais em 53 ligas de 43 países (nenhum clube inventado), ~16 mil jogadores procedurais com 15 atributos,
  potencial oculto (mostrado como estimativa), curvas de carreira, personalidades e histórico.
  Mundo padrão (seed fixo) ou aleatório (reputações, perfis e jogadores novos).
- **Clubes com identidade**: 15 arquétipos (gigante endividado, rico recém-promovido, clube formador,
  tradição em crise...) que mudam finanças, base, IA de mercado e paciência da torcida. Escudos,
  uniformes e rostos gerados proceduralmente.
- **Temporada completa**: 38 rodadas (turno e returno), tabela com desempate, artilharia, assistências,
  acesso e rebaixamento (4/4), premiação e virada de ano.
- **Estaduais**: Paulistão, Carioca, Mineiro, Gauchão, Paranaense, Catarinense, Cearense e Goianão, mais Copa do
  Nordeste e Copa Verde para os estados menores. Primeira fase em grupos no meio de semana, semifinal em jogo
  único e final em ida e volta. Holanda, Portugal, Turquia e Arábia Saudita com ligas de 18 clubes reais,
  mais Serie B italiana e Liga Portugal 2 com acesso e rebaixamento.
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
- **Premiações votadas**: os indicados saem na reta final (30 à Bola de Ouro, 5 finalistas a craque da liga, 3 a
  treinador) e o vencedor sai de um júri. Na Bola de Ouro, um jornalista de cada país ranqueia 10 nomes
  (15-12-10-8-7-5-4-3-2-1), puxando um pouco para o próprio país; títulos do clube e da seleção pesam, e a votação
  só fecha depois do torneio de seleções do verão. O craque e o treinador da liga são votados pelos técnicos, que
  não podem escolher o próprio elenco. Novos prêmios: treinador da temporada (você pode ganhar), treinador do ano,
  Luva de Ouro, melhor goleiro do mundo e seleção do ano.
- **Imprensa com memória**: os setoristas cravam palpites na pré-temporada e cobram no fim; termômetro do cargo e
  bolsa de apostas de quem cai primeiro; rumores de mercado com fonte (veículo sério costuma acertar, o
  sensacionalista inventa) e placar de acertos de cada um; coletiva na zona mista depois de jogos marcantes; frases
  como "somos candidatos" voltam para cobrar semanas depois; jogadores dão entrevista para elogiar ou desabafar.
- **Troféus**: cada liga e copa tem um troféu desenhado (formato próprio, metal pela divisão, fita nas cores do
  país) e o clube ganha uma sala de troféus.
- **Temporadas anteriores**: tabela final, artilharia, assistências, notas, prêmios, Bola de Ouro, seleções do
  mês e os números do seu elenco em cada ano. No perfil, a carreira temporada a temporada com gráfico do overall.
- **Personalidade viva**: traços novos (mentor, resiliente, perfeccionista, cascudo, ídolo da torcida) e traços
  que surgem ou somem com a idade, os prêmios, a fase e o tempo de clube.
- **Passado real**: o mundo padrão já começa com os campeões reais desde 2005 (Premier League, LaLiga,
  Serie A, Bundesliga, Ligue 1, Liga Portugal, Eredivisie, Süper Lig, Escócia, Brasileirão, MLS, Champions,
  Libertadores, Concachampions, África, Ásia e Mundial) e os títulos de todos os tempos dos clubes na sala de
  troféus (`data/world/history.json`). Ligas sem dados reais ganham um passado gerado pela reputação.
- **Evolução e declínio**: quem joga bem cresce mais, mentores aceleram os jovens, lesões graves custam físico,
  cada corpo envelhece no seu ritmo e veteranos ganham leitura de jogo enquanto o físico cai.
- **Copas de verdade**: 43 copas nacionais com nome real (Copa do Brasil, FA Cup, Copa del Rey, Coppa Italia,
  DFB-Pokal, Coupe de France, Taça de Portugal, U.S. Open Cup, Copa do Imperador...), copas da liga (EFL Cup,
  Taça da Liga...) e 24 supercopas (Community Shield, Supercopa do Brasil, Supercopa Europeia, Recopa...). Fase
  preliminar, grandes entrando direto, ida e volta onde é assim na vida real, mando do menor, final em campo
  neutro e vaga continental para o campeão. Campeões reais desde 2005 na sala de troféus.
- **Força realista**: elencos calibrados na escala da vida real (Real Madrid ~86, Man City ~85, Flamengo ~76,
  Série D ~54), craques raros (poucos passam de 88) e no auge entre 23 e 31 anos, goleiros que amadurecem mais
  tarde, potenciais com teto de 94. O motor de partidas pesa a qualidade do elenco mais que os ajustes táticos:
  em simulações, a correlação entre a força do elenco e a posição final é de ~0,84, como no futebol real.
- **Carreira anterior mais crível**: jogos de copa em cada temporada, menos trocas de clube (passagens longas nos
  grandes) e jogos e gols pela seleção desde antes do jogo começar.
- **Filosofias reais de clubes** (`data/gameplay/club_policies.json`): o Athletic só escala bascos e tem uma das
  melhores bases do mundo, o Chivas só mexicanos, Red Bull e Brighton compram jovens, os árabes buscam estrelas
  experientes; bases fortes em La Masia, Ajax, Benfica, Santos, Fluminense, São Paulo e outros.
- **Uniforme de goleiro** para cada clube, nas fotos, no elenco, no campinho e no editor de uniformes.
- **Elenco mais legível**: costas da camisa com o número, ícone dos pés (canhoto, destro, ambidestro) e mapa de
  posições no perfil.
- **Editor e mods**: o Editor do menu edita e cria jogadores do mundo padrão; mods em `user://mods` substituem ou
  corrigem qualquer JSON de dados e colocam jogadores reais (veja `docs/MODS.md`).
- **Base de verdade**: garotos de 14 a 19 anos em sub-15, sub-17 e sub-20, com liga sub-17 além da sub-20. Cada
  jogo escala um 4-3-3 com rodízio (goleiro no gol, garotos sobem de categoria quando se destacam) e dá minutos,
  gols, assistências e notas; quem joga evolui mais. O potencial aparece como uma faixa que estreita com o tempo de
  casa e o coordenador da base. No fim do ano há estirão (garotos tardios e quem brilhou ganham potencial) e
  estagnação (quem não joga, festeiros, desanimados). Captação por região, país ou exterior (com a regra da FIFA
  para menores) e setor prioritário; uma peneira por temporada; clubes maiores fazem propostas pelos garotos
  (vender com 20% de revenda, assinar o primeiro contrato ou recusar); lista dos revelados com o clube e o nível
  de hoje e o total arrecadado com vendas.

## Estrutura do repositório

```text
docs/ARQUITETURA.md      documento técnico (decisões, módulos, motor, economia, balanceamento)
docs/MODS.md             como criar mods (dados, patches, jogadores reais)
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
