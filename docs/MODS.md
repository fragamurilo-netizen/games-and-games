# Mods do Mais Uma Rodada

Tudo o que o jogo sabe sobre o mundo — ligas, clubes, copas, nomes, táticas, narração, notícias —
está em arquivos JSON dentro de `mais-uma-rodada/data/`. Um **mod** muda esses arquivos sem mexer no
jogo instalado: dá para trocar nomes e cores, mudar regras, criar competições e colocar jogadores
reais nos elencos.

No jogo: **Editor → Mods** lista os mods instalados, liga/desliga, muda a ordem, importa um arquivo
(`.zip`, `.json` ou `.csv`), aponta arquivos com erro e exporta as suas personalizações do editor como mod —
em arquivo único para compartilhar ou **como pasta**, com os JSON separados, para continuar editando à mão.

O mundo padrão do jogo é o dos arquivos de `data/`. Todos os campos detalhados descritos abaixo
(nome oficial, estádio completo, uniformes por temporada, patrocinadores, escudos e logos em imagem,
placar da TV) são **opcionais**: sem eles o jogo gera o que faltar. Eles existem para que um pacote de
dados licenciados possa trocar o mundo inteiro só com arquivos, sem mexer no código.

## Licenciamento: imagens e nomes sem editar JSON

**Editor → Mods → Licenciamento**: Recarregar, Importar, Exportar, Gerar modelo, Abrir pasta (PC) e
quantas imagens casaram (ⓘ em cada pacote lista arquivo → dono e os sem dono).

### Pastas

Qualquer pasta em `user://mods/` com pelo menos um destes itens já é um pacote (sem `mod.json`):

```text
user://mods/<pacote>/
  pack.json        opcional: nome, autor, prioridade, nomes/cores/uniformes/jogadores (abaixo)
  names.csv        opcional: planilha de nomes (abaixo)
  crests/          escudos de clubes              (também: escudos/)
  logos/           logos de ligas e copas
  cutouts/         fotos de jogadores             (também: fotos/, faces/, players/, jogadores/)
  kits/            camisas em imagem e uniformes em JSON   (também: uniformes/)
  stadiums/        fotos de estádios              (também: estadios/)
```

Imagens: `.png`, `.jpg`, `.jpeg`, `.webp` (subpastas valem). Recortes com fundo transparente ficam
sobre a cor do clube; o rosto deve ficar no alto da imagem. Imagens grandes são reduzidas na memória
(512 px; estádios 1280 px). Arquivo ilegível é ignorado e aparece como sem dono.

### Nome do arquivo

O nome vale sem acento, maiúsculas, espaços ou símbolos: `São Paulo.png` = `sao-paulo.webp` =
`SAO_PAULO.jpg`. Casa com, nesta ordem:

| Pasta | Nomes aceitos |
| --- | --- |
| `crests/`, `stadiums/` | chave (`BRA_RNC`), nome, nome curto, nome oficial, sigla; `stadiums/` também o nome do estádio |
| `logos/` | id (`BRA1`, `LIB`), nome, nome curto |
| `cutouts/` | id do jogador, nome completo (`Nome Sobrenome`), nome de camisa, apelido |
| `kits/` | como `crests/`, com sufixo do uniforme: nada ou `_home` titular, `_away` reserva, `_third` terceiro, `_gk` goleiro (`_titular`, `_reserva`, `_terceiro`, `_goleiro` também) |

`kits/<clube>.json` traz uniformes no formato de `data/world/kits` (`{"h": {...}, "a": {...}}`) e vale
para carreiras novas. Os nomes usados são os atuais (depois dos pacotes): se o pacote renomeia um
clube, a imagem pode ter o nome novo ou a chave.

Imagens soltas valem na hora, também em carreiras abertas (Recarregar). Escudo ou logo escolhido no
Editor ou citado nos dados (`crest_img`, `logo`) ganha da imagem solta. Entre pacotes, ganha o de baixo.
Sem o arquivo, volta o desenho do jogo — o save guarda só a referência (`"@crests/flamengo"`).

### names.csv

Gerado por **Gerar modelo** (pacote `modelo_licenciamento`, já ligado): todas as ligas, copas,
clubes e os jogadores do mundo padrão, com id e nome atual. Preencha só o que quer mudar; célula
vazia não muda nada. UTF-8; separador `,` ou `;` (Excel em português).

```csv
tipo,id,atual,nome,curto,sigla,cor1,cor2,estadio,capacidade
liga,BRA1,Campeonato Nacional,Brasileirão Série A,Brasileirão,,#0B6E4F,#F2C94C,,
clube,BRA_RNC,Rubro-Negro,Clube de Regatas do Flamengo,Flamengo,FLA,#C8102E,#111111,Maracanã,78838
jogador,BRA_RNC/Nome Sobrenome,Nome Sobrenome,Giorgian de Arrascaeta,Arrascaeta,,,,,
```

