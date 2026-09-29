# Fight Studio — biblioteca visual e contrato de replay

Referências: Game Design Bible §§3, 5–6, 15–18 e 22; MMA Research Bible §§7 e 20.

## Estado desta entrega

O laboratório reproduz uma biblioteca procedural 2D de **156 técnicas**, com
**478 trilhas pareadas de resposta**, dez bases marciais e seis sequências
exemplificativas. Esses números contam técnicas e respostas, não 478 golpes
diferentes. Movimentos relacionados compartilham poses-base, e cada técnica
pode ter várias respostas visuais. É um protótipo de apresentação, não captura
de movimento, física de contato ou animação 3D final.

Há seis arenas octogonais e o ringue de quatro cordas da Shinsei, seguindo
`organizations.json` e `rulesets.json`. Cada organização tem cores, inscrições,
pads, lona, marca geométrica e apron próprios. Somente marcas fictícias.

O `FightEngine.simulate()` ainda está no TODO(M1). Os exemplos são registros
**autorais**, claramente identificados na tela, e não resultados de partidas.
O player, o catálogo e o contrato de dados já estão disponíveis para a ligação
com o motor. A cena de luta nativa na Godot e o porte visual do corpo/rosto
continuam separados desta entrega: há um player GDScript funcional e testado,
mas o renderer de atletas e arenas desta etapa roda no laboratório web.

## Abrir e testar

Na pasta `corner-office`:

```sh
python -m http.server 8767 --bind 127.0.0.1
# http://127.0.0.1:8767/prototypes/fight-lab/
node prototypes/fight-lab/tests/replay.cjs
tools/run_tests.sh
```

Não há build nem dependência de execução no navegador. O servidor precisa ter
`corner-office` como raiz para acessar `game/content`; abrir por `file://` não
permite carregar os JSONs. `face-lab` continua abrindo diretamente pelo HTML.

Testes de Canvas opcionais usam a dependência de desenvolvimento do face-lab:

```sh
cd prototypes/face-lab
npm install
cd ../..
CANVAS_MODULE_PATH="$PWD/prototypes/face-lab/node_modules/@napi-rs/canvas" node prototypes/fight-lab/tests/replay.cjs
```

No PowerShell, atribua o caminho absoluto a `$env:CANVAS_MODULE_PATH` antes de
executar o comando Node. `VISUAL_OUTPUT` opcional salva seis frames de inspeção
fora do repositório. A CI roda os testes de replay, a Godot e verifica que os
JSONs gerados correspondem aos scripts de autoria.

## Arquivos e responsabilidades

| Arquivo | Responsabilidade |
|---|---|
| `tools/build_motion_catalog.py` | Autoria de técnicas, poses e arenas; gera os dois catálogos |
| `tools/build_replay_examples.py` | Seis registros autorais consistentes para QA |
| `game/content/fight_visuals.json` | IDs estáveis, fases, bases e keyframes dos dois atletas |
| `game/content/arena_profiles.json` | Identidade das sete arenas; nenhuma regra de combate |
| `game/content/replays/` | Exemplos, incluindo atletas femininas e ringue |
| `prototypes/fight-lab/replay.js` | Validação, busca temporal e interpolação determinística |
| `prototypes/fight-lab/renderer.js` | Arena, esqueleto, materiais, roupas, rostos e câmera |
| `prototypes/fight-lab/app.js` | Inspeção, filtros, transportes, importação/exportação |
| `game/presentation/fight/fight_replay_player.gd` | Mesmo contrato/keyframes para a Godot |
| `prototypes/face-lab/identity.js` | Biblioteca de identidade compartilhada, extraída sem duplicação |

Não editar os JSONs gerados isoladamente. Alterar os scripts de autoria e rodar:

```sh
python tools/build_motion_catalog.py
python tools/build_replay_examples.py
```

## Contrato v1

Um replay contém `version`, `id`, `source` (`authored_preview` ou `simulation`),
`organization_id`, `ruleset_id`, dois `fighter_ids`, um mapa `fighters`,
`initial_state`, `events` e `result` opcional. `fighters[id]` pode fornecer a
aparência completa do face-lab em `appearance` e o nome em `name`. Os exemplos
usam `appearance_index` para o roster canônico do laboratório. Esse índice é
apenas conveniência do protótipo; o motor deve fornecer a aparência completa.

Cada evento contém:

| Campo | Significado |
|---|---|
| `id` | Identificador único e estável |
| `at_ms`, `duration_ms` | Intervalo no tempo de apresentação; eventos não se sobrepõem |
| `round`, `clock_s` | Round e relógio oficial fornecidos pelo motor |
| `actor_id`, `target_id` | Atleta que executa a técnica e o adversário |
| `technique_id`, `outcome` | Técnica e resposta já resolvidas pelo motor |
| `rules_approved` | `true` somente depois da verificação de regras/jurisdição |
| `reason_codes` | Razões produzidas pelo motor; exemplos usam `AUTHORED_PREVIEW` |
| `before`, `after` | Snapshots completos da troca, com continuidade obrigatória |

