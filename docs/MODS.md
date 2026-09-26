# Mods do Mais Uma Rodada

Tudo o que o jogo sabe sobre o mundo — ligas, clubes, copas, nomes, táticas, narração, notícias —
está em arquivos JSON dentro de `mais-uma-rodada/data/`. Um **mod** muda esses arquivos sem mexer no
jogo instalado: dá para trocar nomes e cores, mudar regras, criar competições e colocar jogadores
reais nos elencos.

No jogo: **Editor → Mods** lista os mods instalados, liga/desliga, muda a ordem, instala um arquivo
(`.zip` ou `.json`) e exporta as suas personalizações do editor como mod para compartilhar.

## Onde ficam

```text
user://mods/<id-do-mod>/
  mod.json                      nome, autor, versão e descrição
  data/<caminho>.json           substitui o arquivo inteiro res://data/<caminho>.json
  data/<caminho>.patch.json     corrige o arquivo original (só o que mudar)
  players.json                  jogadores novos, editados ou removidos
  img/*.png                     imagens (escudos, logos, fotos) — vão para a pasta de imagens do editor
```

`user://` é a pasta de dados do jogo (no PC: `%APPDATA%/Godot/app_userdata/Mais Uma Rodada` no Windows,
`~/.local/share/godot/app_userdata/Mais Uma Rodada` no Linux; no Android, a pasta interna do app — use
**Instalar mod** para copiar um arquivo para lá).

Mods ligados valem na ordem da lista: o último ganha. Os dados são relidos quando você liga ou desliga
um mod no menu (sem carreira aberta); em carreiras já começadas, só valem as mudanças que o save não
guarda (nomes de competições, textos, regras).

## mod.json

```json
{ "name": "Brasileirão 2026 real", "author": "Seu nome", "version": "1.0",
  "description": "Elencos reais da Série A." }
```

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
  "format": 1,
  "mod": { "name": "Meu mod", "author": "Eu", "version": "1.0", "description": "" },
  "files": { "data/world/clubs/BRA.patch.json": { "clubs": { "_by": "key", "items": [] } } },
  "players": [],
  "images": { "escudo_1234.png": "<imagem PNG em base64>" }
}
```

Só caminhos dentro de `data/` são aceitos em `files`.

## Mod em .zip

Um `.zip` com `mod.json` na raiz (ou numa única pasta) e as pastas `data/`, `img/` e o `players.json`.