| Coluna | Uso |
| --- | --- |
| `tipo` | `liga`, `copa`, `clube` ou `jogador` (`league`, `cup`, `club`, `player`). |
| `id` | Chave da liga/copa/clube; jogador: `<chave do clube>/<nome original>` (não mude). |
| `atual` | Só referência; ignorada. |
| `nome` | Nome completo. Jogador: primeira palavra = nome, o resto = sobrenome. |
| `curto` | Nome curto; jogador: nome de camisa. |
| `sigla`, `estadio`, `capacidade` | Só clubes. |
| `cor1`, `cor2` | `#RRGGBB` (o `#` é opcional). |

Nomes de clubes, competições e jogadores valem para carreiras novas; renomear jogadores vale para
carreiras no mundo padrão (semente inicial), onde os nomes originais existem.

### pack.json

```json
{ "name": "Brasil real", "author": "Eu", "version": "1.0", "priority": 10,
  "clubs": { "BRA_RNC": { "name": "Flamengo", "short": "Flamengo", "abbr": "FLA", "colors": ["#C8102E", "#111111"],
                          "stadium": "Maracanã", "capacity": 78838, "kits": { "h": { "pattern": "hoops_thin" } } } },
  "leagues": { "BRA1": { "name": "Brasileirão", "short": "Série A", "colors": ["#0B6E4F", "#F2C94C"] } },
  "cups": { "CDB": { "name": "Copa do Brasil" } },
  "players": [ { "club": "BRA_RNC", "match": "Nome Sobrenome", "first": "Giorgian", "last": "de Arrascaeta" } ] }
```

`clubs`, `leagues` e `cups` aceitam qualquer campo dos dados (ver "Clubes em detalhe" e
"Competições em detalhe"); só mudam itens que existem. `players` segue o `players.json`.
Ordem dentro do pacote: arquivos `data/`, depois `pack.json`, depois `names.csv`.

### Importar e exportar

- **Importar**: `.zip` (com `pack.json`, `names.csv`, `mod.json` ou as pastas de imagens, na raiz ou
  numa pasta), `pack.json` (copia a pasta dele), `.csv` sozinho ou mod `.json`. Entra ligado, por último.
- **Exportar**: `user://exports/<nome>/` + `.zip` com `pack.json` (só o que difere dos dados originais:
  pacotes ligados + Editor), jogadores, e as imagens em uso renomeadas pela chave/id
  (`crests/BRA_RNC.png`, `logos/BRA1.png`, `stadiums/BRA_RNC.jpg`, `kits/BRA_RNC_away.png`, `cutouts/…`).

## O caminho mais curto

1. No **Editor** do menu inicial, edite clubes (nome, cores, escudo, estádio, uniformes), competições
   (nome, logo, cores, placar da TV) e jogadores.
2. **Editor → Mods → Exportar como pasta**. O jogo cria `user://mods/<id>/` com os arquivos no
   formato deste documento (e um `.zip` em `user://exports/`).
3. Abra os JSON, copie o padrão para os outros clubes e competições e ligue o mod.

## Onde ficam

```text
user://mods/<id-do-mod>/
  mod.json                      nome, autor, versão, descrição, prioridade
  data/<caminho>.json           substitui o arquivo inteiro res://data/<caminho>.json
                                (ou cria um novo, ex.: data/world/clubs/<PAÍS>.json de um país sem clubes)
  data/<caminho>.patch.json     corrige o arquivo original (só o que mudar)
  players.json                  jogadores novos, editados ou removidos
  img/**                        imagens (png, jpg, webp) em qualquer subpasta
```

Os dados citam imagens pelo caminho a partir de `img/`: `"crest_img": "escudos/meu_clube.png"` usa
`user://mods/<id>/img/escudos/meu_clube.png`. Se dois mods ligados tiverem a mesma imagem, vale a do
mod que vem por último. Um nome sem pasta (`"crest_123.png"`) procura primeiro nas imagens importadas
pelo Editor (`user://custom/img`).

`user://` é a pasta de dados do jogo (no PC: `%APPDATA%/Godot/app_userdata/Mais Uma Rodada` no Windows,
`~/.local/share/godot/app_userdata/Mais Uma Rodada` no Linux; no Android, a pasta interna do app — use
**Importar** para copiar um arquivo para lá).