Um snapshot contém `position` (um dos 12 estados do FightEngine), `top_id`
(obrigatório no chão, `null` em pé), `location` (`center`, `cage` ou `ropes`),
`stamina[id]` e `damage[id].head/body/leg` normalizados em 0–1.

`before` de um evento deve ser idêntico a `after` do anterior. O resultado vem
exclusivamente de `result.method` e `result.winner_id`. Métodos: `ko_tko`,
`submission`, `decision`, `draw`, `nc`, `dq`. Empate/NC usam `winner_id: null`.

O relógio oficial e o tempo de apresentação são diferentes: o player pode
condensar uma troca demorada. Por isso ele mostra `clock_s`, sem inventar a
passagem de tempo. Snapshots estatísticos mudam ao final do evento. No fim,
1×, 2×, 5×, seek e instantâneo produzem o mesmo estado e resultado.

### Transições do catálogo

- `completed`, `held`, `threatened`: destino definido em `to_position`.
- `blocked`, `evaded`, `missed`, `defended`: mantém a posição anterior.
- `knockdown`: `scramble`; o evento seguinte informa a continuidade no chão.
- `stoppage`, `tapped`: `reset` lógico; a pose final fica preservada até o
  próximo evento oficial (não significa levantar o atleta inconsciente).
- `escaped` de controle em pé: `pocket`; no chão: `scramble`.
- `escaped` de submissão: mantém a posição anterior.

Esses contratos descrevem os clips disponíveis, não decidem os resultados.
Se o motor precisa de outro destino, deve emitir a transição correspondente ou
adicionar um clip explícito. A UI rejeita combinações incompatíveis, técnica
inexistente, falta de aprovação de regras, relógio inválido e estados rompidos.
Não há substituição silenciosa nem inferência de vencedor.

## Ligação com o motor

1. O motor resolve a troca usando `world.rng`, atributos e regras.
2. Só depois associa um `technique_id` compatível, `outcome`, reason codes e
   snapshots. Base marcial é uma preferência, não uma classe limitante.
3. Persiste os eventos append-only em `Fight.round_log` e o resultado em Fight.
   Este trabalho não mudou o save nem inseriu fixtures no mundo persistente.
4. Um adaptador de apresentação transforma os logs por round no envelope v1.
   Esse adaptador deve mapear campos explicitamente quando o FightEngine for
   implementado; não gerar trocas para preencher lacunas do motor.
5. A UI reage a `EventBus.fight_resolved`, lê o log e entrega ao player:

```gdscript
var playback := FightReplayPlayer.new()
if playback.load_replay(replay_dictionary):
    var frame := playback.seek_ms(playback_time_ms)
    # O renderer da Godot consome frame.poses e frame.state.
else:
    push_error(str(playback.errors))
```

Apresentação nunca importa `WorldState`, avança RNG, resolve colisões de
combate, calcula dano, pontua ou escolhe o vencedor. Os materiais podem mudar
sem reescrever a luta.

## Rig e continuidade

Keyframes pareados usam metros, eixo Y para cima, pelvis em `root`, inclinação
`lean`, alvos `hands`/`feet`, inclinação da cabeça e orientação. O renderer
projeta para a tela, com Y para baixo. Tronco, pescoço e membros usam a mesma
transformação: inverter o sinal somente no tronco causava a separação visual.

A cinemática inversa conserva o comprimento dos dois segmentos. O espelhamento
inverte também os ombros/quadris, evitando pernas cruzadas por associação ao
lado errado. Mãos e pés partem do fim calculado do membro, não de um alvo que
pode estar fora de alcance. Os primeiros 26% de cada evento fazem a ligação
com a pose final anterior por **id do atleta**, inclusive quando muda o ator.
Não há rotação do corpo ou troca dos atletas causada pela ordem do dicionário.

O esquema é propositalmente 2D: contatos em profundidade, rotações completas,
pegadas finas e técnicas complexas de chão precisam de refinamento artístico
antes da arte final. Não é física de ragdoll. Validar só coordenadas finitas
não garante anatomia bonita; revisar também imagens e playback em câmera lenta.

## Para quem continuar

- Implementar FightEngine + Judge e o mapeamento de `round_log`, conforme M1.
- Portar/implementar o renderer nativo utilizando o sampler GDScript existente.
- Refinar a coreografia de cada família com contato e orientação em profundidade,
  preservando os IDs, os eventos autoritativos e os testes de continuidade.
- Expandir os eventos de árbitro/corner, estender o contrato para contatos finos
  e gravar fixtures reais quando o motor produzir lutas.
- Manter Shinsei separada: ringue, regras e apresentação não são sinônimos.

Antes de publicar: testes Node + Godot, render do face-lab se alterar identidade,
inspeção de pelo menos striking/clinch/queda/chão, desktop e mobile. Commits
pequenos na branch de trabalho, com instruções e limitações no mesmo commit.
