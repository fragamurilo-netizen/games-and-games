# Noite de Luta — nota de passagem (08/10/2026)

Ramo: `claude/festive-maxwell-iuncob`. O jogo **já roda**: dá para fundar a academia, contratar,
aceitar propostas, desafiar, montar o plano, assistir à luta round a round e avançar as semanas.

## Decisões do dono

- O jogo é **muito inspirado no LEATHER: Tactical Boxing Management**, levado para o MMA.
- O jogador é o **empresário de uma academia**, não o dono de uma organização.
- **Não usar nada do Corner Office antigo** (`corner-office/`).
- Base técnica: a do Mais Uma Rodada (interface, retratos, nomes, países).

## O que está pronto

**Mundo e dados**
- 12 categorias, cerca de 1.000 lutadores (do campeão ao amador), 50 academias rivais e campeões.
- Nomes por cultura, incluindo os femininos, e uma lista de lutadores reais que nunca são gerados (`data/world/mma.json`, `data/names/fight_names.json`).

**Motor de luta** (`scripts/systems/fight_engine.gd`, `fight_plan.gd`)
- Round a round, com plano de 10 escolhas.
- Calibrado com `tools/fight_soak.gd`: nocautes de 20% a 42% conforme o peso nos homens e 15% nas mulheres; finalizações perto de 18%.

**Carreira** (`scripts/systems/`)
- `Calendar`: Liga Global (LGC) a cada duas semanas, uma noite continental e três regionais por semana.
- `Matchmaker`: lutas das rivais, cinturão, propostas, desafios no estilo LEATHER (perder trava os desafios para cima por 8 semanas; o campeão só aceita os três primeiros do ranking).
- `Rankings`: rating tipo Elo.
- `Signing`: contratação com fatia da bolsa, número de lutas e luvas.
- `StaffMarket`: 7 funções.
- `Development`: treino por foco e intensidade, envelhecimento, condição física, lesões, aposentadorias, novos amadores todo mês.
- `Career`: pesagem e corte de peso, bolsas, reputação, notícias, finanças semanais, contratos e a semana andando.
- Save em JSON (`GameManager`, `user://carreira.json`, cerca de 2,5 MB).

**Telas** (`scripts/ui/screens/`)
- Menu, nova academia e Início (noite de luta, propostas, próximas lutas, notícias, avançar semana).
- Equipe, perfil do lutador (ficha, carreira, treino, contrato), Rankings (com modo "escolher quem desafiar").
- Mercado (lutadores e staff), Academia (finanças e staff), proposta, desafio, card do evento e opções.
- Plano de luta (pesagem, leitura do técnico, ficha, editor do plano) e luta ao vivo (placar, fôlego e dano, narração, corner no intervalo, resultado).

## Verificação feita

- `tools/check_scripts.gd`: 70 scripts, 0 erros.
- `tools/world_sim.gd`: 26 semanas sem erro (cerca de 29 lutas por semana) e o save recarrega.
- `tools/design_shots.gd`: capturas de todas as telas em 390×844, com uma luta inteira jogada.
- **Não testado:** celular deitado e tablet, APK e aparelho Android, carreira longa jogada à mão.

## Próximos passos sugeridos

1. Jogar algumas semanas à mão e equilibrar o dinheiro: hoje o caixa cai uns US$ 4 mil por semana e as bolsas do regional são pequenas.
2. Lista de lançamentos da Academia: agrupar por semana (hoje se repete muito).
3. Bandeiras de países que vieram sem desenho no `nations.json` (THA, KAZ, UZB e outros aparecem como sigla).
4. Capturas em 844×390 e 1280×800, e ajuste das telas largas.
5. `CLAUDE.md` e `DESIGN.md` próprios do Noite de Luta. Hoje vale o sistema "Lousa e Giz" do MUR, com estas regras extras:
   - vermelho e azul só para os corners;
   - o destaque da interface é a cor da equipe.
6. Testes automáticos (`tests/`) e preset de exportação Android.
7. Ideias do LEATHER que ainda faltam:
   - ofertas de "step-aside" (pagar para o adversário sair do caminho);
   - mudar de categoria;
   - torneios e Grand Prix;
   - comparar dois lutadores lado a lado;
   - lutador criado pelo jogador.

## Comandos (na pasta `noite-de-luta`)

```
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tools/build_theme.gd          # depois de mexer em cores/tokens
godot --headless --path . --script res://tools/world_sim.gd -- --weeks=52
godot --headless --path . --script res://tools/fight_soak.gd -- --n=300 --seed=7
xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/design_shots.gd -- --out=/tmp/telas
```