Mods ligados valem na ordem da lista: o último ganha. Uma pasta copiada à mão para `user://mods/`
aparece ligada na próxima vez que o jogo abrir (ou em **Recarregar**), na posição do
seu `priority`; `"enabled": false` no `mod.json` faz ela entrar desligada. Os dados são relidos quando você liga ou desliga
um mod no menu (sem carreira aberta); em carreiras já começadas, só valem as mudanças que o save não
guarda (nomes de competições, textos, regras).

## mod.json

```json
{ "name": "Brasileirão 2026 real", "author": "Seu nome", "version": "1.0",
  "description": "Elencos reais da Série A.", "format": 2, "priority": 10, "enabled": true }
```

| Campo | O que faz |
| --- | --- |
| `priority` | Ordem inicial de um mod novo: maior = aplicado depois (ganha dos outros). Padrão 0. |
| `enabled` | `false` faz o mod entrar desligado quando for descoberto. Padrão `true`. |
| `format` | Versão do formato (2 = este documento). Só informativo. |

## Substituir um arquivo

Copie o arquivo original (por exemplo `data/text/commentary.json`) para `data/text/commentary.json`
dentro do mod e edite. O jogo usa o do mod no lugar do original.

## Corrigir um arquivo (patch)

Um `*.patch.json` é mesclado sobre o original:

- objeto sobre objeto: chave a chave, recursivo. `"_remove": ["chave"]` apaga chaves.
- lista de objetos: `{"_by": "campo", "items": [...], "remove": [valores]}` — cada item é mesclado com
  o elemento de mesmo `campo` (ou acrescentado, se não existir); `remove` apaga pelos valores do campo.
- qualquer outro valor substitui o original.

Exemplo — renomear um clube e mudar as cores (`data/world/clubs/BRA.patch.json`, Flamengo = `BRA_RNC`):

```json
{ "clubs": { "_by": "key", "items": [
  { "key": "BRA_RNC", "name": "Clube de Regatas do Flamengo", "short": "Flamengo", "colors": ["#C8102E", "#111111"] }
] } }
```

Exemplo — Copa do Brasil em jogo único até a semifinal (`data/world/domestic.patch.json`):

```json
{ "cups": { "CDB": { "two_legs": ["sf", "f"], "name": "Copa do Brasil" } } }
```

Exemplo — mais vagas do Brasil na Libertadores (`data/world/continental.patch.json`):

```json
{ "cups": { "LIB": { "alloc": { "BRA": 8 } } } }
```

## Clubes em detalhe (data/world/clubs/<PAÍS>.json)

Cada clube é um objeto da lista `clubs`, identificado pela `key` (estável, não muda com o nome).
Campos de sempre: `key`, `name`, `short`, `abbr`, `nick`, `city`, `uf`, `founded`, `league`, `rep`,
`arch`, `colors`, `stadium`, `capacity`, `kit`, `crest`, `rivals`. Campos detalhados (opcionais):

| Campo | Formato |
| --- | --- |
| `official` (ou `official_name`) | Nome oficial completo, quando diferente de `name`. |
| `short_name`, `abbreviation`, `nickname`, `reputation`, `archetype` | Apelidos em inglês de `short`, `abbr`, `nick`, `rep`, `arch`. |
| `founded` | Ano (`1914`) ou data (`"1914-08-26"`). |
| `colors` | `["#hex", "#hex"]` ou `{"primary": "#hex", "secondary": "#hex"}`. |
| `crest_img` | Escudo em imagem (caminho em `img/`). Sem ele, o escudo desenhado de `crest`. |
| `stadium` | Texto (só o nome) ou objeto `{name, capacity, city, built, nick, photo, kind}`. |
| `kits` | Uniformes no formato de `data/world/kits` (abaixo); valem por cima do arquivo de uniformes. |
| `sponsors` | Patrocinadores fixos no começo do jogo (abaixo). |

`stadium.kind` escolhe o desenho do estádio e o corte do gramado na partida:

| `kind` | Estádio |
| --- | --- |
| `arena` | Moderno, cobertura fechada, placas de LED, listras finas no gramado. |
| `caldeirao` | Arquibancada íngreme colada no campo, alambrado, listras largas. |
| `olimpico` | Pista de atletismo em volta, torcida mais longe, corte xadrez. |
| `acanhado` | Pequeno, muro pintado, poucas placas, gramado gasto nas áreas. |

Sem `kind`, o jogo escolhe pela capacidade, pelo país e pelo nome. `photo` aparece na tela do clube.

Exemplo completo de um clube fictício (`data/world/clubs/BRA.patch.json`):

```json
{ "clubs": { "_by": "key", "items": [
  { "key": "BRA_XYZ", "name": "Atlético Serrano", "official": "Associação Atlética Serrana",
    "short": "Serrano", "abbr": "SER", "nick": "Leão da Serra", "city": "Serra Alta", "uf": "MG",
    "founded": "1921-05-03", "league": "BRA2", "rep": 62, "colors": {"primary": "#0B6E4F", "secondary": "#FFFFFF"},
    "crest_img": "escudos/serrano.png",
    "stadium": { "name": "Estádio da Colina", "capacity": 18500, "built": 1954, "nick": "Colina",
                 "kind": "caldeirao", "photo": "estadios/colina.jpg" },
    "kits": { "h": { "pattern": "stripes_v", "c1": "#0B6E4F", "c2": "#FFFFFF", "shorts": "#FFFFFF", "socks": "#0B6E4F",
                     "sponsor": "Café Serrano", "supplier": {"n": "Trama", "c": "#111111", "t": "#FFFFFF"} },
              "a": { "pattern": "plain", "c1": "#FFFFFF", "c2": "#0B6E4F" } },
    "sponsors": { "manga": { "n": "Rádio Colina", "yrs": 2 } } }
] } }
```

Um clube novo é só um item com uma `key` que não existe (`<PAÍS>_<3 letras>`) e a `league` dele; a
liga completa o número de times com clubes gerados, se faltar.

### Uniformes (data/world/kits/<PAÍS>.json)

```json
{ "kits": { "BRA_XYZ": {
  "h": { "pattern": "stripes_v", "c1": "#0B6E4F", "c2": "#FFFFFF", "c3": "#FFFFFF",
         "shorts": "#FFFFFF", "shorts2": "#0B6E4F", "socks": "#0B6E4F", "socks2": "#FFFFFF",
         "collar": "v", "sleeve": "cuff", "shorts_style": "plain", "socks_style": "top_band" },
  "a": { ... }, "t": { ... }, "g": { ... },
  "alt": [ { ... } ],
  "seasons": { "2027": { "h": { ... }, "a": { ... } } }
} } }
```

`h` titular, `a` reserva, `t` terceiro, `g` goleiro, `alt` outros modelos recentes. `seasons` troca os
uniformes a partir de uma temporada (a da temporada inicial já vale desde o começo). Campos que faltam
são completados pelo jogo. Estampas (`pattern`): `plain stripes_v pinstripes wide_stripes center_stripe
halves quarters stripes_h hoops_thin faixa faixa_duo double_band yoke diagonal sash_double chevron
v_big cross checkers harlequin gradient halftone sunburst camo …` (a lista completa está em
`scripts/ui/components/kit_view.gd`, `PATTERNS`). Um uniforme pode trazer `sponsor` e `supplier`.

### Patrocinadores

`sponsors` tem os espaços `master`, `fornecedor`, `manga`, `costas` e `calcao`, cada um
`{n: nome, c: cor de fundo, t: cor do texto, logo: imagem, yrs: anos de contrato (3), v: valor anual}`.
Sem `v`, o valor segue o mercado do clube. Marcas de `data/world/brands.json` completam cores e logo.

## Competições em detalhe

Ligas (`data/world/leagues.json`, lista `leagues`, por `id`) e copas (`continental.json` e
`domestic.json`, objeto `cups`, por id) aceitam, além das regras:

| Campo | Formato |
| --- | --- |
| `name`, `short` | Nome completo e curto. |
| `colors` | `["#principal", "#destaque"]`: selo, tabelas, placar. |
| `logo` | Logo em imagem (caminho em `img/`). |
| `logo_design` | Logo desenhado, no formato do escudo (`shape`, `c1`, `c2`, `symbol`, `text`, `text2`…). |
| `scoreboard` | Placar da TV: `{"layout": "...", "colors": ["#fundo", "#fundo2", "#destaque"], "text": "#hex"}`. |

`scoreboard.layout` escolhe o desenho do placar da partida (prévia no Editor → Competições →
Placar da TV; o desenho fica em `scripts/ui/components/scoreboard_view.gd`):

| `layout` | Placar |
| --- | --- |
| `faixa` | Faixa arredondada, placar numa caixa com borda, filete na cor de cada time. |
| `tv` | Barra reta, blocos na cor dos times e placar cheio na cor da competição. |
| `angular` | Peças inclinadas. |
| `capsula` | Tudo arredondado, com brilho na cor da competição. |
| `classico` | Placar de estádio antigo: caixa preta e números âmbar. |
| `compacto` | Selo no canto: logo, siglas em fichas coloridas, placar e relógio numa linha. |
| `painel` | Um time por linha (placar empilhado) e o relógio numa coluna. |
| `neon` | Vidro escuro, filetes acesos e números grandes. |

Todos mostram o logo da competição, o acréscimo ("+4"), o aviso de gol, intervalo/fim/pênaltis e o
agregado nos mata-matas de ida e volta. Sem `scoreboard`, valem
`identity.json` (`scoreboard` e `scoreboard_layout` por id) e, por fim, as cores da liga ou da bandeira.

```json
{ "leagues": { "_by": "id", "items": [
  { "id": "BRA1", "name": "Campeonato Nacional", "logo": "logos/nacional.png",
    "scoreboard": { "layout": "tv", "colors": ["#0B1F14", "#12351F", "#F2C94C"] } }
] } }
```

## O que o Editor grava (overrides)

O Editor guarda as personalizações em `user://custom/overrides.json` e as aplica por cima dos dados e
dos mods, em todas as carreiras novas:

```json
{ "clubs": { "BRA_RNC": { "name": "...", "stadium": "...", "cap": 78000,
    "venue": { "kind": "olimpico", "photo": "stadium_1700000000_123.png", "nick": "...", "built": 1950 },
    "c1": "#hex", "c2": "#hex", "crest": { ... }, "kits": { "h": { ... }, "a": { ... }, "t": { ... }, "g": { ... } } } },
  "leagues": { "BRA1": { "name": "...", "short": "...", "logo": "...", "colors": [], "scoreboard": { ... } } },
  "cups": { "CDB": { ... } } }
```

**Exportar como mod** converte isso para patches de `data/world/clubs`, `data/world/kits`,
`data/world/leagues.json`, `continental.json` e `domestic.json`, então quem instala não precisa do seu
`overrides.json`.

## Conferindo um mod

O Editor mostra embaixo de cada mod os arquivos com problema: JSON inválido, `mod.json` ilegível ou um
`.patch.json` que não corrige nenhum arquivo do jogo.

## Jogadores (players.json)

Uma lista de entradas. Com `match` edita um jogador gerado (pelo nome original dele no clube); sem
`match` cria um jogador novo; com `"remove": true` tira o jogador do mundo.

```json
[
  { "club": "BRA_RNC", "first": "Giorgian", "last": "de Arrascaeta", "known": "Arrascaeta",
    "nat": "URU", "pos": "MEI", "sec": ["MC"], "birth": 1994, "foot": "R", "height": 174,
    "ovr": 84, "pot": 84, "shirt": 10, "traits": ["lider"] },
  { "club": "BRA_RNC", "match": "Nome Sobrenome", "remove": true },
  { "club": "ENG_MSK", "match": "Nome Sobrenome", "known": "Craque", "attrs": { "FIN": 92, "VEL": 88 } }
]
```

Campos: `club` (chave do clube, vazio = sem clube), `first`, `last`, `known` (nome na camisa), `nick`,
`nat` (código do país, ex. `BRA`), `pos` e `sec` (códigos `GOL LD ZAG LE VOL MC MEI MD ME PD PE ATA` ou
`GK RB CB LB DM CM AM RM LM RW LW ST`), `birth` ou `age`, `height`, `weight`, `foot` (`R`, `L` ou `B`),
`shirt`, `ovr` (overall alvo: o jogo monta atributos coerentes com a posição), `attrs` (qualquer um de
`FIN PAS TEC VEL FOR MAR POS VIS CRU CAB RES GOL DIS INT DEC DRI DES CHL ACE REF FRI`, de 1 a 99; os que faltarem ficam com os valores gerados para o jogador), `pot` (potencial), `traits`
(ids de `data/gameplay/personalities.json`), `look` (aparência: `hs`, `hc`, `bd`, `sk`, `ey`, `photo`).

As chaves dos clubes estão em `data/world/clubs/<PAÍS>.json` (campo `key`) e aparecem no editor de
clubes do jogo, embaixo do nome ("Chave para mods"). Elas não seguem a sigla do clube: o Flamengo, por
exemplo, é `BRA_RNC`.

## Mod em arquivo único (.json)

Mais fácil de mandar pelo celular. É o formato de **Exportar como mod**:

```json
{
  "format": 2,
  "mod": { "name": "Meu mod", "author": "Eu", "version": "1.0", "description": "" },
  "files": { "data/world/clubs/BRA.patch.json": { "clubs": { "_by": "key", "items": [] } } },
  "players": [],
  "images": { "escudos/meu_clube.png": "<imagem em base64>" }
}
```

Só caminhos dentro de `data/` são aceitos em `files`.

## Mod em .zip

Um `.zip` com `mod.json` na raiz (ou numa única pasta) e as pastas `data/`, `img/` e o `players.json`.
